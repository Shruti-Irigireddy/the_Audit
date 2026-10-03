import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import 'package:the_audit/core/database/app_database.dart';
import 'package:the_audit/core/utils/navbar.dart';
import 'package:the_audit/core/utils/theme.dart';
import 'package:the_audit/core/utils/app_logger.dart';
import 'package:the_audit/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:the_audit/features/post_flight/presentation/post-flight.dart';
import 'package:the_audit/features/pre_field/data/repositories/pre_field_repository_impl.dart';
import 'package:the_audit/features/pre_field/presentation/cubit/pre_field_cubit.dart';
import 'package:the_audit/features/pre_field/presentation/cubit/pre_field_state.dart';
import 'package:the_audit/features/pre_flight/domain/dtos/pre_flight_dtos.dart';
import 'package:the_audit/features/pre_flight/data/repositories/pre_flight_repository_impl.dart';
import 'package:the_audit/features/pre_flight/domain/entities/sortie_entity.dart';
import 'package:the_audit/features/pre_flight/presentation/cubit/pre_flight_cubit.dart';
import 'package:the_audit/features/pre_flight/presentation/cubit/pre_flight_state.dart';
import 'package:the_audit/features/pre_flight/presentation/pre-flight.dart';

const _uuid = Uuid();
const _log = AppLogger('SessionLoop');

class SessionLoopPage extends StatefulWidget {
  final AppDatabase database;
  final AuthCubit authCubit;
  final String sessionId;

  const SessionLoopPage({
    super.key,
    required this.database,
    required this.authCubit,
    required this.sessionId,
  });

  @override
  State<SessionLoopPage> createState() => _SessionLoopPageState();
}

