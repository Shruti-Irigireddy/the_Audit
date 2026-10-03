import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:drift/drift.dart' show InsertMode, OrderingTerm;
import 'package:uuid/uuid.dart';

import 'package:the_audit/core/database/app_database.dart';
import 'package:the_audit/core/utils/navbar.dart';
import 'package:the_audit/core/utils/theme.dart';
import 'package:the_audit/core/utils/app_logger.dart';
import 'package:the_audit/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:the_audit/features/auth/presentation/cubit/auth_state.dart';
import 'package:the_audit/features/vehicle/domain/dtos/vehicle_dtos.dart';
import 'package:the_audit/features/pre_field/data/repositories/pre_field_repository_impl.dart';
import 'package:the_audit/features/pre_field/presentation/cubit/pre_field_cubit.dart';
import 'package:the_audit/features/pre_field/presentation/cubit/pre_field_state.dart';
import 'package:the_audit/features/pre_field/presentation/session_loop.dart';

import 'package:geolocator/geolocator.dart';
import 'package:flutter/services.dart';

enum PreFieldMissionType {
  testing('testing', 'TESTING'),
  dataCollection('data_collection', 'DATA_COLLECTION'),
  practice('practice', 'PRACTICE'),
  mixed('mixed', 'MIXED');

  final String label;
  final String dbValue;

  const PreFieldMissionType(this.label, this.dbValue);
}

enum PreFieldSessionStatus {
  planned('planned', 'PLANNED'),
  inProgress('inprogress', 'IN_PROGRESS'),
  closed('closed', 'CLOSED');

  final String label;
  final String dbValue;

  const PreFieldSessionStatus(this.label, this.dbValue);
}

enum _TeamRole {
  pic('PIC'),
  vo('VO'),
  crew('Crew');

  final String label;

  const _TeamRole(this.label);
}

enum _VehicleType {
  multirotor('Multirotor', 'MULTIROTOR'),
  vtol('VTOL', 'VTOL'),
  fixedWing('Fixed wing', 'FIXED_WING');

  final String label;
  final String dbValue;

  const _VehicleType(this.label, this.dbValue);

  String get imageAsset => switch (this) {
    _VehicleType.multirotor => 'assets/images/vehicles/multirotor.png',
    _VehicleType.vtol => 'assets/images/vehicles/vtol.png',
    _VehicleType.fixedWing => 'assets/images/vehicles/fixed_wing.png',
  };

  static _VehicleType? fromDb(String value) {
    for (final type in values) {
      if (type.dbValue == value.toUpperCase()) return type;
    }
    return null;
  }
}

const _uuid = Uuid();
const _log = AppLogger('CreateSession');
const _dialogLog = AppLogger('VehicleDetailsDialog');

/// IN_PROGRESS -> In progress, DATA_COLLECTION -> Data collection.
String _humanize(String dbValue) {
  final words = dbValue.toLowerCase().replaceAll('_', ' ');
  return words.isEmpty ? words : words[0].toUpperCase() + words.substring(1);
}

class _NewVehicleDraft {
  final String name;
  final _VehicleType type;
  final String? frameMake;
  final String? frameModel;
  final int? motorCount;
  final String? frameStyle;
  final String? firmwareTarget;
  final String? defaultFailSafeProfile;
  final String? notes;

  const _NewVehicleDraft({
    required this.name,
    required this.type,
    this.frameMake,
    this.frameModel,
    this.motorCount,
    this.frameStyle,
    this.firmwareTarget,
    this.defaultFailSafeProfile,
    this.notes,
  });
}

class CreateSessionPage extends StatefulWidget {
  final AppDatabase database;
  final AuthCubit authCubit;

  const CreateSessionPage({
    super.key,
    required this.database,
    required this.authCubit,
  });

  @override
  State<CreateSessionPage> createState() => _CreateSessionPageState();
}

class _CreateSessionPageState extends State<CreateSessionPage> {
  late final PreFieldCubit _preFieldCubit;

  @override
  void initState() {
    super.initState();
    _preFieldCubit = PreFieldCubit(
      PreFieldRepositoryImpl(widget.database.preFieldDao),
    );
  }

  @override
  void dispose() {
    _preFieldCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _preFieldCubit,
      child: _CreateSessionView(
        database: widget.database,
        authCubit: widget.authCubit,
      ),
    );
  }
}

class _CreateSessionView extends StatefulWidget {
  final AppDatabase database;
  final AuthCubit authCubit;

  const _CreateSessionView({required this.database, required this.authCubit});

  @override
  State<_CreateSessionView> createState() => _CreateSessionViewState();
}

class _CreateSessionViewState extends State<_CreateSessionView> {
  final _formKey = GlobalKey<FormState>();
  final _locationController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();

  final DateTime _sessionDate = DateTime.now();
  PreFieldMissionType _missionType = PreFieldMissionType.testing;
  PreFieldSessionStatus _sessionStatus = PreFieldSessionStatus.inProgress;
  List<Vehicle> _vehicles = [];
  List<User> _users = [];
  Set<String> _selectedVehicleIds = {};
  String? _picUserId;
  String? _voUserId;
  Set<String> _crewUserIds = {};
  bool _loadingVehicles = true;
  bool _loadingUsers = true;
  bool _submitting = false;
  bool _gettingCurrentLocation = false;

  /// Current wizard step: 0 details, 1 equipment, 2 packing, 3 review.
  int _step = 0;
  final List<_EquipmentRow> _equipmentRows = [];
  bool _loadingEquipment = true;

