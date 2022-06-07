import 'dart:async';
import 'dart:collection';

import 'log_record.dart';
import 'logging_level.dart';

/// Whether to allow fine-grain logging and configuration of loggers in a
/// hierarchy.
///
/// When false, all hierarchical logging instead is merged in the root logger.
bool hierarchicalLoggingEnabled = false;

/// Automatically record stack traces for any message of this level or above.
///
/// Because this is expensive, this is off by default.
LoggingLevel recordStackTraceAtLevel = LoggingLevel.OFF;

/// The default [LoggingLevel].
const defaultLevel = LoggingLevel.INFO;

/// Use a [LoggingLogger] to log debug messages.
///
/// [LoggingLogger]s are named using a hierarchical dot-separated name convention.
class LoggingLogger {
  /// Simple name of this logger.
  final String name;

  /// The full name of this logger, which includes the parent's full name.
  String get fullName => parent?.name.isNotEmpty ?? false ? '${parent!.fullName}.$name' : name;

  /// Parent of this logger in the hierarchy of loggers.
  final LoggingLogger? parent;

  /// Logging [LoggingLevel] used for entries generated on this logger.
  ///
  /// Only the root logger is guaranteed to have a non-null [LoggingLevel].
  LoggingLevel? _level;

  /// Private modifiable map of child loggers, indexed by their simple names.
  final Map<String, LoggingLogger> _children;

  /// Children in the hierarchy of loggers, indexed by their simple names.
  ///
  /// This is an unmodifiable map.
  final Map<String, LoggingLogger> children;

  /// Controller used to notify when log entries are added to this logger.
  ///
  /// If hierarchical logging is disabled then this is `null` for all but the
  /// root [LoggingLogger].
  StreamController<LogRecord>? _controller;

  /// Create or find a Logger by name.
  ///
  /// Calling `Logger(name)` will return the same instance whenever it is called
  /// with the same string name. Loggers created with this constructor are
  /// retained indefinitely and available through [attachedLoggers];
  factory LoggingLogger(String name) => _loggers.putIfAbsent(name, () => LoggingLogger._named(name));

  /// Creates a new detached [LoggingLogger].
  ///
  /// Returns a new [LoggingLogger] instance (unlike `new Logger`, which returns a
  /// [LoggingLogger] singleton), which doesn't have any parent or children,
  /// and is not a part of the global hierarchical loggers structure.
  ///
  /// It can be useful when you just need a local short-living logger,
  /// which you'd like to be garbage-collected later.
  factory LoggingLogger.detached(String name) => LoggingLogger._internal(name, null, <String, LoggingLogger>{});

  factory LoggingLogger._named(String name) {
    if (name.startsWith('.')) {
      throw ArgumentError("name shouldn't start with a '.'");
    }
    // Split hierarchical names (separated with '.').
    var dot = name.lastIndexOf('.');
    LoggingLogger? parent;
    String thisName;
    if (dot == -1) {
      if (name != '') parent = LoggingLogger('');
      thisName = name;
    } else {
      parent = LoggingLogger(name.substring(0, dot));
      thisName = name.substring(dot + 1);
    }
    return LoggingLogger._internal(thisName, parent, <String, LoggingLogger>{});
  }

  LoggingLogger._internal(this.name, this.parent, Map<String, LoggingLogger> children)
      : _children = children,
        children = UnmodifiableMapView(children) {
    if (parent == null) {
      _level = defaultLevel;
    } else {
      parent!._children[name] = this;
    }
  }

  /// Effective level considering the levels established in this logger's
  /// parents (when [hierarchicalLoggingEnabled] is true).
  LoggingLevel get level {
    LoggingLevel effectiveLevel;

    if (parent == null) {
      // We're either the root logger or a detached logger.  Return our own
      // level.
      effectiveLevel = _level!;
    } else if (!hierarchicalLoggingEnabled) {
      effectiveLevel = root._level!;
    } else {
      effectiveLevel = _level ?? parent!.level;
    }

    // ignore: unnecessary_null_comparison
    assert(effectiveLevel != null);
    return effectiveLevel;
  }

  /// Override the level for this particular [LoggingLogger] and its children.
  ///
  /// Setting this to `null` makes it inherit the [parent]s level.
  set level(LoggingLevel? value) {
    if (!hierarchicalLoggingEnabled && parent != null) {
      throw UnsupportedError('Please set "hierarchicalLoggingEnabled" to true if you want to '
          'change the level on a non-root logger.');
    }
    if (parent == null && value == null) {
      throw UnsupportedError('Cannot set the level to `null` on a logger with no parent.');
    }
    _level = value;
  }

  /// Returns a stream of messages added to this [LoggingLogger].
  ///
  /// You can listen for messages using the standard stream APIs, for instance:
  ///
  /// ```dart
  /// logger.onRecord.listen((record) { ... });
  /// ```
  Stream<LogRecord> get onRecord => _getStream();

  void clearListeners() {
    if (hierarchicalLoggingEnabled || parent == null) {
      _controller?.close();
      _controller = null;
    } else {
      root.clearListeners();
    }
  }

