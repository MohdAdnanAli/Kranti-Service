import 'package:flutter/material.dart';

import 'api.dart';
import 'login.dart';
import 'shell.dart';
import 'ui.dart';

void main() => runApp(const KrantiApp());

class KrantiApp extends StatefulWidget {
  const KrantiApp({super.key});
  @override
  State<KrantiApp> createState() => _KrantiAppState();
}

class _KrantiAppState extends State<KrantiApp> {
  Api? api;
  Map<String, dynamic>? user;
  Map<String, dynamic>? org;

  @override
  Widget build(BuildContext context) {
    final Widget home;
    if (api == null) {
      home = LoginScreen(
        onLogin: (a, u, o) => setState(() {
          api = a;
          user = u;
          org = o;
        }),
      );
    } else {
      home = Shell(
        api: api!,
        user: user!,
        org: org!,
        onLogout: () => setState(() {
          api = null;
          user = null;
          org = null;
        }),
      );
    }
    return MaterialApp(
      title: 'Kranti Transport',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: K.teal,
        primaryColor: K.titleA,
        colorScheme: ColorScheme.fromSeed(
          seedColor: K.titleA,
          primary: K.titleA,
          secondary: K.titleB,
          surface: Colors.white,
        ),
        fontFamilyFallback: const ['Tahoma', 'Segoe UI', 'Arial'],
        appBarTheme: const AppBarTheme(
          backgroundColor: K.titleA,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: K.line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: K.titleA, width: 1.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: K.line),
          ),
        ),
      ),
      home: home,
    );
  }
}