class _SessionLoopPageState extends State<SessionLoopPage> {
  late final PreFieldCubit _preFieldCubit;
  late final PreFlightCubit _preFlightCubit;
  String? _selectedSessionVehicleId;
  String? _selectedPicUserId;
  Set<String> _selectedVoUserIds = {};
  Set<String> _selectedPayloadIds = {};
  Set<String> _selectedBatteryIds = {};
  final Map<String, TextEditingController> _batteryVoltageControllers = {};
  final Map<String, TextEditingController> _batteryPercentControllers = {};
  final _objectiveController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _log.t('initState session ${widget.sessionId}');
    _preFieldCubit = PreFieldCubit(
      PreFieldRepositoryImpl(widget.database.preFieldDao),
    )..loadSession(widget.sessionId);
    _preFlightCubit = PreFlightCubit(
      PreFlightRepositoryImpl(widget.database.preFlightDao),
    )..loadSortiesForSession(widget.sessionId);
  }

  @override
  void dispose() {
    _log.t('dispose');
    _objectiveController.dispose();
    for (final controller in _batteryVoltageControllers.values) {
      controller.dispose();
    }
    for (final controller in _batteryPercentControllers.values) {
      controller.dispose();
    }
    _preFieldCubit.close();
    _preFlightCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _preFieldCubit),
        BlocProvider.value(value: _preFlightCubit),
      ],
      child: Scaffold(
        appBar: const NavBar(),
        body: SafeArea(
          child: ListView(
            padding: AppSizes.pageInsets,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () {
                      _log.d('back tapped');
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.arrow_back),
                    tooltip: 'Back',
                  ),
                  const Expanded(
                    child: Text('Session loop', style: AppTextStyles.pageTitle),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              BlocBuilder<PreFieldCubit, PreFieldState>(
                builder: (context, preFieldState) {
                  return _CreateSortieCard(
                    state: preFieldState,
                    selectedSessionVehicleId: _selectedSessionVehicleId,
                    selectedPicUserId: _selectedPicUserId,
                    selectedVoUserIds: _selectedVoUserIds,
                    selectedPayloadIds: _selectedPayloadIds,
                    selectedBatteryIds: _selectedBatteryIds,
                    batteryVoltageControllers: _batteryVoltageControllers,
                    batteryPercentControllers: _batteryPercentControllers,
                    objectiveController: _objectiveController,
                    onVehicleChanged: (value) {
                      _log.d('sortie vehicle: $value');
                      setState(() {
                        _selectedSessionVehicleId = value;
                        _selectedPayloadIds = {};
                      });
                      if (value != null) {
                        _preFieldCubit.loadPayloadsForSessionVehicle(value);
                      }
                    },
                    onPicChanged: (value) {
                      _log.d('sortie PIC: $value');
                      setState(() => _selectedPicUserId = value);
                    },
                    onVoChanged: _toggleVo,
                    onPayloadChanged: _togglePayload,
                    onBatteryChanged: _toggleBattery,
                    onCreateSortie: _createSortie,
                  );
                },
              ),
              const SizedBox(height: 16),
              BlocBuilder<PreFlightCubit, PreFlightState>(
                builder: (context, preFlightState) {
                  if (preFlightState.isLoading) {
                    return const LinearProgressIndicator();
                  }

                  return Column(
                    children: [
                      for (final sortie in preFlightState.sorties)
                        _SortieTile(
                          sortie: sortie,
                          onPreFlight: () => _openPreFlight(sortie.flightId),
                          onPostFlight: () => _openPostFlight(sortie.flightId),
                        ),
                      if (preFlightState.sorties.isEmpty)
                        const Text('No sorties yet.'),
                    ],
                  );
                },
              ),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: _closeSession,
                icon: const Icon(Icons.lock_outline),
                label: const Text('Close session'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createSortie() async {
    _log.d('prepare pre-flight tapped');
    await _log.trace('createSortie', () async {
      final sessionVehicleId = _selectedSessionVehicleId;
      final picUserId = _selectedPicUserId;

      if (sessionVehicleId == null || picUserId == null) {
        _log.w('create sortie: vehicle or PIC missing');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Select vehicle and PIC.')),
        );
        return;
      }

      final performedBy = await _performedBy();

      _log.d(
        'creating sortie: vehicle $sessionVehicleId, '
        '${_selectedVoUserIds.length} VOs, '
        '${_selectedPayloadIds.length} payloads, '
        '${_selectedBatteryIds.length} batteries',
      );
      await _preFlightCubit.createSortie(
        sessionId: widget.sessionId,
        sessionVehicleId: sessionVehicleId,
        picUserId: picUserId,
        objective: _nullable(_objectiveController.text),
        performedBy: performedBy,
        selectedPayloadIds: _selectedPayloadIds.toList(),
      );
      final flightId = _preFlightCubit.state.selectedSortie?.flightId;
      if (flightId != null) {
        _log.i('sortie created $flightId');
        for (final voUserId in _selectedVoUserIds) {
          await _preFlightCubit.addUserToSortie(
            flightId: flightId,
            userId: voUserId,
            role: 'VO',
            performedBy: performedBy,
          );
        }

        await _preFlightCubit.replaceAllSortieBatteries(
          flightId: flightId,
          batteries: [
            for (final batteryId in _selectedBatteryIds)
              SortieBatteryDraft(
                id: _uuid.v4(),
                batteryId: batteryId,
                voltageStart: double.tryParse(
                  _batteryVoltageControllers[batteryId]?.text.trim() ?? '',
                ),
                percentStart: int.tryParse(
                  _batteryPercentControllers[batteryId]?.text.trim() ?? '',
                ),
              ),
          ],
          performedBy: performedBy,
        );

        if (!mounted) return;
        await _openPreFlight(flightId);
      } else {
        _log.w('create sortie: no sortie selected after create');
      }
      await _preFlightCubit.loadSortiesForSession(widget.sessionId);
    });
  }

  void _toggleVo(String userId, bool selected) {
    _log.d('VO $userId selected: $selected');
    setState(() {
      final values = {..._selectedVoUserIds};
      selected ? values.add(userId) : values.remove(userId);
      _selectedVoUserIds = values;
    });
  }

  void _togglePayload(String payloadId, bool selected) {
    _log.d('payload $payloadId selected: $selected');
    setState(() {
      final values = {..._selectedPayloadIds};
      selected ? values.add(payloadId) : values.remove(payloadId);
      _selectedPayloadIds = values;
    });
  }

  void _toggleBattery(String batteryId, bool selected) {
    _log.d('battery $batteryId selected: $selected');
    setState(() {
      final values = {..._selectedBatteryIds};
      selected ? values.add(batteryId) : values.remove(batteryId);
      _selectedBatteryIds = values;
      _batteryVoltageControllers.putIfAbsent(
        batteryId,
        TextEditingController.new,
      );
      _batteryPercentControllers.putIfAbsent(
        batteryId,
        TextEditingController.new,
      );
    });
  }

  Future<void> _openPreFlight(String flightId) async {
    _log.d('open pre-flight $flightId');
    await Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: 'PreFlightChecklist'),
        builder: (_) => PreFlightChecklistPage(
          database: widget.database,
          authCubit: widget.authCubit,
          flightId: flightId,
        ),
      ),
    );
    await _preFlightCubit.loadSortiesForSession(widget.sessionId);
  }

  Future<void> _openPostFlight(String flightId) async {
    _log.d('open post-flight $flightId');
    await Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: 'PostFlightNotes'),
        builder: (_) => PostFlightNotesPage(
          database: widget.database,
          authCubit: widget.authCubit,
          flightId: flightId,
        ),
      ),
    );
    await _preFlightCubit.loadSortiesForSession(widget.sessionId);
  }

  Future<void> _closeSession() async {
    _log.d('close session tapped');
    await _log.trace('closeSession', () async {
      final performedBy = await _performedBy();
      await _preFieldCubit.closeFieldSession(
        sessionId: widget.sessionId,
        closedBy: performedBy,
      );
    });
  }

  String? _nullable(String value) {
    final clean = value.trim();
    return clean.isEmpty ? null : clean;
  }

  Future<String> _performedBy() async {
    final state = widget.authCubit.state;
    final uid = state.uid?.trim();
    if (uid != null && uid.isNotEmpty) {
      final user = await (widget.database.select(
        widget.database.users,
      )..where((row) => row.id.equals(uid))).getSingleOrNull();
      if (user != null) return user.id;
    }

    final email = state.email?.trim();
    if (email != null && email.isNotEmpty) {
      final user = await (widget.database.select(
        widget.database.users,
      )..where((row) => row.email.equals(email))).getSingleOrNull();
      if (user != null) return user.id;
    }

    _log.w('no local user for ${AppLogger.mask(email)}, using fallback id');
    return uid ?? email ?? 'unknown';
  }
}

