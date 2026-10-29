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
    final navItems = <({String label, IconData icon, int index, bool highlight})>[
      (label: 'Dashboard', icon: Icons.dashboard_outlined, index: 0, highlight: false),
      (label: 'Profile', icon: Icons.person_outline, index: 1, highlight: false),
      (label: 'Create', icon: Icons.add_circle_outlined, index: 2, highlight: true),
      (label: 'Orders', icon: Icons.receipt_long_outlined, index: 3, highlight: false),
      (label: 'Demo inbox', icon: Icons.inbox_outlined, index: 4, highlight: false),
    ];

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
                colors: [Color(0xFFE9F1F5), Color(0xFFEAEAE5), Color(0xFFE4F3F0)],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final maxWidth = constraints.maxWidth > 980 ? 980.0 : constraints.maxWidth;
                        return Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: maxWidth),
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
                              child: KeyedSubtree(key: ValueKey<int>(tab), child: body()),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              top: false,
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: const Color(0xFFCFD8E3)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x22000000),
                      blurRadius: 16,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final item in navItems)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Tooltip(
                          message: item.label,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () => setState(() => tab = item.index),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 54,
                                height: 54,
                                decoration: BoxDecoration(
                                  color: item.highlight
                                      ? const Color(0xFF1BAE67)
                                      : (tab == item.index ? K.titleA : Colors.transparent),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Icon(
                                  item.icon,
                                  size: 22,
                                  color: item.highlight
                                      ? Colors.white
                                      : (tab == item.index ? Colors.white : K.titleA),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Tooltip(
                        message: 'Log off',
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: widget.onLogout,
                            child: Container(
                              width: 54,
                              height: 54,
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: const Icon(
                                Icons.logout_outlined,
                                color: K.titleA,
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
