import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

import 'package:grammarlens/app.dart';
import 'package:grammarlens/di/injection.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configure logging
  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen((record) {
    debugPrint(
      '${record.level.name}: ${record.loggerName}: ${record.message}',
    );
  });

  // Set up dependency injection
  await configureDependencies();

  runApp(const GrammarLensApp());
}