class _CreateSortieCard extends StatelessWidget {
  final PreFieldState state;
  final String? selectedSessionVehicleId;
  final String? selectedPicUserId;
  final Set<String> selectedVoUserIds;
  final Set<String> selectedPayloadIds;
  final Set<String> selectedBatteryIds;
  final Map<String, TextEditingController> batteryVoltageControllers;
  final Map<String, TextEditingController> batteryPercentControllers;
  final TextEditingController objectiveController;
  final ValueChanged<String?> onVehicleChanged;
  final ValueChanged<String?> onPicChanged;
  final void Function(String userId, bool selected) onVoChanged;
  final void Function(String payloadId, bool selected) onPayloadChanged;
  final void Function(String batteryId, bool selected) onBatteryChanged;
  final VoidCallback onCreateSortie;

  const _CreateSortieCard({
    required this.state,
    required this.selectedSessionVehicleId,
    required this.selectedPicUserId,
    required this.selectedVoUserIds,
    required this.selectedPayloadIds,
    required this.selectedBatteryIds,
    required this.batteryVoltageControllers,
    required this.batteryPercentControllers,
    required this.objectiveController,
    required this.onVehicleChanged,
    required this.onPicChanged,
    required this.onVoChanged,
    required this.onPayloadChanged,
    required this.onBatteryChanged,
    required this.onCreateSortie,
  });

