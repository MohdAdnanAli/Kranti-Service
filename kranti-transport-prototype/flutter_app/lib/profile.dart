import 'package:flutter/material.dart';

import 'api.dart';
import 'ui.dart';

class FieldDef {
  final String key;
  final String label;
  final TextInputType? type;
  const FieldDef(this.key, this.label, {this.type});
}

class ProfileScreen extends StatefulWidget {
  final Api api;
  const ProfileScreen({super.key, required this.api});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? data;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final r = await widget.api.get('/api/profile') as Map<String, dynamic>;
      if (mounted)
        setState(() {
          data = r;
          error = null;
        });
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    }
  }

  List<Map<String, dynamic>> list(String k) => (data![k] as List<dynamic>)
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();

  @override
  Widget build(BuildContext context) {
    final d = data;
    if (d == null)
      return Win(title: 'Profile', child: Text(error ?? 'Loading...'));
    final org = Map<String, dynamic>.from(d['org'] as Map);
    return Win(
      title: 'Profile',
      sub: s(org['name']),
      status:
          'Everything a request needs comes from here. Nothing is typed twice.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionPanel(
            title: '1. Transporter details',
            initiallyOpen: true,
            child: KV([
              ['Business name', s(org['name'])],
              ['GSTIN', s(org['gstin'])],
              ['Address', s(org['address'])],
              ['Mobile', s(org['phone'])],
              ['Email', s(org['email'])],
              ['Plan', s(org['plan'])],
              ['Valid until', fmtDate(org['valid_until'])],
            ]),
          ),
          CrudSection(
            api: widget.api,
            title: '2. Requesters',
            route: 'parties',
            items: list('parties'),
            addLabel: '+ Add requester',
            fields: const [
              FieldDef('name', 'Name'),
              FieldDef('gstin', 'GSTIN'),
              FieldDef('phone', 'Mobile number', type: TextInputType.phone),
              FieldDef('address', 'Address'),
            ],
            heading: (i) => s(i['name']),
            subline: (i) =>
                'GSTIN ${s(i['gstin'])} · ${s(i['phone'])}\n${s(i['address'])}',
            onChanged: load,
          ),
          CrudSection(
            api: widget.api,
            title: '3. Drivers',
            route: 'drivers',
            items: list('drivers'),
            addLabel: '+ Add driver',
            fields: const [
              FieldDef('name', 'Driver name'),
              FieldDef('phone', 'Mobile number', type: TextInputType.phone),
              FieldDef('licence_no', 'Licence number (optional)'),
            ],
            heading: (i) => s(i['name']),
            subline: (i) => '${s(i['phone'])} · Licence ${s(i['licence_no'])}',
            onChanged: load,
          ),
          CrudSection(
            api: widget.api,
            title: '4. Vehicles',
            route: 'vehicles',
            items: list('vehicles'),
            addLabel: '+ Add vehicle',
            fields: const [
              FieldDef('reg_no', 'Vehicle number (e.g. RJ14GA1234)'),
              FieldDef('vtype', 'Type (e.g. Truck 16 ft)'),
            ],
            heading: (i) => s(i['reg_no']),
            subline: (i) => s(i['vtype']),
            onChanged: load,
          ),
        ],
      ),
    );
  }
}

/// A collapsible list with add, edit and delete. Server errors show exactly as sent.
class CrudSection extends StatelessWidget {
  final Api api;
  final String title;
  final String route;
  final List<Map<String, dynamic>> items;
  final List<FieldDef> fields;
  final String addLabel;
  final String Function(Map<String, dynamic>) heading;
  final String Function(Map<String, dynamic>) subline;
  final VoidCallback onChanged;
  const CrudSection({
    super.key,
    required this.api,
    required this.title,
    required this.route,
    required this.items,
    required this.fields,
    required this.addLabel,
    required this.heading,
    required this.subline,
    required this.onChanged,
  });

  Future<void> edit(BuildContext context, Map<String, dynamic>? item) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _EditDialog(
        api: api,
        route: route,
        item: item,
        fields: fields,
        title: item == null ? addLabel.replaceFirst('+ ', '') : 'Edit',
      ),
    );
    if (saved == true) onChanged();
  }

  Future<void> remove(BuildContext context, Map<String, dynamic> item) async {
    if (!await confirmDialog(
      context,
      'Delete ${heading(item)}? Orders already made keep their own copy of the details.',
      yes: 'Delete',
    ))
      return;
    try {
      await api.delete('/api/$route/${item['id']}');
      onChanged();
    } on ApiException catch (e) {
      if (context.mounted) toast(context, e.message, bad: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SectionPanel(
      title: '$title (${items.length})',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final i in items)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                border: Border.all(color: K.line),
                borderRadius: BorderRadius.circular(6),
                color: const Color(0xFFFAF9F5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    heading(i),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    subline(i),
                    style: const TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      KButton('Edit', onPressed: () => edit(context, i)),
                      const SizedBox(width: 8),
                      KButton(
                        'Delete',
                        danger: true,
                        onPressed: () => remove(context, i),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: KButton(
              addLabel,
              primary: true,
              onPressed: () => edit(context, null),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditDialog extends StatefulWidget {
  final Api api;
  final String route;
  final Map<String, dynamic>? item;
  final List<FieldDef> fields;
  final String title;
  const _EditDialog({
    required this.api,
    required this.route,
    required this.item,
    required this.fields,
    required this.title,
  });
  @override
  State<_EditDialog> createState() => _EditDialogState();
}

class _EditDialogState extends State<_EditDialog> {
  final Map<String, TextEditingController> ctl = {};
  String? error;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    for (final f in widget.fields) {
      ctl[f.key] = TextEditingController(
        text: widget.item == null
            ? ''
            : s(widget.item![f.key]).replaceAll(RegExp(r'^-$'), ''),
      );
    }
  }

  Future<void> save() async {
    setState(() {
      busy = true;
      error = null;
    });
    final body = <String, String>{
      for (final f in widget.fields) f.key: ctl[f.key]!.text.trim(),
    };
    try {
      if (widget.item == null) {
        await widget.api.post('/api/${widget.route}', body);
      } else {
        await widget.api.put(
          '/api/${widget.route}/${widget.item!['id']}',
          body,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted)
        setState(() {
          error = e.message;
          busy = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final f in widget.fields)
              labeledField(f.label, ctl[f.key]!, type: f.type),
            if (error != null) InfoBanner(error!, kind: 'bad'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(onPressed: busy ? null : save, child: const Text('Save')),
      ],
    );
  }
}
