import 'dart:async';

import 'package:flutter/material.dart';

import 'api.dart';
import 'ui.dart';

String templateLabel(dynamic t) =>
    t == 'load' ? 'Load (pick-up)' : 'Unload (drop)';

class OrderRow extends StatelessWidget {
  final Map<String, dynamic> o;
  final VoidCallback onOpen;
  final Widget? extra;
  const OrderRow({
    super.key,
    required this.o,
    required this.onOpen,
    this.extra,
  });

  @override
  Widget build(BuildContext context) {
    final status = o['status'] as String;
    final flag = o['flag'] as String?;
    final waiting = status == 'created' || status == 'submitted';
    final other = s(o['oth_name']) == '-' ? '' : '  →  ${o['oth_name']}';
    return InkWell(
      onTap: onOpen,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: K.line),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  s(o['code']),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(templateLabel(o['template'])),
                StatusPill(status: status),
                if (flag != null) StatusPill(status: flag),
                if (waiting)
                  Countdown(expiresAt: (o['expires_at'] as num).toInt()),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${s(o['req_name'])}$other',
              style: const TextStyle(color: Colors.black54),
            ),
            if (extra != null) ...[const SizedBox(height: 6), extra!],
          ],
        ),
      ),
    );
  }
}

class OrdersScreen extends StatefulWidget {
  final Api api;
  final void Function(int id) onOpen;
  const OrdersScreen({super.key, required this.api, required this.onOpen});
  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  List<Map<String, dynamic>>? orders;
  String? error;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    load();
    timer = Timer.periodic(const Duration(seconds: 5), (_) => load());
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final r = await widget.api.get('/api/orders') as List<dynamic>;
      if (mounted)
        setState(() {
          orders = r.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          error = null;
        });
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    }
  }

  Future<void> resend(int id) async {
    try {
      await widget.api.post('/api/orders/$id/resend');
      if (mounted) toast(context, 'A new link was sent to the requester.');
      await load();
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, bad: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = orders;
    return Win(
      title: 'Orders',
      sub: list == null ? '' : '${list.length} orders',
      status: 'Tap an order to open it. The list refreshes every 5 seconds.',
      child: list == null
          ? Text(error ?? 'Loading...')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (list.isEmpty)
                  const Text(
                    'No orders yet. Use Create to send your first request.',
                  ),
                for (final o in list)
                  OrderRow(
                    o: o,
                    onOpen: () => widget.onOpen((o['id'] as num).toInt()),
                    extra: o['status'] == 'expired'
                        ? Align(
                            alignment: Alignment.centerLeft,
                            child: KButton(
                              'Resend link',
                              onPressed: () => resend((o['id'] as num).toInt()),
                            ),
                          )
                        : null,
                  ),
              ],
            ),
    );
  }
}

class OrderDetailScreen extends StatefulWidget {
  final Api api;
  final int id;
  const OrderDetailScreen({super.key, required this.api, required this.id});
  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  Map<String, dynamic>? data;
  List<Map<String, dynamic>> drivers = [];
  List<Map<String, dynamic>> vehicles = [];
  String? loadError;
  String? msg;
  bool msgBad = false;
  bool busy = false;
  bool inited = false;
  int? driverId;
  int? vehicleId;
  Timer? timer;
  final refCtl = TextEditingController();
  final emailCtl = TextEditingController();
  final codeCtl = TextEditingController();

  @override
  void initState() {
    super.initState();
    load();
    timer = Timer.periodic(const Duration(seconds: 4), (_) => load());
  }

