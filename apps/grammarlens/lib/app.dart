import 'package:flutter/material.dart';

import 'package:grammarlens_ui/grammarlens_ui.dart';

import 'package:grammarlens/features/editor/presentation/pages/editor_page.dart';

/// Root widget for the GrammarLens application.
class GrammarLensApp extends StatelessWidget {
  const GrammarLensApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GrammarLens',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: const EditorPage(),
    );
  }
}
