import 'dart:async';

import 'package:flutter/material.dart';

import 'app.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      debugPrint('════════════════════════════════════════');
      debugPrint('Flutter Error: ${details.exception}');
      debugPrint('Stack trace: ${details.stack}');
      debugPrint('════════════════════════════════════════');
    };

    debugPrint('════════════════════════════════════════');
    debugPrint('Starting Node Graph Notebook...');
    debugPrint('════════════════════════════════════════');

    runApp(
      const NodeGraphNotebookApp(),
    );
  }, (error, stack) {
    debugPrint('════════════════════════════════════════');
    debugPrint('Uncaught Error: $error');
    debugPrint('Stack trace: $stack');
    debugPrint('════════════════════════════════════════');
  });
}
