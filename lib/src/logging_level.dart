// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// ignore_for_file: constant_identifier_names

/// [LoggingLevel]s to control logging output. Logging can be enabled to include all
/// levels above certain [LoggingLevel]. [LoggingLevel]s are ordered using an integer
/// value [LoggingLevel.value]. The predefined [LoggingLevel] constants below are sorted as
/// follows (in descending order): [LoggingLevel.SHOUT], [LoggingLevel.SEVERE],
/// [LoggingLevel.WARNING], [LoggingLevel.INFO], [LoggingLevel.CONFIG], [LoggingLevel.FINE], [LoggingLevel.FINER],
/// [LoggingLevel.FINEST], and [LoggingLevel.ALL].
///
/// We recommend using one of the predefined logging levels. If you define your
/// own level, make sure you use a value between those used in [LoggingLevel.ALL] and
/// [LoggingLevel.OFF].
class LoggingLevel implements Comparable<LoggingLevel> {
  final String name;

  /// Unique value for this level. Used to order levels, so filtering can
  /// exclude messages whose level is under certain value.
  final int value;

  const LoggingLevel(this.name, this.value);

  /// Special key to turn on logging for all levels ([value] = 0).
  static const LoggingLevel ALL = LoggingLevel('ALL', 0);

  /// Special key to turn off all logging ([value] = 2000).
  static const LoggingLevel OFF = LoggingLevel('OFF', 2000);

  /// Key for highly detailed tracing ([value] = 300).
  static const LoggingLevel FINEST = LoggingLevel('FINEST', 300);

  /// Key for fairly detailed tracing ([value] = 400).
  static const LoggingLevel FINER = LoggingLevel('FINER', 400);

  /// Key for tracing information ([value] = 500).
  static const LoggingLevel FINE = LoggingLevel('FINE', 500);

  /// Key for static configuration messages ([value] = 700).
  static const LoggingLevel CONFIG = LoggingLevel('CONFIG', 700);

  /// Key for informational messages ([value] = 800).
  static const LoggingLevel INFO = LoggingLevel('INFO', 800);

  /// Key for potential problems ([value] = 900).
  static const LoggingLevel WARNING = LoggingLevel('WARNING', 900);

  /// Key for serious failures ([value] = 1000).
  static const LoggingLevel SEVERE = LoggingLevel('SEVERE', 1000);

  /// Key for extra debugging loudness ([value] = 1200).
  static const LoggingLevel SHOUT = LoggingLevel('SHOUT', 1200);

  static const List<LoggingLevel> LEVELS = [ALL, FINEST, FINER, FINE, CONFIG, INFO, WARNING, SEVERE, SHOUT, OFF];

  @override
  bool operator ==(Object other) => other is LoggingLevel && value == other.value;

  bool operator <(LoggingLevel other) => value < other.value;

  bool operator <=(LoggingLevel other) => value <= other.value;

  bool operator >(LoggingLevel other) => value > other.value;

  bool operator >=(LoggingLevel other) => value >= other.value;

  @override
  int compareTo(LoggingLevel other) => value - other.value;

  @override
  int get hashCode => value;

  @override
  String toString() => name;
}
