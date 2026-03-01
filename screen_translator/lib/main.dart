import 'package:flutter/material.dart';

import 'screens/main_shell.dart';
import 'services/settings_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SettingsService.instance.load();
  runApp(const ScreenTranslatorApp());
}

class ScreenTranslatorApp extends StatelessWidget {
  const ScreenTranslatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Screen Translator',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0)),
        useMaterial3: true,
      ),
      home: const MainShell(),
    );
  }
}
