import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:grammarlens_ui/grammarlens_ui.dart';

import 'package:grammarlens/di/injection.dart';
import 'package:grammarlens/features/editor/presentation/pages/editor_page.dart';
import 'package:grammarlens/features/external_check/presentation/bloc/external_check_bloc.dart';
import 'package:grammarlens/features/model_manager/presentation/bloc/model_bloc.dart';
import 'package:grammarlens/features/model_manager/presentation/bloc/model_event.dart';
import 'package:grammarlens/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:grammarlens/features/settings/presentation/bloc/settings_event.dart';
import 'package:grammarlens/features/settings/presentation/bloc/settings_state.dart';

/// Root widget for the GrammarLens application.
class GrammarLensApp extends StatelessWidget {
  const GrammarLensApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(
          value: getIt<ModelBloc>()..add(const ModelStatusChecked()),
        ),
        BlocProvider.value(
          value: getIt<SettingsBloc>()..add(const SettingsLoaded()),
        ),
        if (Platform.isMacOS)
          BlocProvider.value(
            value: getIt<ExternalCheckBloc>(),
          ),
      ],
      child: BlocBuilder<SettingsBloc, SettingsState>(
        buildWhen: (prev, curr) =>
            prev.preferences.themeMode != curr.preferences.themeMode,
        builder: (context, settingsState) {
          return MaterialApp(
            title: 'GrammarLens',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: settingsState.preferences.themeMode,
            home: const EditorPage(),
          );
        },
      ),
    );
  }
}
