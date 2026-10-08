import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:the_audit/core/database/database_constants.dart';
import 'package:the_audit/features/auth/data/current_user_repository.dart';
import 'package:the_audit/core/database/app_database.dart';
import 'package:the_audit/core/utils/navbar.dart';
import 'package:the_audit/core/utils/step_indicator.dart';
import 'package:the_audit/core/utils/theme.dart';
import 'package:the_audit/features/vehicle/presentation/widgets/vehicle_tiles.dart';
import 'package:the_audit/core/utils/app_logger.dart';
import 'package:the_audit/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:the_audit/features/post_flight/presentation/post-flight.dart';
import 'package:the_audit/features/pre_field/data/repositories/pre_field_repository_impl.dart';
import 'package:the_audit/features/pre_field/domain/entities/session_user_entity.dart';
import 'package:the_audit/features/pre_field/presentation/cubit/pre_field_cubit.dart';
import 'package:the_audit/features/pre_field/presentation/cubit/pre_field_state.dart';
import 'package:the_audit/features/pre_flight/data/repositories/pre_flight_repository_impl.dart';
import 'package:the_audit/features/pre_flight/domain/entities/sortie_entity.dart';
import 'package:the_audit/features/pre_flight/presentation/cubit/pre_flight_cubit.dart';
import 'package:the_audit/features/pre_flight/presentation/cubit/pre_flight_state.dart';
import 'package:the_audit/features/pre_flight/presentation/pre-flight.dart';

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

  /// Crew members taken off this sortie's VO list (VOs default to the whole
  /// crew except the PIC).
  Set<String> _removedVoUserIds = {};

  /// Whether the "Prepare sortie" form is open (it's always open while the
  /// session has no sorties).
  bool _showNewSortie = false;
  Set<String> _selectedPayloadIds = {};
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
    )..watchSortiesForSession(widget.sessionId);
  }

  @override
  void dispose() {
    _log.t('dispose');
    _objectiveController.dispose();
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
          child: BlocBuilder<PreFlightCubit, PreFlightState>(
            builder: (context, flightState) {
              final sorties = flightState.sorties;
              // A vehicle is busy while one of its sorties is still open:
              // PREFLIGHT, READY (Go saved, flying until its post-flight is
              // closed) or IN_PROGRESS. FLOWN, CLOSED and ABORTED free it.
              const busyStatuses = {FlightStatus.preflight, FlightStatus.ready, FlightStatus.inProgress};
              final busyVehicleIds = {
                for (final sortie in sorties)
                  if (busyStatuses.contains(sortie.flightStatus))
                    sortie.sessionVehicleId,
              };
              // The session can close once every sortie is finished: closed
              // after post-flight, or aborted by a No-Go.
              final openSorties = sorties
                  .where(
                    (s) =>
                        s.flightStatus != FlightStatus.closed &&
                        s.flightStatus != FlightStatus.aborted,
                  )
                  .length;
              return ListView(
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
                        child: Text(
                          'In session',
                          style: AppTextStyles.pageTitle,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Sortie steps: 1 prepare sortie, 2 pre-flight. Post-flight
                  // is its own page afterwards.
                  const StepIndicator(current: 0, count: 2, outerLines: true),
                  const SizedBox(height: 16),
                  Text('Sorties', style: AppTextStyles.sectionTitle),
                  const SizedBox(height: 8),
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
                              vehicleName: _preFieldCubit.state.sessionVehicles
                                  .where(
                                    (item) =>
                                        item.sessionVehicle.id ==
                                        sortie.sessionVehicleId,
                                  )
                                  .map((item) => item.vehicle.name)
                                  .firstOrNull,
                              // Next step: pre-flight until Go is saved,
                              // then post-flight notes.
                              onTap: () => switch (sortie.flightStatus) {
                                FlightStatus.ready ||
                                FlightStatus.flown ||
                                FlightStatus.closed => _openPostFlight(sortie.flightId),
                                _ => _openPreFlight(sortie.flightId),
                              },
                            ),
                          if (preFlightState.sorties.isEmpty)
                            const Text('No sorties yet.'),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  // New sortie: a + button once there are sorties; the form is
                  // open straight away for the first one. Neither shows while
                  // every vehicle is still in an unfinished sortie.
                  BlocBuilder<PreFieldCubit, PreFieldState>(
                    builder: (context, preFieldState) {
                      final vehicles = preFieldState.sessionVehicles;
                      final allBusy =
                          vehicles.isNotEmpty &&
                          vehicles.every(
                            (item) =>
                                busyVehicleIds.contains(item.sessionVehicle.id),
                          );
                      if (allBusy) {
                        return const Text(
                          'All vehicles are in a sortie that hasn\'t landed '
                          'yet. A new sortie can be prepared once one of '
                          'them reaches post-flight.',
                          style: AppTextStyles.secondary,
                        );
                      }
                      if (sorties.isNotEmpty && !_showNewSortie) {
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: FilledButton.icon(
                            onPressed: () =>
                                setState(() => _showNewSortie = true),
                            icon: const Icon(Icons.add),
                            label: const Text('New sortie'),
                          ),
                        );
                      }
                      return _CreateSortieCard(
                        state: preFieldState,
                        busySessionVehicleIds: busyVehicleIds,
                        onClose: sorties.isEmpty
                            ? null
                            : () => setState(() => _showNewSortie = false),
                        selectedSessionVehicleId: _selectedSessionVehicleId,
                        selectedPicUserId: _selectedPicUserId,
                        selectedPayloadIds: _selectedPayloadIds,
                        objectiveController: _objectiveController,
                        onVehicleChanged: (value) {
                          final current = _selectedSessionVehicleId;
                          // One vehicle per sortie: tapping the selected one
                          // deselects it; another one is refused while it's set.
                          if (current != null &&
                              value != null &&
                              value != current) {
                            final name = preFieldState.sessionVehicles
                                .where(
                                  (item) => item.sessionVehicle.id == current,
                                )
                                .map((item) => item.vehicle.name)
                                .firstOrNull;
                            _log.d(
                              'sortie vehicle refused: $current already set',
                            );
                            ScaffoldMessenger.of(context)
                              ..hideCurrentSnackBar()
                              ..showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '${name ?? 'A vehicle'} is already selected. '
                                    'Tap it again to deselect it first.',
                                  ),
                                ),
                              );
                            return;
                          }
                          final next = value == current ? null : value;
                          _log.d('sortie vehicle: $next');
                          setState(() {
                            _selectedSessionVehicleId = next;
                            _selectedPayloadIds = {};
                          });
                          if (next != null) {
                            _preFieldCubit.loadPayloadsForSessionVehicle(next);
                          }
                          // Start from the vehicle's first planned objective
                          // (editable).
                          final planned = next == null
                              ? const <String>[]
                              : _plannedObjectives(preFieldState, next);
                          _objectiveController.text = planned.isEmpty
                              ? ''
                              : planned.first;
                        },
                        removedVoUserIds: _removedVoUserIds,
                        onRemoveVo: (userId) {
                          _log.d('VO $userId removed');
                          setState(() {
                            _removedVoUserIds = {..._removedVoUserIds, userId};
                          });
                        },
                        onPicChanged: (value) {
                          _log.d('sortie PIC: $value');
                          setState(() {
                            _selectedPicUserId = value;
                            // New PIC: VOs start again as everyone else.
                            _removedVoUserIds = {};
                          });
                        },
                        onPayloadChanged: _togglePayload,
                        onCreateSortie: _createSortie,
                      );
                    },
                  ),
                  const SizedBox(height: 18),
                  // Filled (like the other actions) once it can be used.
                  if (openSorties == 0)
                    FilledButton.icon(
                      onPressed: _closeSession,
                      icon: const Icon(Icons.lock_outline),
                      label: const Text('Close session'),
                    )
                  else
                    const OutlinedButton(
                      onPressed: null,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.lock_outline, size: 18),
                          SizedBox(width: 8),
                          Text('Close session'),
                        ],
                      ),
                    ),
                  if (openSorties > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'Close every sortie first '
                        '($openSorties still open).',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.caption,
                      ),
                    ),
                ],
              );
            },
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
      // VOs: the rest of the session's crew (everyone except the PIC),
      // minus anyone removed.
      final voUserIds = {
        for (final item in _preFieldCubit.state.sessionUsers)
          if (item.user.id != picUserId &&
              !_removedVoUserIds.contains(item.user.id))
            item.user.id,
      };

      _log.d(
        'creating sortie: vehicle $sessionVehicleId, '
        '${voUserIds.length} VOs, '
        '${_selectedPayloadIds.length} payloads',
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
        for (final voUserId in voUserIds) {
          await _preFlightCubit.addUserToSortie(
            flightId: flightId,
            userId: voUserId,
            role: 'VO',
            performedBy: performedBy,
          );
        }

        if (!mounted) return;
        setState(() {
          _showNewSortie = false;
          _selectedSessionVehicleId = null;
          _selectedPayloadIds = {};
          _removedVoUserIds = {};
          _objectiveController.clear();
        });
        await _openPreFlight(flightId);
      } else {
        _log.w('create sortie: no sortie selected after create');
      }
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

  /// The objectives entered for this vehicle on Create session (one per
  /// line in session_vehicles.objective).
  static List<String> _plannedObjectives(
    PreFieldState state,
    String sessionVehicleId,
  ) {
    for (final item in state.sessionVehicles) {
      if (item.sessionVehicle.id == sessionVehicleId) {
        return [
          for (final line in (item.sessionVehicle.objective ?? '').split('\n'))
            if (line.trim().isNotEmpty) line.trim(),
        ];
      }
    }
    return const [];
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
  }

  Future<void> _openPostFlight(String flightId) async {
    _log.d('open post-flight $flightId');
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        settings: const RouteSettings(name: 'PostFlightNotes'),
        builder: (_) => PostFlightNotesPage(
          database: widget.database,
          authCubit: widget.authCubit,
          flightId: flightId,
        ),
      ),
    );
  }

  Future<void> _closeSession() async {
    _log.d('close session tapped');
    await _log.trace('closeSession', () async {
      final performedBy = await _performedBy();
      await _preFieldCubit.closeFieldSession(
        sessionId: widget.sessionId,
        closedBy: performedBy,
      );
      if (!mounted) return;
      final state = _preFieldCubit.state;
      final messenger = ScaffoldMessenger.of(context);
      if (state.hasError) {
        messenger.showSnackBar(SnackBar(content: Text(state.errorMessage!)));
        return;
      }
      // Back to the sessions list, where it now shows as Closed.
      messenger.showSnackBar(const SnackBar(content: Text('Session closed.')));
      Navigator.of(context).pop();
    });
  }

  String? _nullable(String value) {
    final clean = value.trim();
    return clean.isEmpty ? null : clean;
  }

  /// The signed-in user, as a row in the local users table.
  Future<String> _performedBy() => CurrentUserRepository(
    widget.database,
  ).resolvePerformedBy(widget.authCubit.state);
}

