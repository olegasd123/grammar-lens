import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:grammarlens_ui/grammarlens_ui.dart';

import 'package:grammarlens/di/injection.dart';
import 'package:grammarlens/features/editor/presentation/pages/editor_page.dart';
import 'package:grammarlens/features/model_manager/presentation/bloc/model_bloc.dart';
import 'package:grammarlens/features/model_manager/presentation/bloc/model_event.dart';

/// Root widget for the GrammarLens application.
class GrammarLensApp extends StatelessWidget {
  const GrammarLensApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: getIt<ModelBloc>()..add(const ModelStatusChecked()),
      child: MaterialApp(
        title: 'GrammarLens',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.system,
        home: const EditorPage(),
      ),
    );
  }
}