  @override
  void dispose() {
    timer?.cancel();
    refCtl.dispose();
    emailCtl.dispose();
    codeCtl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> asList(dynamic v) => (v as List<dynamic>)
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();

  Future<void> load() async {
    try {
      final r = await widget.api.get(
        '/api/orders/${widget.id}',
      ) as Map<String, dynamic>;
      if (!inited) {
        final p = await widget.api.get('/api/profile') as Map<String, dynamic>;
        drivers = asList(p['drivers']);
        vehicles = asList(p['vehicles']);
        final o = Map<String, dynamic>.from(r['order'] as Map);
        driverId = (o['driver_id'] as num?)?.toInt();
        final match = vehicles.where((v) => v['reg_no'] == o['vehicle_no']);
        vehicleId = match.isEmpty ? null : (match.first['id'] as num).toInt();
        emailCtl.text = (o['oth_email'] ?? '').toString();
        refCtl.text = (o['ref_receipt'] ?? '').toString();
        inited = true;
      }
      if (mounted)
        setState(() {
          data = r;
          loadError = null;
        });
    } on ApiException catch (e) {
      if (mounted) setState(() => loadError = e.message);
    }
  }

  Future<void> act(Future<String> Function() f) async {
    setState(() {
      busy = true;
      msg = null;
    });
    try {
      final m = await f();
      if (mounted)
        setState(() {
          msg = m;
          msgBad = false;
        });
    } on ApiException catch (e) {
      if (mounted)
        setState(() {
          msg = e.message;
          msgBad = true;
        });
    }
    if (mounted) setState(() => busy = false);
    await load();
  }

  String get base => '/api/orders/${widget.id}';

  Future<void> decide(String d) async {
    if (d == 'deny' &&
        !await confirmDialog(
          context,
          'Deny this request? The requester will have to ask you again informally.',
          yes: 'Deny',
        ))
      return;
    await act(() async {
      await widget.api.post('$base/decision', {'decision': d});
      return d == 'accept'
          ? 'Accepted. Add the driver and vehicle, then send for confirmation at the handover.'
          : 'Denied.';
    });
  }

  Future<void> cancel() async {
    if (!await confirmDialog(
      context,
      'Cancel this order? This cannot be undone.',
      yes: 'Cancel order',
    ))
      return;
    await act(() async {
      await widget.api.post('$base/cancel');
      return 'Order cancelled.';
    });
  }

  Future<void> resend() => act(() async {
    await widget.api.post('$base/resend');
    return 'A new link was sent to the requester.';
  });

  Future<void> saveTransport() => act(() async {
    await widget.api.patch('$base/transport', {
      'driver_id': driverId,
      'vehicle_id': vehicleId,
    });
    return 'Driver and vehicle saved.';
  });

  Future<void> recordRef() => act(() async {
    await widget.api.post('$base/reference', {
      'ref_receipt': refCtl.text.trim(),
    });
    return 'Reference receipt recorded. Driver and vehicle are now locked.';
  });

  Future<void> saveEmail() => act(() async {
    await widget.api.patch('$base/other-email', {
      'email': emailCtl.text.trim(),
    });
    return 'Email saved. The other party will receive the receipt there.';
  });

  Future<void> sendConfirm() => act(() async {
    await widget.api.post('$base/send-confirm');
    return 'Confirmation link sent to the other party. In this demo it appears in the Demo phone tab.';
  });

  Future<void> seal() => act(() async {
    final r = await widget.api.post('$base/seal', {
      'code': codeCtl.text.trim(),
    }) as Map<String, dynamic>;
    codeCtl.clear();
    return 'Sealed. GDRN ${r['akrn']} issued. The emailed verify link is in the Demo phone tab.';
  });

  Widget pick(
    String label,
    int? value,
    List<Map<String, dynamic>> items,
    String Function(Map<String, dynamic>) text,
    void Function(int?) onChanged,
    bool enabled,
  ) {
    final ok = items.any((x) => (x['id'] as num).toInt() == value);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 3),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.black45),
              borderRadius: BorderRadius.circular(5),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int?>(
                isExpanded: true,
                value: ok ? value : null,
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('None yet'),
                  ),
                  for (final x in items)
                    DropdownMenuItem<int?>(
                      value: (x['id'] as num).toInt(),
                      child: Text(text(x)),
                    ),
                ],
                onChanged: enabled ? onChanged : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = data;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: KButton(
                      '‹ Back',
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (d == null)
                    Win(title: 'Order', child: Text(loadError ?? 'Loading...'))
                  else
                    content(d),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget content(Map<String, dynamic> d) {
    final o = Map<String, dynamic>.from(d['order'] as Map);
    final status = o['status'] as String;
    final flag = o['flag'] as String?;
    final locked = o['locked_at'] != null;
    final confirmSent = o['confirm_sent_at'] != null;
    final code = d['code'] == null
        ? null
        : Map<String, dynamic>.from(d['code'] as Map);
    final receipt = d['receipt'] == null
        ? null
        : Map<String, dynamic>.from(d['receipt'] as Map);
    final open =
        status == 'created' || status == 'submitted' || status == 'active';
    final other = o['template'] == 'load' ? 'Seller' : 'Buyer';
    final submitted = o['submitted_at'] != null;

    Widget banner;
    switch (status) {
      case 'created':
        banner = Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          children: [
            const Text('Waiting for the requester to fill the form.'),
            Countdown(expiresAt: (o['expires_at'] as num).toInt()),
          ],
        );
        break;
      case 'submitted':
        banner = Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          children: [
            const Text(
              'The requester submitted the form. Accept or deny within',
            ),
            Countdown(expiresAt: (o['expires_at'] as num).toInt()),
          ],
        );
        break;
      case 'active':
        banner = Text(
          !confirmSent
              ? 'Accepted. Add driver and vehicle, then send for confirmation at the handover.'
              : code != null
              ? 'The other party released a code (valid until ${fmtDateTime(code['live_until'])}). Ask them to read it out, then enter it below.'
              : 'Confirmation sent. Waiting for the other party to press "Get my code".',
        );
        break;
      case 'sealed':
        banner = const Text('Sealed. The GDRN has been issued.');
        break;
      case 'denied':
        banner = const Text('You denied this request.');
        break;
      case 'expired':
        banner = const Text(
          'This request expired. Resend the link to start again.',
        );
        break;
      default:
        banner = const Text('This order was cancelled.');
    }

    return Win(
      title: 'Order ${s(o['code'])}',
      sub: templateLabel(o['template']),
      status: 'Created ${fmtDateTime(o['created_at'])}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            children: [
              StatusPill(status: status),
              if (flag != null) StatusPill(status: flag),
            ],
          ),
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: K.infoBg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: K.line),
            ),
            child: DefaultTextStyle(
              style: const TextStyle(color: K.ink, fontWeight: FontWeight.w600),
              child: banner,
            ),
          ),
          if (msg != null) InfoBanner(msg!, kind: msgBad ? 'bad' : 'ok'),
          if (status == 'submitted')
            Row(
              children: [
                Expanded(
                  child: KButton(
                    'Accept',
                    primary: true,
                    onPressed: busy ? null : () => decide('accept'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: KButton(
                    'Deny',
                    danger: true,
                    onPressed: busy ? null : () => decide('deny'),
                  ),
                ),
              ],
            ),
          if (status == 'expired')
            KButton(
              'Resend link to the requester',
              primary: true,
              wide: true,
              onPressed: busy ? null : resend,
            ),
          SectionPanel(
            title: 'Requester and goods',
            initiallyOpen: status == 'submitted',
            child: !submitted
                ? const Text('The requester has not submitted the form yet.')
                : KV([
                    ['Requester', s(o['req_name'])],
                    ['GSTIN', s(o['req_gstin'])],
                    ['Mobile', s(o['req_phone'])],
                    ['Alternate number', s(o['req_alt_phone'])],
                    ['Email', s(o['req_email'])],
                    ['Goods', s(o['goods_desc'])],
                    ['Items (nos)', s(o['goods_nos'])],
                    ['Unit', s(o['goods_unit'])],
                    ['Weight', s(o['goods_weight'])],
                    ['Order date', fmtDate(o['order_date'])],
                    [
                      'Lifting window',
                      '${fmtDate(o['lift_from'])} to ${fmtDate(o['lift_to'])}',
                    ],
                    [
                      'Expected delivery',
                      '${fmtDate(o['deliver_from'])} to ${fmtDate(o['deliver_to'])}',
                    ],
                  ]),
          ),
          SectionPanel(
            title: '$other (other party)',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!submitted)
                  const Text('Not filled yet.')
                else
                  KV([
                    ['Name', s(o['oth_name'])],
                    ['GSTIN', s(o['oth_gstin'])],
                    ['Address', s(o['oth_address'])],
                    [
                      o['template'] == 'load'
                          ? 'Pick-up address'
                          : 'Drop address',
                      s(o['oth_site']),
                    ],
                    ['Mobile', s(o['oth_phone'])],
                    ['Alternate number', s(o['oth_alt_phone'])],
                    ['Email', s(o['oth_email'])],
                  ]),
                if (open && submitted) ...[
                  const SizedBox(height: 8),
                  labeledField(
                    'Add or change their email (they get the receipt there)',
                    emailCtl,
                    type: TextInputType.emailAddress,
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: KButton(
                      'Save email',
                      onPressed: busy ? null : saveEmail,
                    ),
                  ),
                ],
              ],
            ),
          ),
          SectionPanel(
            title: 'Transport',
            initiallyOpen: status == 'active' && !locked,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (locked)
                  KV([
                    ['Driver', s(o['driver_name'])],
                    [
                      'Vehicle',
                      '${s(o['vehicle_no'])} ${o['vehicle_type'] ?? ''}'.trim(),
                    ],
                    ['Reference receipt', s(o['ref_receipt'])],
                  ])
                else ...[
                  pick(
                    'Driver',
                    driverId,
                    drivers,
                    (x) => '${x['name']}',
                    (v) => setState(() => driverId = v),
                    open,
                  ),
                  pick(
                    'Vehicle',
                    vehicleId,
                    vehicles,
                    (x) => '${x['reg_no']}  ${x['vtype'] ?? ''}',
                    (v) => setState(() => vehicleId = v),
                    open,
                  ),
                  if (open)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: KButton(
                        'Save driver and vehicle',
                        onPressed: busy ? null : saveTransport,
                      ),
                    ),
                  if (status == 'active') ...[
                    const SizedBox(height: 8),
                    labeledField('Reference receipt number', refCtl),
                    const Text(
                      'Recording it locks the driver and vehicle.',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: KButton(
                        'Record reference receipt',
                        onPressed: busy ? null : recordRef,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
          if (status == 'active' || status == 'sealed')
            SectionPanel(
              title: 'End confirmation and seal',
              initiallyOpen: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (status == 'active' && !confirmSent) ...[
                    const Text(
                      'At the handover, send the other party a link. They press "Get my code", read it out to you, and you enter it here. Driver and vehicle lock when you send.',
                    ),
                    const SizedBox(height: 8),
                    KButton(
                      'Send for confirmation',
                      primary: true,
                      wide: true,
                      onPressed: (busy || flag == 'dormant')
                          ? null
                          : sendConfirm,
                    ),
                  ],
                  if (status == 'active' && confirmSent) ...[
                    const Text(
                      'The code is sent to the other party\'s phone, never to you. Ask them to read it out.',
                    ),
                    labeledField(
                      '6-digit code',
                      codeCtl,
                      type: TextInputType.number,
                      maxLength: 6,
                    ),
                    KButton(
                      'Seal now',
                      primary: true,
                      wide: true,
                      onPressed: busy ? null : seal,
                    ),
                    const SizedBox(height: 8),
                    KButton(
                      'Send the link again',
                      onPressed: busy ? null : sendConfirm,
                    ),
                  ],
                  if (status == 'sealed' && receipt != null) ...[
                    const InfoBanner(
                      'Sealed. A receipt goes to everyone with an email on file.',
                      kind: 'ok',
                    ),
                    KV([
                      ['AKRN', s(receipt['akrn'])],
                      ['Sealed at', fmtDateTime(receipt['sealed_at'])],
                      ['Fingerprint', s(receipt['fingerprint'])],
                    ]),
                  ],
                ],
              ),
            ),
          SectionPanel(
            title: 'Messages and emails',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                KV([
                  for (final m in asList(d['sms']))
                    [
                      kindLabel(m['kind']),
                      '${s(m['to'])} · ${s(m['state'])} · ${fmtDateTime(m['created_at'])}',
                    ],
                  for (final e in asList(d['emails']))
                    [
                      'Email: ${s(e['to_role'])}',
                      '${s(e['to_email'])} · ${s(e['status'])}',
                    ],
                ]),
                if (asList(d['sms']).isEmpty && asList(d['emails']).isEmpty)
                  const Text('Nothing sent yet.'),
              ],
            ),
          ),
          SectionPanel(
            title: 'History',
            child: KV([
              for (final e in asList(d['events']))
                [fmtDateTime(e['created_at']), s(e['detail'])],
            ]),
          ),
          if (open) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: KButton(
                'Cancel this order',
                danger: true,
                onPressed: busy ? null : cancel,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String kindLabel(dynamic k) {
    switch (k) {
      case 'link-requester':
        return 'SMS: link to requester';
      case 'link-other':
        return 'SMS: link to other party';
      case 'code':
        return 'SMS: code to other party';
      default:
        return 'SMS';
    }
  }
}