class _CreateSortieCard extends StatelessWidget {
  final PreFieldState state;
  final String? selectedSessionVehicleId;
  final String? selectedPicUserId;
  final Set<String> selectedPayloadIds;
  final TextEditingController objectiveController;
  final ValueChanged<String?> onVehicleChanged;
  final ValueChanged<String?> onPicChanged;
  final Set<String> removedVoUserIds;
  final ValueChanged<String> onRemoveVo;
  final void Function(String payloadId, bool selected) onPayloadChanged;
  final VoidCallback onCreateSortie;

  /// Vehicles flying in an unfinished sortie: hidden from the picker.
  final Set<String> busySessionVehicleIds;

  /// Closes the form (null while it's the only way to start a sortie).
  final VoidCallback? onClose;

  const _CreateSortieCard({
    required this.busySessionVehicleIds,
    this.onClose,
    required this.state,
    required this.selectedSessionVehicleId,
    required this.selectedPicUserId,
    required this.selectedPayloadIds,
    required this.objectiveController,
    required this.onVehicleChanged,
    required this.onPicChanged,
    required this.removedVoUserIds,
    required this.onRemoveVo,
    required this.onPayloadChanged,
    required this.onCreateSortie,
  });

  /// Picks crew members from [options] (one when [single]).
  Future<Set<String>?> _pickUsers(
    BuildContext context, {
    required String title,
    required List<SessionUserWithUserEntity> options,
    required Set<String> selected,
    required bool single,
  }) {
    final chosen = {...selected};
    return showDialog<Set<String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: StatefulBuilder(
          builder: (context, setDialogState) => SizedBox(
            width: 320,
            child: options.isEmpty
                ? const Text('No other crew members in this session.')
                : ListView(
                    shrinkWrap: true,
                    children: [
                      for (final item in options)
                        CheckboxListTile(
                          value: chosen.contains(item.user.id),
                          onChanged: (value) => setDialogState(() {
                            if (single) chosen.clear();
                            value ?? false
                                ? chosen.add(item.user.id)
                                : chosen.remove(item.user.id);
                          }),
                          title: Text(item.user.name),
                          subtitle: Text(item.user.email),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                    ],
                  ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(chosen),
            child: const Text('Select'),
          ),
        ],
      ),
    );
  }

