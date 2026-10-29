import 'dart:async';

import 'package:flutter/material.dart';

import 'api.dart';

/// Kranti's look: the old-school window style, a generation newer.
class K {
  static const Color teal = Color(0xFF0B5F6A);
  static const Color face = Color(0xFFEFECE7);
  static const Color titleA = Color(0xFF0A3A6B);
  static const Color titleB = Color(0xFF2C7AA6);
  static const Color line = Color(0xFFB8C2D0);
  static const Color ink = Color(0xFF101010);
  static const Color ok = Color(0xFF0E7B55);
  static const Color okBg = Color(0xFFE7F8F0);
  static const Color warn = Color(0xFF8A6300);
  static const Color warnBg = Color(0xFFFFF3D6);
  static const Color danger = Color(0xFF9A1414);
  static const Color dangerBg = Color(0xFFFBE3E3);
  static const Color infoBg = Color(0xFFE6EEF8);
}

const List<String> _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String fmtDate(dynamic v) {
  if (v == null || v.toString().isEmpty) return '-';
  final p = v.toString().split('-');
  if (p.length != 3) return v.toString();
  return '${int.parse(p[2])} ${_months[int.parse(p[1]) - 1]} ${p[0]}';
}

String fmtDateTime(dynamic ms) {
  if (ms == null) return '-';
  final d = DateTime.fromMillisecondsSinceEpoch((ms as num).toInt());
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.day} ${_months[d.month - 1]} ${d.year}, ${two(d.hour)}:${two(d.minute)}';
}

String mmss(int ms) {
  final total = (ms < 0 ? 0 : ms) ~/ 1000;
  final m = (total ~/ 60).toString().padLeft(2, '0');
  final s = (total % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

/// Text or a dash when empty.
String s(dynamic v) =>
    (v == null || v.toString().trim().isEmpty) ? '-' : v.toString();

void toast(BuildContext context, String message, {bool bad = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: bad ? K.danger : K.titleA,
      behavior: SnackBarBehavior.floating,
    ),
  );
}

class DemoSecurityOverlay extends StatelessWidget {
  const DemoSecurityOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Opacity(
          opacity: 0.18,
          child: Transform.rotate(
            angle: -0.48,
            child: Center(
              child: Text(
                'PRE-DEV DEMO\nNO SCREENSHOTS\nPRIVATE DATA ONLY',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.4,
                  color: const Color(0xFF0B3A5C).withValues(alpha: 0.8),
                  shadows: const [
                    Shadow(color: Color(0x66000000), blurRadius: 18),
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

Future<bool> confirmDialog(
  BuildContext context,
  String text, {
  String yes = 'Yes',
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      content: Text(text),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c, false),
          child: const Text('No'),
        ),
        TextButton(onPressed: () => Navigator.pop(c, true), child: Text(yes)),
      ],
    ),
  );
  return r ?? false;
}

class TitleBar extends StatelessWidget {
  final String title;
  final String? sub;
  const TitleBar(this.title, {super.key, this.sub});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [K.titleA, K.titleB]),
      ),
      child: Row(
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (sub != null)
            Text(
              sub!,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
        ],
      ),
    );
  }
}

/// An old-school window: title bar, white body and a status line.
class Win extends StatelessWidget {
  final String title;
  final String? sub;
  final Widget child;
  final String? status;
  const Win({
    super.key,
    required this.title,
    required this.child,
    this.sub,
    this.status,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: K.face,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF4F6478)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TitleBar(title, sub: sub),
          Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: K.line),
            ),
            child: child,
          ),
          if (status != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Text(
                status!,
                style: const TextStyle(fontSize: 11, color: Colors.black54),
              ),
            ),
        ],
      ),
    );
  }
}

class KButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool primary;
  final bool danger;
  final bool wide;
  const KButton(
    this.label, {
    super.key,
    this.onPressed,
    this.primary = false,
    this.danger = false,
    this.wide = false,
  });
  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final List<Color> colors = danger
        ? const [Color(0xFFC04040), Color(0xFF8A1414)]
        : primary
        ? const [Color(0xFF4F8FC7), Color(0xFF0A3A6B)]
        : const [Color(0xFFF8F6F1), Color(0xFFE5E0D4)];
    final Color fg = (primary || danger) ? Colors.white : K.ink;
    final button = Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: colors,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: primary || danger ? const Color(0xFF1B3A5C) : K.line,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1C000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w700, color: fg),
              ),
            ),
          ),
        ),
      ),
    );
    return wide ? SizedBox(width: double.infinity, child: button) : button;
    return wide ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// A collapsible section with a blue title bar. Tap the title to open or close.
