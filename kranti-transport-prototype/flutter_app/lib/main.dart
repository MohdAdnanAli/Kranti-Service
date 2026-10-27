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
        useMaterial3: false,
        scaffoldBackgroundColor: K.teal,
        primaryColor: K.titleA,
        fontFamilyFallback: const ['Tahoma', 'Segoe UI', 'Arial'],
      ),
      home: home,
    );
  }
}