  /// Whether a message for [value]'s level is loggable in this logger.
  bool isLoggable(LoggingLevel value) => (value >= level);

  /// Adds a log record for a [message] at a particular [logLevel] if
  /// `isLoggable(logLevel)` is true.
  ///
  /// Use this method to create log entries for user-defined levels. To record a
  /// message at a predefined level (e.g. [LoggingLevel.INFO], [LoggingLevel.WARNING], etc)
  /// you can use their specialized methods instead (e.g. [info], [warning],
  /// etc).
  ///
  /// If [message] is a [Function], it will be lazy evaluated. Additionally, if
  /// [message] or its evaluated value is not a [String], then 'toString()' will
  /// be called on the object and the result will be logged. The log record will
  /// contain a field holding the original object.
  ///
  /// The log record will also contain a field for the zone in which this call
  /// was made. This can be advantageous if a log listener wants to handler
  /// records of different zones differently (e.g. group log records by HTTP
  /// request if each HTTP request handler runs in it's own zone).
  void log(LoggingLevel logLevel, Object? message, [Object? error, StackTrace? stackTrace, Zone? zone]) {
    Object? object;
    if (isLoggable(logLevel)) {
      if (message is Function) {
        message = (message as Object? Function())();
      }

      String msg;
      if (message is String) {
        msg = message;
      } else {
        msg = message.toString();
        object = message;
      }

      if (stackTrace == null && logLevel >= recordStackTraceAtLevel) {
        stackTrace = StackTrace.current;
        error ??= 'autogenerated stack trace for $logLevel $msg';
      }
      zone ??= Zone.current;

      var record = LogRecord(logLevel, msg, fullName, error, stackTrace, zone, object);

      if (parent == null) {
        _publish(record);
      } else if (!hierarchicalLoggingEnabled) {
        root._publish(record);
      } else {
        LoggingLogger? target = this;
        while (target != null) {
          target._publish(record);
          target = target.parent;
        }
      }
    }
  }

  /// Log message at level [LoggingLevel.FINEST].
  ///
  /// See [log] for information on how non-String [message] arguments are
  /// handled.
  void finest(Object? message, [Object? error, StackTrace? stackTrace]) => log(LoggingLevel.FINEST, message, error, stackTrace);

  /// Log message at level [LoggingLevel.FINER].
  ///
  /// See [log] for information on how non-String [message] arguments are
  /// handled.
  void finer(Object? message, [Object? error, StackTrace? stackTrace]) => log(LoggingLevel.FINER, message, error, stackTrace);

  /// Log message at level [LoggingLevel.FINE].
  ///
  /// See [log] for information on how non-String [message] arguments are
  /// handled.
  void fine(Object? message, [Object? error, StackTrace? stackTrace]) => log(LoggingLevel.FINE, message, error, stackTrace);

  /// Log message at level [LoggingLevel.CONFIG].
  ///
  /// See [log] for information on how non-String [message] arguments are
  /// handled.
  void config(Object? message, [Object? error, StackTrace? stackTrace]) => log(LoggingLevel.CONFIG, message, error, stackTrace);

  /// Log message at level [LoggingLevel.INFO].
  ///
  /// See [log] for information on how non-String [message] arguments are
  /// handled.
  void info(Object? message, [Object? error, StackTrace? stackTrace]) => log(LoggingLevel.INFO, message, error, stackTrace);

  /// Log message at level [LoggingLevel.WARNING].
  ///
  /// See [log] for information on how non-String [message] arguments are
  /// handled.
  void warning(Object? message, [Object? error, StackTrace? stackTrace]) => log(LoggingLevel.WARNING, message, error, stackTrace);

  /// Log message at level [LoggingLevel.SEVERE].
  ///
  /// See [log] for information on how non-String [message] arguments are
  /// handled.
  void severe(Object? message, [Object? error, StackTrace? stackTrace]) => log(LoggingLevel.SEVERE, message, error, stackTrace);

  /// Log message at level [LoggingLevel.SHOUT].
  ///
  /// See [log] for information on how non-String [message] arguments are
  /// handled.
  void shout(Object? message, [Object? error, StackTrace? stackTrace]) => log(LoggingLevel.SHOUT, message, error, stackTrace);

  Stream<LogRecord> _getStream() {
    if (hierarchicalLoggingEnabled || parent == null) {
      return (_controller ??= StreamController<LogRecord>.broadcast(sync: true)).stream;
    } else {
      return root._getStream();
    }
  }

  void _publish(LogRecord record) => _controller?.add(record);

  /// Top-level root [LoggingLogger].
  static final LoggingLogger root = LoggingLogger('');

  /// All attached [LoggingLogger]s in the system.
  static final Map<String, LoggingLogger> _loggers = <String, LoggingLogger>{};

  /// All attached [LoggingLogger]s in the system.
  ///
  /// Loggers created with [Logger.detached] are not included.
  static Iterable<LoggingLogger> get attachedLoggers => _loggers.values;
}
