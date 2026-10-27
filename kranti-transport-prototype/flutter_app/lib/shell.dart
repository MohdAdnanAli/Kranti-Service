import 'dart:async';

import 'package:flutter/material.dart';

import 'api.dart';
import 'create.dart';
import 'dashboard.dart';
import 'inbox.dart';
import 'orders.dart';
import 'profile.dart';
import 'ui.dart';

/// The toolbar and the "new request" pop-up alert.
class Shell extends StatefulWidget {
  final Api api;
  final Map<String, dynamic> user;
  final Map<String, dynamic> org;
  final VoidCallback onLogout;
  const Shell({
    super.key,
    required this.api,
    required this.user,
    required this.org,
    required this.onLogout,
  });
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  static const List<String> names = [
    'Dashboard',
    'Profile',
    'Create',
    'Orders',
    'Demo phone',
  ];
  int tab = 0;
  Timer? timer;
  final Set<int> seen = <int>{};
  bool dialogOpen = false;

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 5), (_) => poll());
    poll();
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> poll() async {
    if (dialogOpen || !mounted) return;
    try {
      final list = await widget.api.get('/api/alerts') as List<dynamic>;
      for (final a in list) {
        final m = Map<String, dynamic>.from(a as Map);
        final id = (m['id'] as num).toInt();
        if (seen.contains(id)) continue;
        seen.add(id);
        dialogOpen = true;
        final open = await showAlert(m);
        dialogOpen = false;
        try {
          await widget.api.post('/api/alerts/$id/ack');
        } catch (_) {}
        if (open && mounted) openOrder(id);
        break;
      }
    } catch (_) {}
  }

  Future<bool> showAlert(Map<String, dynamic> a) async {
    final r = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        title: const Text('New request to approve'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${a['req_name']} sent a ${a['template'] == 'load' ? 'Load (pick-up)' : 'Unload (drop)'} request (${a['code']}).',
            ),
            const SizedBox(height: 10),
            const Text('Approve or deny within:'),
            Countdown(expiresAt: (a['expires_at'] as num).toInt()),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Later'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Open request'),
          ),
        ],
      ),
    );
    return r ?? false;
  }

  void openOrder(int id) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderDetailScreen(api: widget.api, id: id),
      ),
    );
  }

  Widget body() {
    switch (tab) {
      case 0:
        return DashboardScreen(
          api: widget.api,
          org: widget.org,
          onOpen: openOrder,
        );
      case 1:
        return ProfileScreen(api: widget.api);
      case 2:
        return CreateScreen(
          api: widget.api,
          onGoto: (t) => setState(() => tab = t),
        );
      case 3:
        return OrdersScreen(api: widget.api, onOpen: openOrder);
      default:
        return InboxScreen(api: widget.api);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: K.face,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (int i = 0; i < names.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: KButton(
                          names[i],
                          primary: tab == i,
                          onPressed: () => setState(() => tab = i),
                        ),
                      ),
                    KButton('Log off', onPressed: widget.onLogout),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 920),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(10),
                    child: KeyedSubtree(key: ValueKey<int>(tab), child: body()),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
