import 'package:flutter/material.dart';

import 'api.dart';
import 'orders.dart';
import 'ui.dart';

class DashboardScreen extends StatefulWidget {
  final Api api;
  final Map<String, dynamic> org;
  final void Function(int id) onOpen;
  const DashboardScreen({
    super.key,
    required this.api,
    required this.org,
    required this.onOpen,
  });
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? data;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final r = await widget.api.get('/api/dashboard') as Map<String, dynamic>;
      if (mounted)
        setState(() {
          data = r;
          error = null;
        });
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    }
  }

  Widget tile(String label, int n) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFEFEDE4),
        border: Border.all(color: K.line),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$n',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = data;
    Widget child;
    if (d == null) {
      child = Text(error ?? 'Loading...');
    } else {
      final c = Map<String, dynamic>.from(d['counts'] as Map);
      int n(String k) => (c[k] as num?)?.toInt() ?? 0;
      final recent = (d['recent'] as List<dynamic>)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      child = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              tile('Total orders', n('total')),
              tile('Waiting for requester', n('created')),
              tile('Need your decision', n('submitted')),
              tile('Active', n('active')),
              tile('Overdue', n('overdue')),
              tile('Dormant', n('dormant')),
              tile('Sealed', n('sealed')),
              tile(
                'Closed without seal',
                n('denied') + n('expired') + n('cancelled'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Recent orders',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 6),
          if (recent.isEmpty)
            const Text('No orders yet. Use Create to send your first request.'),
          for (final o in recent)
            OrderRow(
              o: o,
              onOpen: () => widget.onOpen((o['id'] as num).toInt()),
            ),
        ],
      );
    }
    return Win(
      title: 'Dashboard',
      sub: s(widget.org['name']),
      status:
          'Plan: ${s(widget.org['plan'])} · valid until ${fmtDate(widget.org['valid_until'])}',
      child: child,
    );
  }
}
