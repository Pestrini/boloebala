import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'pages/home_page.dart';
import 'pages/admin_page.dart';
import 'pages/login_page.dart';
import 'pages/client_area.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://supabase.vps9867.panel.icontainer.net',
    anonKey:
        'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIiwiaWF0IjoxNzAwMDAwMDAwLCJleHAiOjIwOTkzMTk4Mjh9.ifWYMBU4oaYQdSBrerriEN1x9kBISimeFk31f-sqetY',
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
        '/client': (context) => const ClientAreaPage(),
        '/admin': (context) => const LoginPage(),
      },
    );
  }
}