class SectionPanel extends StatefulWidget {
  final String title;
  final Widget child;
  final bool initiallyOpen;
  final String? trailing;
  final bool isOpen;
  final ValueChanged<bool>? onToggle;
  const SectionPanel({
    super.key,
    required this.title,
    required this.child,
    this.initiallyOpen = false,
    this.trailing,
    this.isOpen = false,
    this.onToggle,
  });
  @override
  State<SectionPanel> createState() => _SectionPanelState();
}

class _SectionPanelState extends State<SectionPanel> {
  late bool open = widget.isOpen || widget.initiallyOpen;

  @override
  void didUpdateWidget(covariant SectionPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOpen != oldWidget.isOpen) {
      open = widget.isOpen;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isExpanded = widget.isOpen || open;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        border: Border.all(color: K.line),
        borderRadius: BorderRadius.circular(6),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () {
              final next = !isExpanded;
              if (widget.onToggle != null) {
                widget.onToggle!(next);
              } else {
                setState(() => open = next);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [K.titleA, K.titleB]),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${isExpanded ? '▾' : '▸'}  ${widget.title}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (widget.trailing != null)
                    Text(
                      widget.trailing!,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Padding(padding: const EdgeInsets.all(12), child: widget.child),
        ],
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  final String status;
  const StatusPill({super.key, required this.status});
  @override
  Widget build(BuildContext context) {
    const labels = {
      'created': 'Waiting for requester',
      'submitted': 'Needs your decision',
      'active': 'Active',
      'sealed': 'Sealed',
      'denied': 'Denied',
      'expired': 'Expired',
      'cancelled': 'Cancelled',
      'overdue': 'Overdue',
      'dormant': 'Dormant',
    };
    Color fg = K.warn, bg = K.warnBg;
    if (status == 'active' || status == 'sealed') {
      fg = K.ok;
      bg = K.okBg;
    }
    if (status == 'denied' ||
        status == 'expired' ||
        status == 'cancelled' ||
        status == 'dormant') {
      fg = K.danger;
      bg = K.dangerBg;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: fg.withValues(alpha: 0.5)),
      ),
      child: Text(
        labels[status] ?? status,
        style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class InfoBanner extends StatelessWidget {
  final String text;
  final String kind; // info, ok, warn, bad
  const InfoBanner(this.text, {super.key, this.kind = 'info'});
  @override
  Widget build(BuildContext context) {
    Color fg = K.ink, bg = K.infoBg;
    if (kind == 'ok') {
      fg = K.ok;
      bg = K.okBg;
    }
    if (kind == 'warn') {
      fg = K.warn;
      bg = K.warnBg;
    }
    if (kind == 'bad') {
      fg = K.danger;
      bg = K.dangerBg;
    }
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: fg.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        style: TextStyle(color: fg, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Label and value rows.
class KV extends StatelessWidget {
  final List<List<String>> rows;
  const KV(this.rows, {super.key});
  @override
  Widget build(BuildContext context) {
    return Column(
      children: rows
          .map(
            (r) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 118,
                    child: Text(
                      r[0],
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ),
                  Expanded(
                    child: SelectableText(
                      r[1].isEmpty ? '-' : r[1],
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

/// A labelled text box with an optional exact error from the server.
Widget labeledField(
  String label,
  TextEditingController c, {
  String? error,
  bool required = false,
  TextInputType? type,
  int? maxLength,
  bool obscure = false,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          required ? '$label *' : label,
          style: const TextStyle(fontSize: 13, color: Colors.black87),
        ),
        const SizedBox(height: 3),
        TextField(
          controller: c,
          keyboardType: type,
          maxLength: maxLength,
          obscureText: obscure,
          decoration: InputDecoration(
            isDense: true,
            counterText: '',
            errorText: error,
            filled: true,
            fillColor: Colors.white,
            border: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(5)),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 10,
            ),
          ),
        ),
      ],
    ),
  );
}

/// A live mm:ss countdown to a server time.
class Countdown extends StatefulWidget {
  final int expiresAt;
  const Countdown({super.key, required this.expiresAt});
  @override
  State<Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<Countdown> {
  Timer? timer;
  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final left = widget.expiresAt - Api.serverNow();
    return Text(
      left <= 0 ? '0:00 left' : '${mmss(left)} left',
      style: TextStyle(
        fontWeight: FontWeight.bold,
        color: left < 5 * 60 * 1000 ? K.danger : K.warn,
      ),
    );
  }
}