  @override
  void initState() {
    super.initState();
    _log.t('initState');
    _loadVehicles();
    _loadUsers();
    _loadEquipment();
    // Capture the site location as soon as the page opens (FR-PFT-02).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _useCurrentLocation(automatic: true);
    });
  }

  @override
  void dispose() {
    _log.t('dispose');
    _locationController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    for (final row in _equipmentRows) {
      row.dispose();
    }
    super.dispose();
  }

  /// Pre-fill the equipment list with the saved master list so the team
  /// only adds what's new.
  Future<void> _loadEquipment() async {
    try {
      final items = await widget.database.preFieldDao.getActiveEquipmentList();
      _log.d('loaded ${items.length} equipment items');
      if (!mounted) return;
      setState(() {
        _equipmentRows.addAll([
          for (final item in items)
            _EquipmentRow(name: item.name, equipmentId: item.id),
        ]);
        if (_equipmentRows.isEmpty) _equipmentRows.add(_EquipmentRow());
        _loadingEquipment = false;
      });
    } catch (error, stackTrace) {
      _log.e('load equipment failed', error, stackTrace);
      if (!mounted) return;
      setState(() {
        if (_equipmentRows.isEmpty) _equipmentRows.add(_EquipmentRow());
        _loadingEquipment = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<PreFieldCubit, PreFieldState>(
      listenWhen: (previous, current) =>
          previous.viewStatus != current.viewStatus ||
          previous.errorMessage != current.errorMessage,
      listener: (context, state) {
        if (state.hasError) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.errorMessage!)));
        }
      },
      child: PopScope(
        canPop: _step == 0,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) {
            _log.d('system back: step $_step -> ${_step - 1}');
            setState(() => _step--);
          }
        },
        child: Scaffold(
          appBar: const NavBar(),
          body: SafeArea(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: AppSizes.pageInsets,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: _back,
                        icon: const Icon(Icons.arrow_back),
                        tooltip: 'Back',
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _stepTitles[_step],
                          style: AppTextStyles.pageTitle,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _SessionStepper(
                    current: _step,
                    count: _stepTitles.length,
                    onStepTap: (index) {
                      // Only completed steps can be revisited from here.
                      if (index < _step) {
                        _log.d('stepper tap: step $_step -> $index');
                        setState(() => _step = index);
                      }
                    },
                  ),
                  const SizedBox(height: 18),
                  DecoratedBox(
                    decoration: AppDecorations.panel,
                    child: Padding(
                      padding: const EdgeInsets.all(AppSizes.panelPadding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          switch (_step) {
                            0 => _buildDetailsStep(),
                            1 => _buildEquipmentStep(),
                            2 => _buildPackingStep(),
                            _ => _buildReviewStep(),
                          },
                          const SizedBox(height: 22),
                          BlocBuilder<PreFieldCubit, PreFieldState>(
                            builder: (context, state) {
                              final isSaving = state.isSaving || _submitting;
                              final isLast = _step == _stepTitles.length - 1;
                              return Row(
                                children: [
                                  Expanded(
                                    child: SizedBox(
                                      height: AppSizes.buttonHeight,
                                      child: OutlinedButton.icon(
                                        onPressed: isSaving
                                            ? null
                                            : () => _saveSession(start: false),
                                        icon: const Icon(Icons.save_outlined),
                                        label: const Text('Save'),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: SizedBox(
                                      height: AppSizes.buttonHeight,
                                      child: FilledButton.icon(
                                        onPressed: isSaving
                                            ? null
                                            : isLast
                                            ? () => _saveSession(start: true)
                                            : _next,
                                        icon: isSaving
                                            ? const SizedBox(
                                                width: 18,
                                                height: 18,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              )
                                            : Icon(
                                                isLast
                                                    ? Icons.play_arrow
                                                    : Icons.arrow_forward,
                                              ),
                                        label: Text(
                                          isLast ? 'Start session' : 'Next',
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static const _stepTitles = [
    'Create session',
    'Equipment to bring',
    'Packing check',
    'Review',
  ];

  void _back() {
    if (_step == 0) {
      _log.d('back: leaving create session');
      Navigator.of(context).pop();
    } else {
      _log.d('back: step $_step -> ${_step - 1}');
      setState(() => _step--);
    }
  }

  void _next() {
    if (_step == 0 && !_formKey.currentState!.validate()) {
      _log.d('next: step 0 form invalid');
      return;
    }
    _log.d('next: step $_step -> ${_step + 1}');
    FocusScope.of(context).unfocus();
    setState(() => _step++);
  }

  /// Equipment rows that have an item name (blank rows are ignored).
  List<_EquipmentRow> get _filledEquipment => [
    for (final row in _equipmentRows)
      if (row.name.text.trim().isNotEmpty) row,
  ];

  Widget _buildDetailsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DateField(selectedDate: _sessionDate),
        const SizedBox(height: 14),
        _SessionTextField(
          controller: _locationController,
          label: 'Location name',
          icon: Icons.place_outlined,
          textInputAction: TextInputAction.next,
          validator: _requiredValidator,
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _SessionTextField(
                controller: _latitudeController,
                label: 'Latitude',
                icon: Icons.my_location,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                inputFormatters: [
                  _CoordinateInputFormatter(
                    min: -90,
                    max: 90,
                    decimalPlaces: 7,
                  ),
                ],
                textInputAction: TextInputAction.next,
                validator: _latitudeValidator,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SessionTextField(
                controller: _longitudeController,
                label: 'Longitude',
                icon: Icons.explore_outlined,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                inputFormatters: [
                  _CoordinateInputFormatter(
                    min: -180,
                    max: 180,
                    decimalPlaces: 7,
                  ),
                ],
                textInputAction: TextInputAction.done,
                validator: _longitudeValidator,
              ),
            ),
            const SizedBox(width: 8),

            SizedBox(
              width: 52,
              height: 56,
              child: OutlinedButton(
                onPressed: _gettingCurrentLocation
                    ? null
                    : () => _useCurrentLocation(),
                style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
                child: _gettingCurrentLocation
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<PreFieldMissionType>(
          initialValue: _missionType,
          decoration: AppDecorations.field(
            label: 'Mission type',
            icon: Icons.flag_outlined,
          ),
          items: PreFieldMissionType.values
              .map(
                (missionType) => DropdownMenuItem(
                  value: missionType,
                  child: Text(missionType.label),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value == null) return;
            _log.d('mission type: ${value.dbValue}');
            setState(() => _missionType = value);
          },
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<PreFieldSessionStatus>(
          initialValue: _sessionStatus,
          decoration: AppDecorations.field(
            label: 'Session status',
            icon: Icons.pending_actions_outlined,
          ),
          items: PreFieldSessionStatus.values
              .map(
                (status) =>
                    DropdownMenuItem(value: status, child: Text(status.label)),
              )
              .toList(),
          onChanged: (value) {
            if (value == null) return;
            _log.d('session status: ${value.dbValue}');
            setState(() => _sessionStatus = value);
          },
        ),
        const SizedBox(height: 16),
        _VehicleChecklistSection(
          icon: Icons.flight_takeoff_outlined,
          title: 'Vehicles taken',
          vehicles: _vehicles,
          selectedVehicleIds: _selectedVehicleIds,
          isLoading: _loadingVehicles,
          onChanged: _toggleVehicle,
          onOpenType: _openVehicleDetails,
        ),
        const SizedBox(height: 12),
        _TeamMembersSection(
          icon: Icons.groups_outlined,
          title: 'Team members',
          users: _users,
          isLoading: _loadingUsers,
          picUserId: _picUserId,
          voUserId: _voUserId,
          crewUserIds: _crewUserIds,
          onAddPic: () => _showTeamMemberDialog(role: _TeamRole.pic),
          onAddVo: () => _showTeamMemberDialog(role: _TeamRole.vo),
          onAddCrew: () => _showTeamMemberDialog(role: _TeamRole.crew),
        ),
      ],
    );
  }

  Widget _buildEquipmentStep() {
    return _SectionShell(
      icon: Icons.backpack_outlined,
      title: 'Equipment to bring',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text('Item', style: AppTextStyles.label),
                ),
                SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: Text('Value', style: AppTextStyles.label),
                ),
                SizedBox(width: 48),
              ],
            ),
          ),
          if (_loadingEquipment) const LinearProgressIndicator(),
          for (final row in _equipmentRows)
            Padding(
              key: ObjectKey(row),
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: row.name,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        hintText: 'e.g. Batteries',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: row.value,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(hintText: 'e.g. 6'),
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() {
                      _log.d(
                        'equipment row removed (${_equipmentRows.length - 1} left)',
                      );
                      _equipmentRows.remove(row);
                      row.dispose();
                    }),
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Remove item',
                  ),
                ],
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => setState(() {
                _equipmentRows.add(_EquipmentRow());
                _log.d('equipment row added (${_equipmentRows.length} rows)');
              }),
              icon: const Icon(Icons.add),
              label: const Text('Add item'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPackingStep() {
    final items = _filledEquipment;
    final packed = items.where((row) => row.packed).length;

    return _SectionShell(
      icon: Icons.checklist_outlined,
      title: items.isEmpty
          ? 'Packing check'
          : 'Packing check ($packed / ${items.length} packed)',
      child: items.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No equipment added. Go back a step to add items.',
                style: AppTextStyles.secondary,
              ),
            )
          : Column(
              children: [
                for (final row in items)
                  CheckboxListTile(
                    value: row.packed,
                    onChanged: (value) => setState(() {
                      row.packed = value ?? false;
                      _log.d('packed "${row.name.text.trim()}": ${row.packed}');
                    }),
                    title: Text(row.name.text.trim()),
                    secondary: row.value.text.trim().isEmpty
                        ? null
                        : Text(
                            row.value.text.trim(),
                            style: AppTextStyles.bodyStrong,
                          ),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
              ],
            ),
    );
  }

  Widget _buildReviewStep() {
    String userName(String? id) {
      if (id == null) return '—';
      for (final user in _users) {
        if (user.id == id) return user.name;
      }
      return '—';
    }

    final vehicles = [
      for (final vehicle in _vehicles)
        if (_selectedVehicleIds.contains(vehicle.id))
          '${vehicle.name} (${_VehicleType.fromDb(vehicle.type)?.label ?? vehicle.type})',
    ];
    final crew = [for (final id in _crewUserIds) userName(id)];
    final items = _filledEquipment;
    final packed = items.where((row) => row.packed).length;

    Widget line(String label, String value) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(label, style: AppTextStyles.label)),
          Expanded(child: Text(value, style: AppTextStyles.bodyStrong)),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionShell(
          icon: Icons.event_note_outlined,
          title: 'Session',
          child: Column(
            children: [
              line(
                'Date',
                '${_sessionDate.day}/${_sessionDate.month}/${_sessionDate.year}',
              ),
              line('Location', _locationController.text.trim()),
              line(
                'Coordinates',
                '${_latitudeController.text.trim()}, '
                    '${_longitudeController.text.trim()}',
              ),
              line('Mission type', _humanize(_missionType.dbValue)),
              line('Status', _humanize(_sessionStatus.dbValue)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SectionShell(
          icon: Icons.flight_takeoff_outlined,
          title: 'Vehicles & team',
          child: Column(
            children: [
              line('Vehicles', vehicles.isEmpty ? '—' : vehicles.join('\n')),
              line('PIC', userName(_picUserId)),
              line('VO', userName(_voUserId)),
              line('Crew', crew.isEmpty ? '—' : crew.join(', ')),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SectionShell(
          icon: Icons.backpack_outlined,
          title: items.isEmpty
              ? 'Equipment'
              : 'Equipment ($packed / ${items.length} packed)',
          child: items.isEmpty
              ? const Text(
                  'No equipment added.',
                  style: AppTextStyles.secondary,
                )
              : Column(
                  children: [
                    for (final row in items)
                      line(
                        row.packed ? '✓ Packed' : '✗ Not packed',
                        row.value.text.trim().isEmpty
                            ? row.name.text.trim()
                            : '${row.name.text.trim()} — ${row.value.text.trim()}',
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  /// Creates the session with everything entered so far. [start] opens the
  /// session (flights); otherwise returns to the home page.
  Future<void> _saveSession({required bool start}) async {
    _log.d(start ? 'start session tapped' : 'save tapped');
    if (_step == 0 && !_formKey.currentState!.validate()) {
      _log.d('save: step 0 form invalid');
      return;
    }

    await _log.trace('saveSession', () async {
      final authState = widget.authCubit.state;
      final database = widget.database;
      final cubit = context.read<PreFieldCubit>();

      setState(() => _submitting = true);

      try {
        final createdBy = await _resolvePerformedBy(database, authState);

        await cubit.createFieldSession(
          date: _sessionDate,
          locationName: _locationController.text.trim(),
          latitude: double.parse(_latitudeController.text.trim()),
          longitude: double.parse(_longitudeController.text.trim()),
          missionType: _missionType.dbValue,
          sessionStatus: _sessionStatus.dbValue,
          createdBy: createdBy,
        );

        final sessionId = cubit.state.selectedSession?.sessionId;
        if (sessionId == null) {
          throw Exception('Session was not created.');
        }
        _log.i('session created $sessionId');

        for (final vehicleId in _selectedVehicleIds) {
          await cubit.addVehicleToSession(
            sessionId: sessionId,
            vehicleId: vehicleId,
            performedBy: createdBy,
          );
        }
        _log.d('added ${_selectedVehicleIds.length} vehicles');

        final teamMembers = <({String userId, String role})>[
          if (_picUserId != null) (userId: _picUserId!, role: 'PIC'),
          if (_voUserId != null) (userId: _voUserId!, role: 'VO'),
          for (final crewUserId in _crewUserIds)
            (userId: crewUserId, role: 'CREW'),
        ];

        for (final member in teamMembers) {
          await cubit.addUserToSession(
            sessionId: sessionId,
            userId: member.userId,
            role: member.role,
            performedBy: createdBy,
          );
        }
        _log.d('added ${teamMembers.length} team members');

        await _saveEquipment(
          database: database,
          sessionId: sessionId,
          performedBy: createdBy,
        );

        if (!mounted) return;
        if (!start) {
          _log.i('session saved, returning home');
          Navigator.of(context).pop(true);
          return;
        }
        _log.i('starting session loop');
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            settings: const RouteSettings(name: 'SessionLoop'),
            builder: (_) => SessionLoopPage(
              database: database,
              authCubit: widget.authCubit,
              sessionId: sessionId,
            ),
          ),
        );
      } catch (error, stackTrace) {
        _log.e('save session failed', error, stackTrace);
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      } finally {
        if (mounted) {
          setState(() => _submitting = false);
        }
      }
    });
  }

  /// Saves each equipment row as a session check: the item (reusing a saved
  /// item with the same name), its value in the check's notes, and whether
  /// it was ticked as packed.
  Future<void> _saveEquipment({
    required AppDatabase database,
    required String sessionId,
    required String performedBy,
  }) async {
    await _log.trace('saveEquipment', () async {
      final dao = database.preFieldDao;
      final known = {
        for (final item in await dao.getActiveEquipmentList())
          item.name.trim().toLowerCase(): item.id,
      };

      final rows = _filledEquipment;
      var created = 0;
      for (final row in rows) {
        final name = row.name.text.trim();
        final value = row.value.text.trim();
        final existingId = known[name.toLowerCase()];
        if (existingId == null) created++;
        final equipmentId =
            existingId ??
            await dao.createEquipmentItem(
              name: name,
              category: 'General',
              performedBy: performedBy,
            );
        known[name.toLowerCase()] = equipmentId;

        await dao.addCustomEquipmentCheckToSession(
          sessionId: sessionId,
          equipmentId: equipmentId,
          isPacked: row.packed,
          notes: value.isEmpty ? null : value,
          checkedBy: performedBy,
        );
      }
      _log.d(
        'saved ${rows.length} equipment checks '
        '(${rows.where((r) => r.packed).length} packed, $created new items)',
      );
    });
  }

  Future<void> _loadVehicles() async {
    final database = widget.database;

    try {
      final vehicles = await database.vehicleDao.getActiveVehicles();
      _log.d('loaded ${vehicles.length} vehicles');
      if (!mounted) return;
      setState(() {
        _vehicles = vehicles;
        _loadingVehicles = false;
      });
    } catch (error, stackTrace) {
      _log.e('load vehicles failed', error, stackTrace);
      if (!mounted) return;
      setState(() => _loadingVehicles = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _loadUsers() async {
    final database = widget.database;

    try {
      final users = await (database.select(
        database.users,
      )..orderBy([(row) => OrderingTerm.asc(row.name)])).get();
      _log.d('loaded ${users.length} users');
      if (!mounted) return;
      setState(() {
        _users = users;
        _loadingUsers = false;
      });
    } catch (error, stackTrace) {
      _log.e('load users failed', error, stackTrace);
      if (!mounted) return;
      setState(() => _loadingUsers = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  /// Fills latitude/longitude from the device GPS, asking for permission
  /// first. [automatic] is the run on page open: it never jumps to system
  /// settings and never overwrites coordinates the user has typed.
  Future<void> _useCurrentLocation({bool automatic = false}) async {
    _log.d(automatic ? 'auto location capture' : 'location button tapped');
    await _log.trace('useCurrentLocation', () async {
      setState(() => _gettingCurrentLocation = true);

      // Values this run filled in, so they aren't mistaken for user input.
      String? filledLat;
      String? filledLng;
      bool userTyped() {
        final lat = _latitudeController.text.trim();
        final lng = _longitudeController.text.trim();
        return (lat.isNotEmpty && lat != filledLat) ||
            (lng.isNotEmpty && lng != filledLng);
      }

      void fill(Position position) {
        if (automatic && userTyped()) {
          _log.d('auto location: kept user-typed coordinates');
          return;
        }
        _setCoordinates(position);
        filledLat = _latitudeController.text.trim();
        filledLng = _longitudeController.text.trim();
      }

      try {
        var permission = await Geolocator.checkPermission();
        _log.d('location permission: ${permission.name}');

        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
          _log.d('location permission requested: ${permission.name}');
        }

        if (permission == LocationPermission.denied) {
          _log.w('location permission denied');
          _showSnack(
            automatic
                ? 'Location not shared. Enter coordinates or tap the location button.'
                : 'Location permission denied.',
          );
          return;
        }

        if (permission == LocationPermission.deniedForever) {
          _log.w('location permission denied forever');
          _showSnack(
            'Location permission permanently denied. Enable it from app settings.',
          );
          if (!automatic) await Geolocator.openAppSettings();
          return;
        }

        final serviceEnabled = await Geolocator.isLocationServiceEnabled();
        _log.d('location service enabled: $serviceEnabled');

        if (!serviceEnabled) {
          _log.w('location service disabled');
          _showSnack('Location is turned off. Please enable GPS/location.');
          if (!automatic) await Geolocator.openLocationSettings();
          return;
        }

        // Fill instantly from the cached fix, then refine with a fresh one.
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null && mounted) {
          _log.d('using last known position ${_coords(lastKnown)}');
          fill(lastKnown);
        } else {
          _log.d('no last known position');
        }

        const locationSettings = LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        );

        try {
          final position = await Geolocator.getCurrentPosition(
            locationSettings: locationSettings,
          );
          _log.i('location captured ${_coords(position)}');
          if (!mounted) return;
          if (automatic && userTyped()) {
            _log.d('auto location: kept user-typed coordinates');
            return;
          }
          fill(position);
          _showSnack('Current location captured.');
        } on TimeoutException {
          if (lastKnown == null) {
            _log.w('location fix timed out, no fallback');
            rethrow;
          }
          _log.w('location fix timed out, kept last known position');
          _showSnack('Using last known location; a precise fix timed out.');
        }
      } catch (error, stackTrace) {
        _log.e('location capture failed', error, stackTrace);
        _showSnack(error.toString().replaceFirst('Exception: ', ''));
      } finally {
        if (mounted) {
          setState(() => _gettingCurrentLocation = false);
        }
      }
    });
  }

  static String _coords(Position position) =>
      '(${position.latitude.toStringAsFixed(3)}, '
      '${position.longitude.toStringAsFixed(3)})';

  void _setCoordinates(Position position) {
    setState(() {
      _latitudeController.text = position.latitude.toStringAsFixed(7);
      _longitudeController.text = position.longitude.toStringAsFixed(7);
    });
  }

  void _showSnack(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message.replaceFirst('Exception: ', ''))),
    );
  }

  void _toggleVehicle(String vehicleId, bool isSelected) {
    _log.d('vehicle $vehicleId ${isSelected ? 'selected' : 'removed'}');
    setState(() {
      final selected = {..._selectedVehicleIds};
      if (isSelected) {
        selected.add(vehicleId);
      } else {
        selected.remove(vehicleId);
      }
      _selectedVehicleIds = selected;
    });
  }

  Future<void> _showTeamMemberDialog({required _TeamRole role}) async {
    _log.d('team picker opened: ${role.label}');
    final selectedUserIds = await showDialog<Set<String>>(
      context: context,
      builder: (context) {
        var selectedIds = switch (role) {
          _TeamRole.pic => {if (_picUserId != null) _picUserId!},
          _TeamRole.vo => {if (_voUserId != null) _voUserId!},
          _TeamRole.crew => {..._crewUserIds},
        };

        return AlertDialog(
          title: Text('Select ${role.label}'),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              if (_loadingUsers) {
                return const SizedBox(
                  width: 260,
                  child: LinearProgressIndicator(),
                );
              }

              if (_users.isEmpty) {
                return const SizedBox(
                  width: 260,
                  child: Text('No users found. Add users in admin first.'),
                );
              }

              return SizedBox(
                width: 320,
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final user in _users)
                      CheckboxListTile(
                        value: selectedIds.contains(user.id),
                        onChanged: (value) {
                          setDialogState(() {
                            if (role == _TeamRole.crew) {
                              if (value ?? false) {
                                selectedIds.add(user.id);
                              } else {
                                selectedIds.remove(user.id);
                              }
                              return;
                            }

                            selectedIds = value ?? false ? {user.id} : {};
                          });
                        },
                        title: Text(user.name),
                        subtitle: Text(user.role),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(selectedIds),
              child: const Text('Select'),
            ),
          ],
        );
      },
    );

    if (selectedUserIds == null) {
      _log.d('team picker cancelled: ${role.label}');
      return;
    }
    _log.d('team ${role.label} picked: ${selectedUserIds.length} user(s)');

    setState(() {
      switch (role) {
        case _TeamRole.pic:
          _picUserId = selectedUserIds.isEmpty ? null : selectedUserIds.first;
        case _TeamRole.vo:
          _voUserId = selectedUserIds.isEmpty ? null : selectedUserIds.first;
        case _TeamRole.crew:
          _crewUserIds = selectedUserIds;
      }
    });
  }

  /// One vehicle per type per session: saving a type's dialog replaces any
  /// vehicle previously picked for that type.
  Future<void> _openVehicleDetails(_VehicleType type) async {
    _log.d('vehicle type tapped: ${type.dbValue}');
    await _log.trace('openVehicleDetails', () async {
      final database = widget.database;
      final authState = widget.authCubit.state;
      final vehiclesOfType = [
        for (final vehicle in _vehicles)
          if (_VehicleType.fromDb(vehicle.type) == type) vehicle,
      ];
      final typeIds = {for (final vehicle in vehiclesOfType) vehicle.id};
      Vehicle? current;
      for (final vehicle in vehiclesOfType) {
        if (_selectedVehicleIds.contains(vehicle.id)) current = vehicle;
      }

      final result = await showDialog<_VehicleDetailsResult>(
        context: context,
        builder: (_) => _VehicleDetailsDialog(
          type: type,
          savedVehicles: vehiclesOfType,
          currentVehicle: current,
        ),
      );

      if (result == null || !mounted) {
        _log.d('vehicle dialog cancelled: ${type.dbValue}');
        return;
      }

      if (result.remove) {
        _log.d('vehicle dialog: removed ${type.dbValue}');
        setState(() {
          _selectedVehicleIds = _selectedVehicleIds.difference(typeIds);
        });
        return;
      }

      final draft = result.details!;
      try {
        final performedBy = await _resolvePerformedBy(database, authState);
        var vehicleId = result.vehicleId;

        if (vehicleId == null) {
          _log.d('vehicle dialog: adding new ${draft.type.dbValue}');
          vehicleId = await database.vehicleDao.createVehicleWithChecklist(
            name: draft.name,
            type: draft.type.dbValue,
            frameMake: draft.frameMake,
            frameModel: draft.frameModel,
            motorCount: draft.motorCount,
            frameStyle: draft.frameStyle,
            firmwareTarget: draft.firmwareTarget,
            defaultFailSafeProfile: draft.defaultFailSafeProfile,
            notes: draft.notes,
            createdByUserId: performedBy,
            checklistItems: const [
              ChecklistItemDraft(
                section: 'General',
                label: 'Visual inspection complete',
                responseType: 'PASS_FAIL_NA',
              ),
            ],
          );
          _log.i('vehicle added $vehicleId (${draft.type.dbValue})');
        } else {
          final original = vehiclesOfType.firstWhere((v) => v.id == vehicleId);
          if (_detailsChanged(original, draft)) {
            _log.d(
              'vehicle dialog: editing $vehicleId (${draft.type.dbValue})',
            );
            // updateVehicle treats null as "unchanged", so a cleared text
            // field is written as '' to actually clear it.
            String? edited(String? before, String? after) =>
                after ?? (before == null ? null : '');
            await database.vehicleDao.updateVehicle(
              vehicleId: vehicleId,
              name: draft.name,
              frameMake: edited(original.frameMake, draft.frameMake),
              frameModel: edited(original.frameModel, draft.frameModel),
              motorCount: draft.motorCount,
              frameStyle: edited(original.frameStyle, draft.frameStyle),
              firmwareTarget: edited(
                original.firmwareTarget,
                draft.firmwareTarget,
              ),
              defaultFailSafeProfile: edited(
                original.defaultFailSafeProfile,
                draft.defaultFailSafeProfile,
              ),
              notes: edited(original.notes, draft.notes),
              performedBy: performedBy,
            );
            _log.i('vehicle edited $vehicleId (${draft.type.dbValue})');
          } else {
            _log.d(
              'vehicle picked $vehicleId (${draft.type.dbValue}), unchanged',
            );
          }
        }

        if (!mounted) return;
        await _loadVehicles();
        if (!mounted) return;
        setState(() {
          _selectedVehicleIds = {
            ..._selectedVehicleIds.difference(typeIds),
            vehicleId!,
          };
        });
      } catch (error, stackTrace) {
        _log.e('save vehicle details failed', error, stackTrace);
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    });
  }

  bool _detailsChanged(Vehicle vehicle, _NewVehicleDraft draft) {
    String? norm(String? value) =>
        (value == null || value.trim().isEmpty) ? null : value.trim();
    return vehicle.name.trim() != draft.name ||
        norm(vehicle.frameMake) != draft.frameMake ||
        norm(vehicle.frameModel) != draft.frameModel ||
        vehicle.motorCount != draft.motorCount ||
        norm(vehicle.frameStyle) != draft.frameStyle ||
        norm(vehicle.firmwareTarget) != draft.firmwareTarget ||
        norm(vehicle.defaultFailSafeProfile) != draft.defaultFailSafeProfile ||
        norm(vehicle.notes) != draft.notes;
  }

  Future<void> _ensureCurrentUser(
    AppDatabase database,
    AuthState authState,
    String userId,
  ) async {
    final existingUser = await (database.select(
      database.users,
    )..where((row) => row.id.equals(userId))).getSingleOrNull();

    if (existingUser != null) return;

    await database
        .into(database.users)
        .insert(
          UsersCompanion.insert(
            id: userId,
            name: 'User',
            role: 'PIC',
            email: authState.email ?? '$userId@local.the-audit',
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }

  Future<String> _resolvePerformedBy(
    AppDatabase database,
    AuthState authState,
  ) async {
    final uid = authState.uid?.trim();
    if (uid != null && uid.isNotEmpty) {
      final user = await (database.select(
        database.users,
      )..where((row) => row.id.equals(uid))).getSingleOrNull();
      if (user != null) return user.id;
    }

    final email = authState.email?.trim();
    if (email != null && email.isNotEmpty) {
      final user = await (database.select(
        database.users,
      )..where((row) => row.email.equals(email))).getSingleOrNull();
      if (user != null) return user.id;
    }

    final userId = uid != null && uid.isNotEmpty ? uid : _uuid.v4();
    _log.w('no local user for ${AppLogger.mask(email)}, ensuring user $userId');
    await _ensureCurrentUser(database, authState, userId);
    return userId;
  }

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Required';
    }
    return null;
  }

  String? _latitudeValidator(String? value) {
    return _coordinateRangeValidator(
      value: value,
      label: 'Latitude',
      min: -90,
      max: 90,
    );
  }

  String? _longitudeValidator(String? value) {
    return _coordinateRangeValidator(
      value: value,
      label: 'Longitude',
      min: -180,
      max: 180,
    );
  }

  String? _coordinateRangeValidator({
    required String? value,
    required String label,
    required double min,
    required double max,
  }) {
    final clean = value?.trim() ?? '';

    if (clean.isEmpty) {
      return 'Required';
    }

    final parsed = double.tryParse(clean);

    if (parsed == null) {
      return 'Invalid $label';
    }

    if (parsed < min || parsed > max) {
      return '$label must be between $min and $max';
    }

    return null;
  }
}

class _EquipmentRow {
  final TextEditingController name;
  final TextEditingController value;
  final String? equipmentId;
  bool packed = false;

  _EquipmentRow({String name = '', String value = '', this.equipmentId})
    : name = TextEditingController(text: name),
      value = TextEditingController(text: value);

  void dispose() {
    name.dispose();
    value.dispose();
  }
}

/// Numbered step indicator: done steps are filled with a tick, the current
/// step is filled with its number, upcoming steps are outlined.
class _SessionStepper extends StatelessWidget {
  final int current;
  final int count;
  final ValueChanged<int> onStepTap;

  const _SessionStepper({
    required this.current,
    required this.count,
    required this.onStepTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0)
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                color: i <= current ? AppStepper.lineDone : AppStepper.lineTodo,
              ),
            ),
          Semantics(
            label: 'Step ${i + 1} of $count',
            selected: i == current,
            button: i < current,
            child: GestureDetector(
              onTap: () => onStepTap(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i <= current ? AppStepper.active : AppStepper.todoFill,
                  border: Border.all(
                    color: i <= current
                        ? AppStepper.active
                        : AppStepper.todoBorder,
                  ),
                  boxShadow: i == current
                      ? const [
                          BoxShadow(color: AppStepper.glow, blurRadius: 10),
                        ]
                      : null,
                ),
                child: i < current
                    ? const Icon(
                        Icons.check,
                        size: 18,
                        color: AppColors.snowWhite,
                      )
                    : Text(
                        '${i + 1}',
                        style: i == current
                            ? AppStepper.activeNumber
                            : AppStepper.todoNumber,
                      ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  final DateTime selectedDate;

  const _DateField({required this.selectedDate});

  @override
  Widget build(BuildContext context) {
    final dateText =
        '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}';

    return InputDecorator(
      decoration: AppDecorations.field(
        label: 'Date',
        icon: Icons.calendar_today_outlined,
      ),
      child: Text(dateText, style: AppTextStyles.fieldValue),
    );
  }
}

class _VehicleDetailsResult {
  /// True when the user removed this type's vehicle from the session.
  final bool remove;

  /// Saved vehicle being used/edited; null means create a new vehicle.
  final String? vehicleId;

  final _NewVehicleDraft? details;

  const _VehicleDetailsResult.save({this.vehicleId, required this.details})
    : remove = false;

  const _VehicleDetailsResult.remove()
    : remove = true,
      vehicleId = null,
      details = null;
}

/// Pop-up opened by tapping a vehicle type in "Vehicles taken". Pick a saved
/// vehicle of that type (and edit its details) or enter a new one.
class _VehicleDetailsDialog extends StatefulWidget {
  final _VehicleType type;
  final List<Vehicle> savedVehicles;

  /// The vehicle already taken for this type in this session, if any.
  final Vehicle? currentVehicle;

  const _VehicleDetailsDialog({
    required this.type,
    required this.savedVehicles,
    required this.currentVehicle,
  });

  @override
  State<_VehicleDetailsDialog> createState() => _VehicleDetailsDialogState();
}

class _VehicleDetailsDialogState extends State<_VehicleDetailsDialog> {
  static const _newVehicle = '__new__';

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _frameMakeController = TextEditingController();
  final _frameModelController = TextEditingController();
  final _motorCountController = TextEditingController();
  final _frameStyleController = TextEditingController();
  final _firmwareTargetController = TextEditingController();
  final _failSafeController = TextEditingController();
  final _notesController = TextEditingController();

  late String _choice;

  @override
  void initState() {
    super.initState();
    final initial =
        widget.currentVehicle ??
        (widget.savedVehicles.isEmpty ? null : widget.savedVehicles.first);
    _choice = initial?.id ?? _newVehicle;
    _dialogLog.t(
      'initState ${widget.type.dbValue}: '
      '${widget.savedVehicles.length} saved, initial $_choice',
    );
    _fill(initial);
  }

  @override
  void dispose() {
    for (final controller in [
      _nameController,
      _frameMakeController,
      _frameModelController,
      _motorCountController,
      _frameStyleController,
      _firmwareTargetController,
      _failSafeController,
      _notesController,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _fill(Vehicle? vehicle) {
    _nameController.text = vehicle?.name ?? '';
    _frameMakeController.text = vehicle?.frameMake ?? '';
    _frameModelController.text = vehicle?.frameModel ?? '';
    _motorCountController.text = vehicle?.motorCount?.toString() ?? '';
    _frameStyleController.text = vehicle?.frameStyle ?? '';
    _firmwareTargetController.text = vehicle?.firmwareTarget ?? '';
    _failSafeController.text = vehicle?.defaultFailSafeProfile ?? '';
    _notesController.text = vehicle?.notes ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final type = widget.type;
    final isNew = _choice == _newVehicle;

    return AlertDialog(
      title: Row(
        children: [
          SizedBox.square(
            dimension: 28,
            child: Image.asset(type.imageAsset, color: AppColors.darkNavy),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text('${type.label} details')),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.savedVehicles.isNotEmpty) ...[
                  DropdownButtonFormField<String>(
                    initialValue: _choice,
                    isExpanded: true,
                    decoration: AppDecorations.field(
                      label: 'Vehicle',
                      icon: Icons.inventory_2_outlined,
                    ),
                    items: [
                      for (final vehicle in widget.savedVehicles)
                        DropdownMenuItem(
                          value: vehicle.id,
                          child: Text(
                            vehicle.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      DropdownMenuItem(
                        value: _newVehicle,
                        child: Text('New ${type.label}'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      _dialogLog.d('vehicle choice: $value');
                      setState(() {
                        _choice = value;
                        _fill(
                          value == _newVehicle
                              ? null
                              : widget.savedVehicles.firstWhere(
                                  (v) => v.id == value,
                                ),
                        );
                      });
                    },
                  ),
                  const SizedBox(height: 14),
                ],
                TextFormField(
                  controller: _nameController,
                  autofocus: widget.savedVehicles.isEmpty,
                  textCapitalization: TextCapitalization.words,
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Enter a vehicle name'
                      : null,
                  decoration: AppDecorations.field(
                    label: 'Vehicle name',
                    icon: Icons.flight_takeoff_outlined,
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _frameMakeController,
                  textCapitalization: TextCapitalization.words,
                  decoration: AppDecorations.field(
                    label: 'Frame make',
                    icon: Icons.precision_manufacturing_outlined,
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _frameModelController,
                  textCapitalization: TextCapitalization.words,
                  decoration: AppDecorations.field(
                    label: 'Frame model',
                    icon: Icons.view_in_ar_outlined,
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _motorCountController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: AppDecorations.field(
                    label: 'Motor count',
                    icon: Icons.settings_outlined,
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _frameStyleController,
                  textCapitalization: TextCapitalization.words,
                  decoration: AppDecorations.field(
                    label: 'Frame style',
                    icon: Icons.dashboard_customize_outlined,
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _firmwareTargetController,
                  decoration: AppDecorations.field(
                    label: 'Firmware target',
                    icon: Icons.memory_outlined,
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _failSafeController,
                  decoration: AppDecorations.field(
                    label: 'Default failsafe profile',
                    icon: Icons.health_and_safety_outlined,
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _notesController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: AppDecorations.field(
                    label: 'Notes',
                    icon: Icons.notes_outlined,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        if (widget.currentVehicle != null)
          TextButton(
            onPressed: () {
              _dialogLog.d('remove tapped: ${widget.type.dbValue}');
              Navigator.of(context).pop(const _VehicleDetailsResult.remove());
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.errorRed),
            child: const Text('Remove'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: Text(isNew ? 'Add' : 'Save')),
      ],
    );
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      _dialogLog.d('submit: form invalid');
      return;
    }
    _dialogLog.d(
      'submit ${widget.type.dbValue}: '
      '${_choice == _newVehicle ? 'new vehicle' : 'vehicle $_choice'}',
    );

    Navigator.of(context).pop(
      _VehicleDetailsResult.save(
        vehicleId: _choice == _newVehicle ? null : _choice,
        details: _NewVehicleDraft(
          name: _nameController.text.trim(),
          type: widget.type,
          frameMake: _nullableText(_frameMakeController),
          frameModel: _nullableText(_frameModelController),
          motorCount: int.tryParse(_motorCountController.text.trim()),
          frameStyle: _nullableText(_frameStyleController),
          firmwareTarget: _nullableText(_firmwareTargetController),
          defaultFailSafeProfile: _nullableText(_failSafeController),
          notes: _nullableText(_notesController),
        ),
      ),
    );
  }

  String? _nullableText(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : value;
  }
}

/// "Vehicles taken": a carousel of the three vehicle types. Tapping a type
/// opens its details page; the vehicles picked for the session are listed
/// below as removable chips (multi-select across and within types).
class _VehicleChecklistSection extends StatefulWidget {
  final IconData icon;
  final String title;
  final List<Vehicle> vehicles;
  final Set<String> selectedVehicleIds;
  final bool isLoading;
  final void Function(String vehicleId, bool isSelected) onChanged;
  final ValueChanged<_VehicleType> onOpenType;

  const _VehicleChecklistSection({
    required this.icon,
    required this.title,
    required this.vehicles,
    required this.selectedVehicleIds,
    required this.isLoading,
    required this.onChanged,
    required this.onOpenType,
  });

  @override
  State<_VehicleChecklistSection> createState() =>
      _VehicleChecklistSectionState();
}

class _VehicleChecklistSectionState extends State<_VehicleChecklistSection> {
  static const _types = _VehicleType.values;

  final PageController _pageController = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goTo(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = [
      for (final vehicle in widget.vehicles)
        if (widget.selectedVehicleIds.contains(vehicle.id)) vehicle,
    ];
    final selectedCount = selected.length;

    return _SectionShell(
      icon: widget.icon,
      title: selectedCount == 0
          ? widget.title
          : '${widget.title} ($selectedCount)',
      child: widget.isLoading
          ? const LinearProgressIndicator()
          : Column(
              children: [
                SizedBox(
                  height: 214,
                  child: Row(
                    children: [
                      _CarouselArrow(
                        icon: Icons.chevron_left,
                        tooltip: 'Previous type',
                        onPressed: _page > 0 ? () => _goTo(_page - 1) : null,
                      ),
                      Expanded(
                        child: PageView.builder(
                          controller: _pageController,
                          itemCount: _types.length,
                          onPageChanged: (value) =>
                              setState(() => _page = value),
                          itemBuilder: (context, index) {
                            final type = _types[index];
                            final selectedOfType = [
                              for (final vehicle in selected)
                                if (_VehicleType.fromDb(vehicle.type) == type)
                                  vehicle,
                            ];
                            return _VehicleTypeCard(
                              type: type,
                              selectedOfType: selectedOfType,
                              // First tap opens the details pop-up; tapping
                              // a selected type again removes it.
                              onTap: selectedOfType.isEmpty
                                  ? () => widget.onOpenType(type)
                                  : () {
                                      for (final vehicle in selectedOfType) {
                                        widget.onChanged(vehicle.id, false);
                                      }
                                    },
                            );
                          },
                        ),
                      ),
                      _CarouselArrow(
                        icon: Icons.chevron_right,
                        tooltip: 'Next type',
                        onPressed: _page < _types.length - 1
                            ? () => _goTo(_page + 1)
                            : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                _PageDots(count: _types.length, current: _page),
                if (selected.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final vehicle in selected)
                          InputChip(
                            avatar: _VehicleType.fromDb(vehicle.type) == null
                                ? const Icon(Icons.flight, size: 18)
                                : Image.asset(
                                    _VehicleType.fromDb(
                                      vehicle.type,
                                    )!.imageAsset,
                                    color: AppColors.darkNavy,
                                  ),
                            label: Text(vehicle.name),
                            tooltip: 'Edit details',
                            onPressed: () {
                              final type = _VehicleType.fromDb(vehicle.type);
                              if (type != null) widget.onOpenType(type);
                            },
                            onDeleted: () =>
                                widget.onChanged(vehicle.id, false),
                            deleteButtonTooltipMessage: 'Remove',
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

/// Dark blue hexagon showing a vehicle type's image.
class _VehicleHexTile extends StatelessWidget {
  final _VehicleType type;
  final bool isSelected;

  const _VehicleHexTile({required this.type, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      // Pointy-top regular hexagon: height = width * 2 / sqrt(3).
      width: 112,
      height: 129,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 30),
      decoration: ShapeDecoration(
        color: isSelected ? AppVehicleTile.selectedFill : AppVehicleTile.fill,
        shape: _HexagonTileBorder(
          side: BorderSide(
            color: isSelected
                ? AppVehicleTile.selectedBorder
                : AppVehicleTile.border,
            width: isSelected ? 2.5 : 1,
          ),
        ),
        shadows: isSelected
            ? const [
                BoxShadow(
                  color: AppVehicleTile.glow,
                  blurRadius: 22,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: AppVehicleTile.selectedShadow,
                  blurRadius: 16,
                  offset: Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Blurred copy of the drawing behind it gives the glow.
          if (isSelected)
            ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Image.asset(
                type.imageAsset,
                color: AppVehicleTile.glyphGlow,
                fit: BoxFit.contain,
              ),
            ),
          Image.asset(
            type.imageAsset,
            color: isSelected
                ? AppVehicleTile.selectedGlyph
                : AppVehicleTile.glyph,
            fit: BoxFit.contain,
          ),
        ],
      ),
    );
  }
}

class _VehicleTypeCard extends StatelessWidget {
  final _VehicleType type;
  final List<Vehicle> selectedOfType;
  final VoidCallback onTap;

  const _VehicleTypeCard({
    required this.type,
    required this.selectedOfType,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = selectedOfType.isNotEmpty;
    final meta = isSelected
        ? '${selectedOfType.first.name.toUpperCase()} · TAP TO REMOVE'
        : 'TAP TO SELECT';

    return Semantics(
      button: true,
      selected: isSelected,
      label: isSelected
          ? 'Remove ${type.label} ${selectedOfType.first.name}'
          : 'Add ${type.label}',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _VehicleHexTile(type: type, isSelected: isSelected),
            const SizedBox(height: 12),
            Text(
              type.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.vehicleName,
            ),
            const SizedBox(height: 2),
            Text(
              meta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: isSelected
                  ? AppTextStyles.vehicleMeta.copyWith(
                      color: AppColors.darkNavy,
                    )
                  : AppTextStyles.vehicleMeta,
            ),
          ],
        ),
      ),
    );
  }
}

/// Pointy-top hexagon outline for the vehicle image tile.
class _HexagonTileBorder extends ShapeBorder {
  final BorderSide side;

  const _HexagonTileBorder({this.side = BorderSide.none});

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);

  Path _path(Rect rect) {
    final cx = rect.center.dx;
    final quarter = rect.height / 4;
    return Path()
      ..moveTo(cx, rect.top)
      ..lineTo(rect.right, rect.top + quarter)
      ..lineTo(rect.right, rect.bottom - quarter)
      ..lineTo(cx, rect.bottom)
      ..lineTo(rect.left, rect.bottom - quarter)
      ..lineTo(rect.left, rect.top + quarter)
      ..close();
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => _path(rect);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      _path(rect.deflate(side.width));

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none || side.width == 0) return;
    canvas.drawPath(
      _path(rect.deflate(side.width / 2)),
      side.toPaint()..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  ShapeBorder scale(double t) => _HexagonTileBorder(side: side.scale(t));

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) => a is _HexagonTileBorder
      ? _HexagonTileBorder(side: BorderSide.lerp(a.side, side, t))
      : super.lerpFrom(a, t);

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) => b is _HexagonTileBorder
      ? _HexagonTileBorder(side: BorderSide.lerp(side, b.side, t))
      : super.lerpTo(b, t);

  @override
  bool operator ==(Object other) =>
      other is _HexagonTileBorder && other.side == side;

  @override
  int get hashCode => side.hashCode;
}

class _CarouselArrow extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  const _CarouselArrow({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton.outlined(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon),
      style: IconButton.styleFrom(
        side: const BorderSide(color: AppColors.borderStrong),
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  final int count;
  final int current;

  const _PageDots({required this.count, required this.current});

  @override
  Widget build(BuildContext context) {
    if (count <= 1) return const SizedBox.shrink();

    if (count > 8) {
      return Text('${current + 1} / $count', style: AppTextStyles.caption);
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == current ? 18 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: i == current ? AppColors.darkNavy : AppColors.borderStrong,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
      ],
    );
  }
}

class _TeamMembersSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<User> users;
  final bool isLoading;
  final String? picUserId;
  final String? voUserId;
  final Set<String> crewUserIds;
  final VoidCallback onAddPic;
  final VoidCallback onAddVo;
  final VoidCallback onAddCrew;

  const _TeamMembersSection({
    required this.icon,
    required this.title,
    required this.users,
    required this.isLoading,
    required this.picUserId,
    required this.voUserId,
    required this.crewUserIds,
    required this.onAddPic,
    required this.onAddVo,
    required this.onAddCrew,
  });

  @override
  Widget build(BuildContext context) {
    final picName = _userName(picUserId);
    final voName = _userName(voUserId);
    final crewNames = [
      for (final userId in crewUserIds) _userName(userId),
    ].whereType<String>().toList();

    return _SectionShell(
      icon: icon,
      title: title,
      child: isLoading
          ? const LinearProgressIndicator()
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.person_outline, size: 18),
                  label: Text(picName == null ? 'PIC' : 'PIC: $picName'),
                  onPressed: onAddPic,
                ),
                ActionChip(
                  avatar: const Icon(Icons.person_outline, size: 18),
                  label: Text(voName == null ? 'VO' : 'VO: $voName'),
                  onPressed: onAddVo,
                ),
                ActionChip(
                  avatar: const Icon(Icons.group_add_outlined, size: 18),
                  label: const Text('Crew'),
                  onPressed: onAddCrew,
                ),
                for (final crewName in crewNames)
                  Chip(
                    avatar: const Icon(Icons.person_outline, size: 18),
                    label: Text('Crew: $crewName'),
                  ),
              ],
            ),
    );
  }

  String? _userName(String? userId) {
    if (userId == null) return null;

    for (final user in users) {
      if (user.id == userId) return user.name;
    }

    return null;
  }
}

class _SectionShell extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _SectionShell({
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
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
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _SessionTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final List<TextInputFormatter>? inputFormatters;

  const _SessionTextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      validator: validator,
      decoration: AppDecorations.field(label: label, icon: icon),
    );
  }
}

class _CoordinateInputFormatter extends TextInputFormatter {
  final double min;
  final double max;
  final int decimalPlaces;

  _CoordinateInputFormatter({
    required this.min,
    required this.max,
    required this.decimalPlaces,
  });

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.trim();

    if (text.isEmpty || text == '-' || text == '.' || text == '-.') {
      return newValue;
    }

    final decimalRegex = RegExp(
      r'^-?\d{0,3}(\.\d{0,' + decimalPlaces.toString() + r'})?$',
    );

    if (!decimalRegex.hasMatch(text)) {
      return oldValue;
    }

    final parsed = double.tryParse(text);

    if (parsed == null) {
      return oldValue;
    }

    if (parsed < min || parsed > max) {
      return oldValue;
    }

    return newValue;
  }
}
