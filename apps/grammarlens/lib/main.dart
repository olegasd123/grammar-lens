import 'dart:io';

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

import 'package:platform_integration/platform_integration.dart';

import 'package:grammarlens/app.dart';
import 'package:grammarlens/di/injection.dart';
import 'package:grammarlens/features/external_check/presentation/bloc/external_check_bloc.dart';
import 'package:grammarlens/features/external_check/presentation/bloc/external_check_event.dart';

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

  // Register global hotkey on macOS (Cmd+Shift+G)
  if (Platform.isMacOS) {
    final hotkeyService = getIt<GlobalHotkeyService>();
    await hotkeyService.registerHotkey('cmd+shift+g', () {
      getIt<ExternalCheckBloc>().add(const ExternalCheckTriggered());
    });
  }

  runApp(const GrammarLensApp());
}
