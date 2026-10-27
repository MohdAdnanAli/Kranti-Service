import 'package:flutter/material.dart';

import 'api.dart';
import 'ui.dart';

/// Step 0: a handful of selectors and one button. Everything else comes from the profile.
class CreateScreen extends StatefulWidget {
  final Api api;
  final void Function(int tab) onGoto;
  const CreateScreen({super.key, required this.api, required this.onGoto});
  @override
  State<CreateScreen> createState() => _CreateScreenState();
}

class _CreateScreenState extends State<CreateScreen> {
  Map<String, dynamic>? profile;
  int? partyId;
  int? driverId;
  int? vehicleId;
  String template = 'load';
  bool busy = false;
  String? error;
  Map<String, dynamic>? created;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final r = await widget.api.get('/api/profile') as Map<String, dynamic>;
      if (mounted) setState(() => profile = r);
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    }
  }

  List<Map<String, dynamic>> list(String k) => (profile![k] as List<dynamic>)
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();

  Future<void> send() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final r = await widget.api.post('/api/orders', {
        'party_id': partyId,
        'template': template,
        'driver_id': driverId,
        'vehicle_id': vehicleId,
      }) as Map<String, dynamic>;
      if (mounted)
        setState(() {
          created = r;
          busy = false;
        });
    } on ApiException catch (e) {
      if (mounted)
        setState(() {
          error = e.message;
          busy = false;
        });
    }
  }

  Widget box(String label, Widget child) {
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
            child: DropdownButtonHideUnderline(child: child),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = profile;
    if (p == null)
      return Win(
        title: 'Create a service request',
        child: Text(error ?? 'Loading...'),
      );
    final c = created;
    if (c != null) {
      return Win(
        title: 'Create a service request',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InfoBanner(
              'Request ${c['code']} created. A link was sent to the requester\'s phone. In this demo it appears in the Demo phone tab.',
              kind: 'ok',
            ),
            const SizedBox(height: 6),
            KButton(
              'Open the Demo phone',
              primary: true,
              onPressed: () => widget.onGoto(4),
            ),
            const SizedBox(height: 8),
            KButton('Go to Orders', onPressed: () => widget.onGoto(3)),
            const SizedBox(height: 8),
            KButton(
              'Create another',
              onPressed: () => setState(() {
                created = null;
                partyId = null;
              }),
            ),
          ],
        ),
      );
    }
    final parties = list('parties'),
        drivers = list('drivers'),
        vehicles = list('vehicles');
    return Win(
      title: 'Create a service request',
      status: 'Requesters, drivers and vehicles come from your Profile.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          box(
            'Requester *',
            DropdownButton<int>(
              isExpanded: true,
              value: partyId,
              hint: const Text('Choose a requester'),
              items: [
                for (final x in parties)
                  DropdownMenuItem<int>(
                    value: (x['id'] as num).toInt(),
                    child: Text(
                      '${x['name']}  (${x['gstin']})',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (v) => setState(() => partyId = v),
            ),
          ),
          const SizedBox(height: 6),
          const Text('Service *', style: TextStyle(fontSize: 13)),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: KButton(
                  'Load (pick-up)',
                  primary: template == 'load',
                  onPressed: () => setState(() => template = 'load'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: KButton(
                  'Unload (drop)',
                  primary: template == 'unload',
                  onPressed: () => setState(() => template = 'unload'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            template == 'load'
                ? 'Load: the buyer is asking. It is sealed at the pick-up.'
                : 'Unload: the seller is asking. It is sealed at the drop.',
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          box(
            'Driver (optional now, add before confirmation)',
            DropdownButton<int?>(
              isExpanded: true,
              value: driverId,
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('None yet'),
                ),
                for (final x in drivers)
                  DropdownMenuItem<int?>(
                    value: (x['id'] as num).toInt(),
                    child: Text('${x['name']}'),
                  ),
              ],
              onChanged: (v) => setState(() => driverId = v),
            ),
          ),
          box(
            'Vehicle (optional now, add before confirmation)',
            DropdownButton<int?>(
              isExpanded: true,
              value: vehicleId,
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('None yet'),
                ),
                for (final x in vehicles)
                  DropdownMenuItem<int?>(
                    value: (x['id'] as num).toInt(),
                    child: Text('${x['reg_no']}  ${x['vtype'] ?? ''}'),
                  ),
              ],
              onChanged: (v) => setState(() => vehicleId = v),
            ),
          ),
          if (error != null) InfoBanner(error!, kind: 'bad'),
          const SizedBox(height: 8),
          KButton(
            busy ? 'Sending...' : 'Send the request link',
            primary: true,
            wide: true,
            onPressed: (busy || partyId == null) ? null : send,
          ),
        ],
      ),
    );
  }
}
