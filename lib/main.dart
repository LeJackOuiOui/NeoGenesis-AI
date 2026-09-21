import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/theme/app_theme.dart';
import 'package:neogenesis_ai/screens/home/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://mvaujcjymykgakfcjvjt.supabase.co',
    publishableKey: 'sb_publishable_7IYM29KIJL3aF7LW42TxLg_9oYcS5xC',
  );

  runApp(const MainApp());
}

// Helper global para acceder al cliente de Supabase
final supabase = Supabase.instance.client;

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'NEOGENESIS IA',
      theme: AppTheme.lightTheme,
      home: const HomeScreen(),
    );
  }
}
