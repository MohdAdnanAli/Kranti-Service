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
      body: Stack(
        children: [
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0C4A6E), Color(0xFF0D7A8B), Color(0xFF0F8F7A)],
              ),
            ),
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final formWidth = constraints.maxWidth > 600 ? 520.0 : constraints.maxWidth - 24;
                  return Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(12),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: formWidth),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.96),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x26000000),
                                blurRadius: 20,
                                offset: Offset(0, 14),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: 6),
                              const Text(
                                'Kranti',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 28,
                                  color: K.titleA,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const Text(
                                'Gold transporter',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.black54,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 18),
                              const Text(
                                'Do your trade honestly and securely',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: K.titleA,
                                ),
                              ),
                              const SizedBox(height: 10),
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
                              const SizedBox(height: 12),
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
                  );
                },
              ),
            ),
          ),
          const DemoSecurityOverlay(),
        ],
      ),
    );
  }
}
