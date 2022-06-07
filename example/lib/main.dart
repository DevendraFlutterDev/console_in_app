import 'package:console_in_app/console_in_app.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  MyApp({Key? key}) : super(key: key);

  num number = 0;
  final log = LoggingLogger('MyApp');

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: LogConsoleOnShake(
        child: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                MaterialButton(
                  onPressed: () {
                    log.fine('Got the result: you have pressed ${number++} times');
                  },
                  child: const Text("Click on this button"),
                ),
                const SizedBox(
                  height: 24,
                ),
                const Text("Shake your phone to see the console"),
              ],
            ),
          ),
        ),
        dark: true,
      ),
    );
  }
}
