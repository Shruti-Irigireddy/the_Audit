import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:drift/drift.dart' show InsertMode, OrderingTerm;
import 'package:uuid/uuid.dart';

import 'package:the_audit/core/database/app_database.dart';
import 'package:the_audit/core/utils/navbar.dart';
import 'package:the_audit/core/utils/theme.dart';
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
}

const _uuid = Uuid();

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

  @override
  void initState() {
    super.initState();
    _loadVehicles();
    _loadUsers();
  }

  @override
  void dispose() {
    _locationController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
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
      child: Scaffold(
        appBar: const NavBar(),
        backgroundColor: AppColors.iceBlue,
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back),
                      color: AppColors.darkNavy,
                      tooltip: 'Back',
                    ),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'Create session',
                        style: TextStyle(
                          color: AppColors.darkNavy,
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.cardWhite,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.steelBlue.withValues(alpha: 0.18),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.black.withValues(alpha: 0.06),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
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
                                keyboardType:
                                    const TextInputType.numberWithOptions(
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
                                keyboardType:
                                    const TextInputType.numberWithOptions(
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
                                    : _useCurrentLocation,
                                style: OutlinedButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppSizes.inputRadius,
                                    ),
                                  ),
                                ),
                                child: _gettingCurrentLocation
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.my_location),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<PreFieldMissionType>(
                          initialValue: _missionType,
                          decoration: _inputDecoration(
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
                            setState(() => _missionType = value);
                          },
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<PreFieldSessionStatus>(
                          initialValue: _sessionStatus,
                          decoration: _inputDecoration(
                            label: 'Session status',
                            icon: Icons.pending_actions_outlined,
                          ),
                          items: PreFieldSessionStatus.values
                              .map(
                                (status) => DropdownMenuItem(
                                  value: status,
                                  child: Text(status.label),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
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
                          onAddVehicle: _showAddVehicleDialog,
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
                          onAddPic: () =>
                              _showTeamMemberDialog(role: _TeamRole.pic),
                          onAddVo: () =>
                              _showTeamMemberDialog(role: _TeamRole.vo),
                          onAddCrew: () =>
                              _showTeamMemberDialog(role: _TeamRole.crew),
                        ),
                        const SizedBox(height: 22),
                        BlocBuilder<PreFieldCubit, PreFieldState>(
                          builder: (context, state) {
                            final isSaving = state.isSaving || _submitting;
                            return SizedBox(
                              width: double.infinity,
                              height: AppSizes.buttonHeight,
                              child: FilledButton.icon(
                                onPressed: isSaving ? null : _submit,
                                icon: isSaving
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.check),
                                label: Text(
                                  isSaving
                                      ? 'Creating session'
                                      : 'Create session',
                                ),
                              ),
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
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

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

      for (final vehicleId in _selectedVehicleIds) {
        await cubit.addVehicleToSession(
          sessionId: sessionId,
          vehicleId: vehicleId,
          performedBy: createdBy,
        );
      }

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

      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => SessionLoopPage(
            database: database,
            authCubit: widget.authCubit,
            sessionId: sessionId,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _loadVehicles() async {
    final database = widget.database;

    try {
      final vehicles = await database.vehicleDao.getActiveVehicles();
      if (!mounted) return;
      setState(() {
        _vehicles = vehicles;
        _loadingVehicles = false;
      });
    } catch (error) {
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
      if (!mounted) return;
      setState(() {
        _users = users;
        _loadingUsers = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadingUsers = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _gettingCurrentLocation = true);

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        _showSnack('Location is turned off. Please enable GPS/location.');
        await Geolocator.openLocationSettings();
        return;
      }

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        _showSnack('Location permission denied.');
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        _showSnack(
          'Location permission permanently denied. Enable it from app settings.',
        );
        await Geolocator.openAppSettings();
        return;
      }

      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      );

      final position = await Geolocator.getCurrentPosition(
        locationSettings: locationSettings,
      );

      if (!mounted) return;

      setState(() {
        _latitudeController.text = position.latitude.toStringAsFixed(7);
        _longitudeController.text = position.longitude.toStringAsFixed(7);
      });

      _showSnack('Current location captured.');
    } catch (error) {
      _showSnack(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _gettingCurrentLocation = false);
      }
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message.replaceFirst('Exception: ', ''))),
    );
  }

  void _toggleVehicle(String vehicleId, bool isSelected) {
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

    if (selectedUserIds == null) return;

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

  Future<void> _showAddVehicleDialog() async {
    final database = widget.database;
    final authState = widget.authCubit.state;

    final draft = await showDialog<_NewVehicleDraft>(
      context: context,
      builder: (_) => const _AddVehicleDialog(),
    );

    if (draft == null) return;

    try {
      final createdBy = await _resolvePerformedBy(database, authState);
      final vehicleId = await database.vehicleDao.createVehicleWithChecklist(
        name: draft.name,
        type: draft.type.dbValue,
        frameMake: draft.frameMake,
        frameModel: draft.frameModel,
        motorCount: draft.motorCount,
        frameStyle: draft.frameStyle,
        firmwareTarget: draft.firmwareTarget,
        defaultFailSafeProfile: draft.defaultFailSafeProfile,
        notes: draft.notes,
        createdByUserId: createdBy,
        checklistItems: const [
          ChecklistItemDraft(
            section: 'General',
            label: 'Visual inspection complete',
            responseType: 'PASS_FAIL_NA',
          ),
        ],
      );

      if (!mounted) return;
      await _loadVehicles();
      setState(() {
        _selectedVehicleIds = {..._selectedVehicleIds, vehicleId};
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
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

class _DateField extends StatelessWidget {
  final DateTime selectedDate;

  const _DateField({required this.selectedDate});

  @override
  Widget build(BuildContext context) {
    final dateText =
        '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}';

    return InputDecorator(
      decoration: _inputDecoration(
        label: 'Date',
        icon: Icons.calendar_today_outlined,
      ),
      child: Text(
        dateText,
        style: const TextStyle(
          color: AppColors.darkNavy,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _AddVehicleDialog extends StatefulWidget {
  const _AddVehicleDialog();

  @override
  State<_AddVehicleDialog> createState() => _AddVehicleDialogState();
}

class _AddVehicleDialogState extends State<_AddVehicleDialog> {
  final _nameController = TextEditingController();
  final _frameMakeController = TextEditingController();
  final _frameModelController = TextEditingController();
  final _motorCountController = TextEditingController();
  final _frameStyleController = TextEditingController();
  final _firmwareTargetController = TextEditingController();
  final _failSafeController = TextEditingController();
  final _notesController = TextEditingController();

  _VehicleType _vehicleType = _VehicleType.multirotor;

  @override
  void dispose() {
    _nameController.dispose();
    _frameMakeController.dispose();
    _frameModelController.dispose();
    _motorCountController.dispose();
    _frameStyleController.dispose();
    _firmwareTargetController.dispose();
    _failSafeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add vehicle'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: _inputDecoration(
                label: 'Vehicle name',
                icon: Icons.flight_takeoff_outlined,
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<_VehicleType>(
              initialValue: _vehicleType,
              decoration: _inputDecoration(
                label: 'Vehicle type',
                icon: Icons.category_outlined,
              ),
              items: _VehicleType.values
                  .map(
                    (type) =>
                        DropdownMenuItem(value: type, child: Text(type.label)),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() => _vehicleType = value);
              },
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _frameMakeController,
              textCapitalization: TextCapitalization.words,
              decoration: _inputDecoration(
                label: 'Frame make',
                icon: Icons.precision_manufacturing_outlined,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _frameModelController,
              textCapitalization: TextCapitalization.words,
              decoration: _inputDecoration(
                label: 'Frame model',
                icon: Icons.view_in_ar_outlined,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _motorCountController,
              keyboardType: TextInputType.number,
              decoration: _inputDecoration(
                label: 'Motor count',
                icon: Icons.settings_outlined,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _frameStyleController,
              textCapitalization: TextCapitalization.words,
              decoration: _inputDecoration(
                label: 'Frame style',
                icon: Icons.dashboard_customize_outlined,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _firmwareTargetController,
              decoration: _inputDecoration(
                label: 'Firmware target',
                icon: Icons.memory_outlined,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _failSafeController,
              decoration: _inputDecoration(
                label: 'Default failsafe profile',
                icon: Icons.health_and_safety_outlined,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _notesController,
              minLines: 2,
              maxLines: 4,
              decoration: _inputDecoration(
                label: 'Notes',
                icon: Icons.notes_outlined,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Add')),
      ],
    );
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    Navigator.of(context).pop(
      _NewVehicleDraft(
        name: name,
        type: _vehicleType,
        frameMake: _nullableText(_frameMakeController),
        frameModel: _nullableText(_frameModelController),
        motorCount: int.tryParse(_motorCountController.text.trim()),
        frameStyle: _nullableText(_frameStyleController),
        firmwareTarget: _nullableText(_firmwareTargetController),
        defaultFailSafeProfile: _nullableText(_failSafeController),
        notes: _nullableText(_notesController),
      ),
    );
  }

  String? _nullableText(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : value;
  }
}

class _VehicleChecklistSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<Vehicle> vehicles;
  final Set<String> selectedVehicleIds;
  final bool isLoading;
  final void Function(String vehicleId, bool isSelected) onChanged;
  final VoidCallback onAddVehicle;

  const _VehicleChecklistSection({
    required this.icon,
    required this.title,
    required this.vehicles,
    required this.selectedVehicleIds,
    required this.isLoading,
    required this.onChanged,
    required this.onAddVehicle,
  });

  @override
  Widget build(BuildContext context) {
    final selectedCount = selectedVehicleIds.length;

    return _SectionShell(
      icon: icon,
      title: selectedCount == 0 ? title : '$title ($selectedCount)',
      trailing: IconButton(
        onPressed: onAddVehicle,
        icon: const Icon(Icons.add),
        tooltip: 'Add vehicle',
      ),
      child: isLoading
          ? const LinearProgressIndicator()
          : ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              title: Text(
                vehicles.isEmpty
                    ? 'No vehicles'
                    : selectedCount == 0
                    ? 'Select vehicles'
                    : '$selectedCount selected',
              ),
              children: [
                for (final vehicle in vehicles)
                  CheckboxListTile(
                    value: selectedVehicleIds.contains(vehicle.id),
                    onChanged: (value) {
                      onChanged(vehicle.id, value ?? false);
                    },
                    title: Text(vehicle.name),
                    subtitle: Text(vehicle.type),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
              ],
            ),
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
                    side: BorderSide(
                      color: AppColors.steelBlue.withValues(alpha: 0.22),
                    ),
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
  final Widget? trailing;

  const _SectionShell({
    required this.icon,
    required this.title,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.snowWhite,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.steelBlue.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppColors.darkNavy),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.darkNavy,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
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
      decoration: _inputDecoration(label: label, icon: icon),
    );
  }
}

InputDecoration _inputDecoration({
  required String label,
  required IconData icon,
}) {
  return InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon),
    filled: true,
    fillColor: AppColors.snowWhite,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppSizes.inputRadius),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppSizes.inputRadius),
      borderSide: BorderSide(
        color: AppColors.steelBlue.withValues(alpha: 0.28),
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppSizes.inputRadius),
      borderSide: const BorderSide(color: AppColors.deepBlue, width: 1.4),
    ),
  );
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
