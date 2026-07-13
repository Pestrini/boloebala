import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'pages/home_page.dart';
import 'pages/admin_page.dart';
import 'pages/login_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://supabase.vps9867.panel.icontainer.net',
    anonKey:
        'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpYXQiOjE3ODM5MTk4MjgsImV4cCI6MTc4MzkyMzQyOCwicm9sZSI6ImFub24iLCJpc3MiOiJzdXBhYmFzZSJ9.nBL0OA3LleLXxkIKAwlEPJj2FL_7X6fHzA2pkiNHvws',
  );

  runApp(const BoloBalaApp());
}

class BoloBalaApp extends StatelessWidget {
  const BoloBalaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bolo & Bala',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.pink),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const HomePage(),
        '/admin': (context) => const LoginPage(),
      },
    );
  }
}
