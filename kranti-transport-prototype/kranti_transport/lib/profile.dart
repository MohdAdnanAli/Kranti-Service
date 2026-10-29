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
      final safe = Map<String, dynamic>.from(r);
      safe['parties'] = (safe['parties'] as List<dynamic>? ?? []).isNotEmpty
          ? List<Map<String, dynamic>>.from(
              (safe['parties'] as List<dynamic>).map(
                (e) => Map<String, dynamic>.from(e as Map),
              ),
            )
          : [
              {
                'id': 101,
                'name': 'Apex Traders',
                'gstin': '27AAAAA0000A1Z5',
                'phone': '+91 98111 22333',
                'address': 'Andheri East, Mumbai',
              },
              {
                'id': 102,
                'name': 'Harbor Logistics',
                'gstin': '27BBBBB0000A2Z6',
                'phone': '+91 98222 33444',
                'address': 'Banjara Hills, Hyderabad',
              },
              {
                'id': 103,
                'name': 'Northline Exports',
                'gstin': '27CCCCC0000A3Z7',
                'phone': '+91 98333 44555',
                'address': 'Sahibabad, Delhi',
              },
            ];
      safe['drivers'] = (safe['drivers'] as List<dynamic>? ?? []).isNotEmpty
          ? List<Map<String, dynamic>>.from(
              (safe['drivers'] as List<dynamic>).map(
                (e) => Map<String, dynamic>.from(e as Map),
              ),
            )
          : [
              {
                'id': 201,
                'name': 'Rahul Sharma',
                'phone': '+91 98765 43210',
                'address': 'Mira Road, Mumbai',
                'licence_no': 'MH12 2023456789',
              },
              {
                'id': 202,
                'name': 'Vikram Singh',
                'phone': '+91 98123 45678',
                'address': 'Secunderabad, Telangana',
                'licence_no': 'TS08 9876543210',
              },
              {
                'id': 203,
                'name': 'Naveen Kumar',
                'phone': '+91 98888 77665',
                'address': 'Bengaluru East',
                'licence_no': 'KA03 3456789012',
              },
            ];
      safe['vehicles'] = (safe['vehicles'] as List<dynamic>? ?? []).isNotEmpty
          ? List<Map<String, dynamic>>.from(
              (safe['vehicles'] as List<dynamic>).map(
                (e) => Map<String, dynamic>.from(e as Map),
              ),
            )
          : [
              {
                'id': 301,
                'reg_no': 'MH12AB1234',
                'vtype': '16 ft Open Body',
                'owner_name': 'Kranti Fleet',
                'address': 'Bhiwandi, Maharashtra',
              },
              {
                'id': 302,
                'reg_no': 'TS08CD5678',
                'vtype': '20 ft Container',
                'owner_name': 'Blue Route Logistics',
                'address': 'Medchal, Telangana',
              },
              {
                'id': 303,
                'reg_no': 'DL01EF9012',
                'vtype': '24 ft Trailer',
                'owner_name': 'NCR Freight',
                'address': 'Ghaziabad, Uttar Pradesh',
              },
            ];
      if (mounted)
        setState(() {
          data = safe;
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
    int? openSection;
    int sectionIndex = 0;
    return Win(
      title: 'Profile',
      sub: s(org['name']),
      status:
          'Everything a request needs comes from here. Nothing is typed twice.',
      child: StatefulBuilder(
        builder: (context, setState) {
          void toggleSection(int index, bool next) {
            setState(() {
              openSection = next ? index : null;
            });
          }

          final sections = <Widget>[
            SectionPanel(
              title: '1. Transporter details',
              initiallyOpen: true,
              isOpen: openSection == 0 || (openSection == null && sectionIndex == 0),
              onToggle: (next) => toggleSection(0, next),
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
              isOpen: openSection == 1,
              onToggle: (next) => toggleSection(1, next),
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
                FieldDef('address', 'Address'),
                FieldDef('licence_no', 'Licence number'),
              ],
              heading: (i) => s(i['name']),
              subline: (i) =>
                  '${s(i['phone'])} · ${s(i['address'])}\nLicence ${s(i['licence_no'])}',
              onChanged: load,
              isOpen: openSection == 2,
              onToggle: (next) => toggleSection(2, next),
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
                FieldDef('owner_name', 'Owner name'),
                FieldDef('address', 'Owner address'),
              ],
              heading: (i) => s(i['reg_no']),
              subline: (i) =>
                  '${s(i['vtype'])}\n${s(i['owner_name'])} · ${s(i['address'])}',
              onChanged: load,
              isOpen: openSection == 3,
              onToggle: (next) => toggleSection(3, next),
            ),
          ];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: sections,
          );
        },
      ),
    );
  }
}

/// A collapsible list with add, edit and delete. Server errors show exactly as sent.
class CrudSection extends StatefulWidget {
  final Api api;
  final String title;
  final String route;
  final List<Map<String, dynamic>> items;
  final List<FieldDef> fields;
  final String addLabel;
  final String Function(Map<String, dynamic>) heading;
  final String Function(Map<String, dynamic>) subline;
  final VoidCallback onChanged;
  final bool isOpen;
  final ValueChanged<bool>? onToggle;
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
    this.isOpen = false,
    this.onToggle,
  });

  @override
  State<CrudSection> createState() => _CrudSectionState();
}

class _CrudSectionState extends State<CrudSection> {
  final searchCtl = TextEditingController();

  @override
  void dispose() {
    searchCtl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get filteredItems {
    final q = searchCtl.text.trim().toLowerCase();
    if (q.isEmpty) return widget.items;
    final tokens = q.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    return widget.items.where((item) {
      final haystack = [
        widget.heading(item),
        widget.subline(item),
      ].join(' ').toLowerCase();
      return tokens.every((token) => haystack.contains(token));
    }).toList();
  }

  Future<void> edit(BuildContext context, Map<String, dynamic>? item) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _EditDialog(
        api: widget.api,
        route: widget.route,
        item: item,
        fields: widget.fields,
        title: item == null ? widget.addLabel.replaceFirst('+ ', '') : 'Edit',
      ),
    );
    if (saved == true) widget.onChanged();
  }

  Future<void> remove(BuildContext context, Map<String, dynamic> item) async {
    if (!await confirmDialog(
      context,
      'Delete ${widget.heading(item)}? Orders already made keep their own copy of the details.',
      yes: 'Delete',
    ))
      return;
    try {
      await widget.api.delete('/api/${widget.route}/${item['id']}');
      widget.onChanged();
    } on ApiException catch (e) {
      if (context.mounted) toast(context, e.message, bad: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = filteredItems;
    return SectionPanel(
      title: '${widget.title} (${widget.items.length})',
      isOpen: widget.isOpen,
      onToggle: widget.onToggle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: searchCtl,
            decoration: InputDecoration(
              hintText: 'Search ${widget.title.toLowerCase()}…',
              isDense: true,
              prefixIcon: const Icon(Icons.search, size: 18),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
          ),
          const SizedBox(height: 8),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('No matching records found.'),
            )
          else
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
                      widget.heading(i),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      widget.subline(i),
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
              widget.addLabel,
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
