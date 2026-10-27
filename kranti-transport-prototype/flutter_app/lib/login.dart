import 'package:flutter/material.dart';

import 'api.dart';
import 'ui.dart';

class LoginScreen extends StatefulWidget {
  final void Function(
    Api api,
    Map<String, dynamic> user,
    Map<String, dynamic> org,
  )
  onLogin;
  const LoginScreen({super.key, required this.onLogin});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final server = TextEditingController(text: 'http://localhost:4180');
  final email = TextEditingController(text: 'adnan@xyz.com');
  final pass = TextEditingController(text: 'Password@123');
  String? error;
  bool busy = false;

  Future<void> login() async {
    setState(() {
      busy = true;
      error = null;
    });
    final api = Api(server.text.trim());
    try {
      final r = await api.post('/api/login', {
        'email': email.text.trim(),
        'password': pass.text,
      }) as Map<String, dynamic>;
      api.token = r['token'] as String;
      Api.offsetMs =
          (r['now'] as num).toInt() - DateTime.now().millisecondsSinceEpoch;
      widget.onLogin(
        api,
        Map<String, dynamic>.from(r['user'] as Map),
        Map<String, dynamic>.from(r['org'] as Map),
      );
    } on ApiException catch (e) {
      if (mounted)
        setState(() {
          error = e.message;
          busy = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          error = '$e';
          busy = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Win(
                title: 'Kranti: sign in',
                sub: 'Gold (transporter)',
                status: 'Demo only. The login is pre-filled.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Do your trade honestly and securely',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    labeledField(
                      'Server address',
                      server,
                      type: TextInputType.url,
                    ),
                    const Text(
                      'Use http://localhost:4180 on this computer or in a browser, http://10.0.2.2:4180 in an Android emulator, '
                      'or your computer\'s network address (for example http://192.168.1.20:4180) on a real phone.',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    labeledField(
                      'Email',
                      email,
                      type: TextInputType.emailAddress,
                    ),
                    labeledField('Password', pass, obscure: true),
                    if (error != null) InfoBanner(error!, kind: 'bad'),
                    const SizedBox(height: 8),
                    KButton(
                      busy ? 'Signing in...' : 'Sign in',
                      primary: true,
                      wide: true,
                      onPressed: busy ? null : login,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