  String? _nameOf(List<SessionUserWithUserEntity> crew, String? id) {
    for (final item in crew) {
      if (item.user.id == id) return item.user.name;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // The session's team is its crew; PIC and VO are chosen per flight from
    // it. Each person once, even if an older session lists them twice.
    final crew = {
      for (final item in state.sessionUsers) item.user.id: item,
    }.values.toList();
    // VOs: once a PIC is chosen, everyone else in the crew; any can be
    // removed.
    final voUsers = [
      if (selectedPicUserId != null)
        for (final item in crew)
          if (item.user.id != selectedPicUserId &&
              !removedVoUserIds.contains(item.user.id))
            item,
    ];
    final picName = _nameOf(crew, selectedPicUserId);
    final planned = selectedSessionVehicleId == null
        ? const <String>[]
        : _SessionLoopPageState._plannedObjectives(
            state,
            selectedSessionVehicleId!,
          );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Prepare sortie',
                    style: AppTextStyles.sectionTitle,
                  ),
                ),
                if (onClose != null)
                  IconButton(
                    onPressed: onClose,
                    icon: const Icon(Icons.close),
                    tooltip: 'Close',
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // Only the vehicles taken on this session, as in Create session.
            SessionVehiclePicker(
              vehicles: [
                for (final item in state.sessionVehicles)
                  if (!busySessionVehicleIds.contains(item.sessionVehicle.id))
                    (
                      id: item.sessionVehicle.id,
                      name: item.vehicle.name,
                      type: item.vehicle.type,
                    ),
              ],
              selectedId: selectedSessionVehicleId,
              onSelected: onVehicleChanged,
              emptyMessage: state.sessionVehicles.isEmpty
                  ? 'No vehicles on this session.'
                  : 'Every vehicle is in a sortie that hasn\'t landed yet. '
                        'It can be picked again once that sortie is in '
                        'post-flight.',
            ),
            const SizedBox(height: 12),
            _PickSection(
              icon: Icons.person_outline,
              title: 'PIC',
              onAdd: () async {
                final picked = await _pickUsers(
                  context,
                  title: 'Select PIC',
                  options: crew,
                  selected: {?selectedPicUserId},
                  single: true,
                );
                if (picked != null) {
                  onPicChanged(picked.isEmpty ? null : picked.first);
                }
              },
              emptyText: 'No PIC yet. Tap + to choose.',
              chips: [
                if (picName != null)
                  InputChip(
                    avatar: const Icon(Icons.person_outline, size: 18),
                    label: Text(picName),
                    onDeleted: () => onPicChanged(null),
                    deleteButtonTooltipMessage: 'Remove',
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _PickSection(
              icon: Icons.visibility_outlined,
              title: voUsers.isEmpty ? 'VOs' : 'VOs (${voUsers.length})',
              emptyText: 'No VOs.',
              chips: [
                for (final item in voUsers)
                  InputChip(
                    avatar: const Icon(Icons.person_outline, size: 18),
                    label: Text(item.user.name),
                    onDeleted: () => onRemoveVo(item.user.id),
                    deleteButtonTooltipMessage: 'Remove',
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _PickSection(
              icon: Icons.camera_alt_outlined,
              title: selectedPayloadIds.isEmpty
                  ? 'Payloads'
                  : 'Payloads (${selectedPayloadIds.length})',
              emptyText: selectedSessionVehicleId == null
                  ? 'Select a vehicle to see its payloads.'
                  : 'No planned payloads for this vehicle.',
              chips: [
                if (selectedSessionVehicleId != null)
                  for (final payload in state.sessionVehiclePayloads)
                    FilterChip(
                      label: Text(payload.name),
                      tooltip: payload.category,
                      selected: selectedPayloadIds.contains(payload.payloadId),
                      onSelected: (value) =>
                          onPayloadChanged(payload.payloadId, value),
                    ),
              ],
            ),
            const SizedBox(height: 12),
            // The vehicle's planned objectives from Create session, or type
            // your own.
            DropdownMenu<String>(
              key: ValueKey('objective-$selectedSessionVehicleId'),
              controller: objectiveController,
              expandedInsets: EdgeInsets.zero,
              requestFocusOnTap: true,
              enableFilter: false,
              label: const Text('Objective'),
              leadingIcon: const Icon(Icons.flag_outlined),
              helperText: planned.isEmpty
                  ? null
                  : 'Pick a planned objective or type your own.',
              dropdownMenuEntries: [
                for (final objective in planned)
                  DropdownMenuEntry(value: objective, label: objective),
              ],
              onSelected: (value) {
                if (value != null) objectiveController.text = value;
              },
            ),
            const SizedBox(height: 16),
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

/// A titled box with an optional + in its header and chips below, like the
/// sections on Create session.
class _PickSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback? onAdd;
  final String emptyText;
  final List<Widget> chips;

  const _PickSection({
    required this.icon,
    required this.title,
    required this.emptyText,
    required this.chips,
    this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: AppDecorations.section,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppColors.darkNavy),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: AppTextStyles.sectionHeader)),
              if (onAdd != null)
                IconButton(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add),
                  tooltip: 'Add',
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (chips.isEmpty)
            Text(emptyText, style: AppTextStyles.secondary)
          else
            Wrap(spacing: 8, runSpacing: 8, children: chips),
        ],
      ),
    );
  }
}

/// One sortie: number, vehicle and a status tag. Tapping it opens the
/// sortie's next step.
class _SortieTile extends StatelessWidget {
  final SortieEntity sortie;
  final String? vehicleName;
  final VoidCallback onTap;

  const _SortieTile({
    required this.sortie,
    required this.vehicleName,
    required this.onTap,
  });

  /// (tag, still running?) for a flight status.
  static (String, bool) _tag(String status) => switch (status) {
    FlightStatus.preflight => ('Pre-flight', true),
    FlightStatus.ready => ('Ready', true),
    'IN_PROGRESS' => ('In flight', true),
    FlightStatus.flown => ('Post-flight', true),
    FlightStatus.closed => ('Ended', false),
    FlightStatus.aborted => ('Aborted', false),
    _ => (status, false),
  };

  @override
  Widget build(BuildContext context) {
    final (tag, running) = _tag(sortie.flightStatus);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        leading: const Icon(Icons.flight_takeoff_outlined),
        title: Text(
          'Sortie ${sortie.sequenceNo}',
          style: AppTextStyles.bodyStrong,
        ),
        subtitle: vehicleName == null ? null : Text(vehicleName!),
        // The whole card opens the sortie's next step.
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: AppDecorations.stepChip(active: running),
          child: Text(
            tag,
            style: running
                ? AppTextStyles.chipLabel.copyWith(color: AppColors.snowWhite)
                : AppTextStyles.chipLabel,
          ),
        ),
      ),
    );
  }
}
