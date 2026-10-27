import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'api.dart';
import 'ui.dart';

/// Stands in for real SMS and email. Demo only.
class InboxScreen extends StatefulWidget {
  final Api api;
  const InboxScreen({super.key, required this.api});
  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  List<Map<String, dynamic>> msgs = [];
  String? error;
  Timer? timer;
  final filter = TextEditingController();
  String viewer = 'all';

  @override
  void initState() {
    super.initState();
    load();
    timer = Timer.periodic(const Duration(seconds: 3), (_) => load());
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  bool matchesViewer(Map<String, dynamic> m) {
    final role = s(m['to_role']).toLowerCase();
    final kind = s(m['kind']).toLowerCase();
    final body = s(m['body']).toLowerCase();
    switch (viewer) {
      case 'requester':
        return role.contains('requester') ||
            kind.contains('requester') ||
            kind.contains('link-requester') ||
            body.contains('requester') ||
            body.contains('request');
      case 'other':
        return role.contains('other') ||
            kind.contains('other') ||
            kind.contains('link-other') ||
            kind.contains('buyer') ||
            kind.contains('seller') ||
            body.contains('other party') ||
            body.contains('buyer') ||
            body.contains('seller');
      default:
        return true;
    }
  }

  Future<void> load() async {
    try {
      final q = filter.text.trim();
      final param = q.isEmpty ? '' : '?phone=${Uri.encodeQueryComponent(q)}';
      final r = await widget.api.get('/api/demo/inbox$param') as List<dynamic>;
      if (mounted)
        setState(() {
          msgs = r
              .map((e) => Map<String, dynamic>.from(e as Map))
              .where(matchesViewer)
              .toList();
          error = null;
        });
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Win(
      title: 'Demo phone inbox',
      sub: 'stands in for real SMS',
      status: 'Refreshes every 3 seconds.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFE9A8),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFB08400)),
            ),
            child: const Text(
              'DEMO ONLY. Real Kranti sends SMS and email. Here every message lands in this list, so you can open the links and read the codes as a requester or other party would. The subscriber never sees a code in real life.',
              style: TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: K.line),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: viewer,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All views')),
                  DropdownMenuItem(value: 'requester', child: Text('Requester only')),
                  DropdownMenuItem(value: 'other', child: Text('Other party only')),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => viewer = v);
                  load();
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          labeledField(
            'Show one number or email (leave empty for all)',
            filter,
            type: TextInputType.phone,
          ),
          KButton('Filter', onPressed: load),
          const SizedBox(height: 8),
          if (error != null) InfoBanner(error!, kind: 'bad'),
          if (msgs.isEmpty && error == null) const Text('No messages yet for this view.'),
          for (final m in msgs) bubble(m),
        ],
      ),
    );
  }

  Widget bubble(Map<String, dynamic> m) {
    final kind = m['kind'] as String;
    final label = kind == 'email'
        ? 'Email (recorded, not really sent)'
        : kind == 'code'
        ? 'SMS: one-time code'
        : 'SMS: link';
    final body = s(m['body']);
    final match = RegExp(r'https?://\S+').firstMatch(body);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: kind == 'code'
            ? const Color(0xFFFFF6D6)
            : kind == 'email'
            ? const Color(0xFFEAF0FA)
            : const Color(0xFFEEF6EE),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: K.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label · to ${m['to_phone']} · ${fmtDateTime(m['created_at'])}',
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 3),
          SelectableText(body),
          if (match != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: KButton(
                  'Copy link',
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: match.group(0)!),
                    );
                    if (mounted)
                      toast(
                        context,
                        'Link copied. Paste it into a browser to open it as the requester or other party.',
                      );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}