  @override
  Widget build(BuildContext context) {
    final picUsers = state.sessionUsers
        .where((item) => item.sessionUser.role == 'PIC')
        .toList();
    final voUsers = state.sessionUsers
        .where((item) => item.sessionUser.role == 'VO')
        .toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Prepare sortie', style: AppTextStyles.sectionTitle),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: selectedSessionVehicleId,
              decoration: const InputDecoration(labelText: 'Vehicle'),
              items: [
                for (final item in state.sessionVehicles)
                  DropdownMenuItem(
                    value: item.sessionVehicle.id,
                    child: Text(item.vehicle.name),
                  ),
              ],
              onChanged: onVehicleChanged,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: selectedPicUserId,
              decoration: const InputDecoration(labelText: 'PIC'),
              items: [
                for (final item in picUsers)
                  DropdownMenuItem(
                    value: item.user.id,
                    child: Text(item.user.name),
                  ),
              ],
              onChanged: onPicChanged,
            ),
            const SizedBox(height: 12),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text('VOs (${selectedVoUserIds.length})'),
              children: [
                for (final item in voUsers)
                  CheckboxListTile(
                    value: selectedVoUserIds.contains(item.user.id),
                    onChanged: (value) {
                      onVoChanged(item.user.id, value ?? false);
                    },
                    title: Text(item.user.name),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                if (voUsers.isEmpty)
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('No VOs in this session.'),
                  ),
              ],
            ),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text('Payloads (${selectedPayloadIds.length})'),
              children: [
                for (final payload in state.sessionVehiclePayloads)
                  CheckboxListTile(
                    value: selectedPayloadIds.contains(payload.payloadId),
                    onChanged: (value) {
                      onPayloadChanged(payload.payloadId, value ?? false);
                    },
                    title: Text(payload.name),
                    subtitle: Text(payload.category),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                if (selectedSessionVehicleId == null)
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Select vehicle to load payloads.'),
                  ),
                if (selectedSessionVehicleId != null &&
                    state.sessionVehiclePayloads.isEmpty)
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('No planned payloads for this vehicle.'),
                  ),
              ],
            ),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text('Batteries (${selectedBatteryIds.length})'),
              children: [
                for (final item in state.sessionBatteries)
                  _BatterySelectionTile(
                    name: item.battery.config,
                    batteryId: item.battery.batteryId,
                    selected: selectedBatteryIds.contains(
                      item.battery.batteryId,
                    ),
                    voltageController: batteryVoltageControllers.putIfAbsent(
                      item.battery.batteryId,
                      TextEditingController.new,
                    ),
                    percentController: batteryPercentControllers.putIfAbsent(
                      item.battery.batteryId,
                      TextEditingController.new,
                    ),
                    onChanged: onBatteryChanged,
                  ),
                if (state.sessionBatteries.isEmpty)
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('No batteries in this session.'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: objectiveController,
              decoration: const InputDecoration(labelText: 'Objective'),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onCreateSortie,
              icon: const Icon(Icons.add),
              label: const Text('Prepare pre-flight'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BatterySelectionTile extends StatelessWidget {
  final String name;
  final String batteryId;
  final bool selected;
  final TextEditingController voltageController;
  final TextEditingController percentController;
  final void Function(String batteryId, bool selected) onChanged;

  const _BatterySelectionTile({
    required this.name,
    required this.batteryId,
    required this.selected,
    required this.voltageController,
    required this.percentController,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CheckboxListTile(
          value: selected,
          onChanged: (value) => onChanged(batteryId, value ?? false),
          title: Text(name),
          dense: true,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
        ),
        if (selected)
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: voltageController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Start voltage'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: percentController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Start percent'),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _SortieTile extends StatelessWidget {
  final SortieEntity sortie;
  final VoidCallback onPreFlight;
  final VoidCallback onPostFlight;

  const _SortieTile({
    required this.sortie,
    required this.onPreFlight,
    required this.onPostFlight,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        title: Text('Sortie ${sortie.sequenceNo}'),
        subtitle: Text(sortie.flightStatus),
        trailing: Wrap(
          spacing: 8,
          children: [
            IconButton(
              onPressed: onPreFlight,
              icon: const Icon(Icons.fact_check_outlined),
              tooltip: 'Pre-flight',
            ),
            IconButton(
              onPressed: onPostFlight,
              icon: const Icon(Icons.note_alt_outlined),
              tooltip: 'Post-flight',
            ),
          ],
        ),
      ),
    );
  }
}
