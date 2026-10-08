import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:the_audit/core/config/app_config.dart';
import 'package:the_audit/core/database/database_constants.dart';
import 'package:the_audit/core/errors/app_failure.dart';
import 'package:the_audit/features/auth/data/current_user_repository.dart';
import 'package:the_audit/core/database/app_database.dart';
import 'package:the_audit/core/utils/navbar.dart';
import 'package:the_audit/core/utils/step_indicator.dart';
import 'package:the_audit/core/utils/theme.dart';
import 'package:the_audit/core/utils/app_logger.dart';
import 'package:the_audit/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:the_audit/features/auth/presentation/cubit/auth_state.dart';
import 'package:the_audit/features/vehicle/presentation/widgets/vehicle_tiles.dart';
import 'package:the_audit/features/pre_field/data/repositories/pre_field_repository_impl.dart';
import 'package:the_audit/features/pre_field/data/repositories/session_setup_repository.dart';
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
  planned('planned', SessionStatus.planned),
  inProgress('inprogress', 'IN_PROGRESS'),
  closed('closed', SessionStatus.closed);

  final String label;
  final String dbValue;

  const PreFieldSessionStatus(this.label, this.dbValue);
}

const _log = AppLogger('CreateSession');
const _dialogLog = AppLogger('VehicleDetailsDialog');

/// IN_PROGRESS -> In progress, DATA_COLLECTION -> Data collection.
String _humanize(String dbValue) {
  final words = dbValue.toLowerCase().replaceAll('_', ' ');
  return words.isEmpty ? words : words[0].toUpperCase() + words.substring(1);
}

class _NewVehicleDraft {
  final String name;
  final VehicleType type;
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
  PreFieldSessionStatus _sessionStatus = PreFieldSessionStatus.planned;
  List<Vehicle> _vehicles = [];
  List<User> _users = [];

  /// Vehicles taken. Each vehicle is one unit; several of the same type are
  /// separate vehicles.
  Set<String> _selectedVehicleIds = {};

  /// Today's objective per selected vehicle (required, FR-PFT-05).
  final Map<String, TextEditingController> _objectiveControllers = {};

  TextEditingController _objectiveFor(String vehicleId) =>
      _objectiveControllers.putIfAbsent(vehicleId, TextEditingController.new);

  /// Objectives added per vehicle (one or more each).
  final Map<String, List<String>> _objectiveLists = {};

  /// A vehicle's objectives, including anything still typed in its field.
  List<String> _objectivesOf(String vehicleId) {
    final pending = _objectiveFor(vehicleId).text.trim();
    return [...?_objectiveLists[vehicleId], if (pending.isNotEmpty) pending];
  }

  void _addObjective(String vehicleId) {
    final text = _objectiveFor(vehicleId).text.trim();
    if (text.isEmpty) return;
    setState(() {
      _objectiveLists[vehicleId] = [...?_objectiveLists[vehicleId], text];
      _objectiveFor(vehicleId).clear();
    });
  }

  void _removeObjective(String vehicleId, int index) {
    setState(() {
      _objectiveLists[vehicleId] = [...?_objectiveLists[vehicleId]]
        ..removeAt(index);
    });
  }

  /// The session's team. PIC and VO are chosen per flight from the crew.
  Set<String> _crewUserIds = {};
  bool _loadingVehicles = true;

  /// Set after the first Next/Save on step 1, so missing picks show in red.
  bool _showSelectionErrors = false;
  bool _loadingUsers = true;
  bool _submitting = false;
  bool _gettingCurrentLocation = false;

  late final _setup = SessionSetupRepository(widget.database);

  /// Current wizard step: 0 details, 1 equipment, 2 packing, 3 review.
  int _step = 0;

  /// Equipment lists by key: [_toolsKey] for Tools, otherwise a vehicle id.
  Map<String, List<EquipmentTemplateItem>> _equipmentLists = {};
  bool _loadingEquipment = true;

  /// Template item ids ticked on the packing check.
  Set<String> _packedItemIds = {};

  /// List cards the user opened or closed on the equipment, packing and
  /// review steps. By default only the first card (Tools) is open; a key in
  /// these sets flips its card from that default.
  Set<String> _toggledLists = {};
  Set<String> _toggledPacking = {};
  Set<String> _toggledReview = {};

  /// Whether [key]'s card is open: the first card by default, flipped once
  /// the user toggles it.
  bool _isOpen(Set<String> toggled, String key) =>
      (_equipmentListKeys.isNotEmpty && key == _equipmentListKeys.first) !=
      toggled.contains(key);

  /// [toggled] with [key]'s card flipped.
  static Set<String> _flip(Set<String> toggled, String key) =>
      toggled.contains(key) ? ({...toggled}..remove(key)) : {...toggled, key};

  /// [toggled] with [key]'s card closed.
  Set<String> _closed(Set<String> toggled, String key) =>
      _isOpen(toggled, key) ? _flip(toggled, key) : toggled;

  /// Active payloads and the vehicle types each fits (empty set = any type).
  /// Active payloads and which vehicles each fits.
  PayloadCatalog _payloadCatalog = PayloadCatalog.empty;
  List<Payload> get _payloads => _payloadCatalog.payloads;

  /// Payloads taken, for all selected vehicles together.
  Set<String> _selectedPayloadIds = {};

  @override
  void initState() {
    super.initState();
    _log.t('initState');
    _loadVehicles();
    _loadUsers();
    _loadEquipmentLists();
    _loadPayloads();
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
    for (final controller in _objectiveControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  static const _toolsKey = '';

  /// Tools first, then the selected vehicles in the carousel's name order.
  List<String> get _equipmentListKeys => [
    _toolsKey,
    for (final vehicle in _vehicles)
      if (_selectedVehicleIds.contains(vehicle.id)) vehicle.id,
  ];

  Vehicle? _vehicleById(String id) {
    for (final vehicle in _vehicles) {
      if (vehicle.id == id) return vehicle;
    }
    return null;
  }

  String _listName(String key) =>
      key == _toolsKey ? 'Tools' : (_vehicleById(key)?.name ?? 'Vehicle');

  /// Only items with something to pack go on the packing check.
  static bool _isPackable(EquipmentTemplateItem item) =>
      (item.quantity ?? 0) + (item.spares ?? 0) > 0;

  List<EquipmentTemplateItem> _packableItems(String key) => [
    for (final item in _equipmentLists[key] ?? const <EquipmentTemplateItem>[])
      if (_isPackable(item)) item,
  ];

  /// (Re)loads Tools and the selected vehicles' lists from the database.
  Future<void> _loadEquipmentLists() async {
    setState(() => _loadingEquipment = true);
    try {
      final lists = <String, List<EquipmentTemplateItem>>{
        for (final key in _equipmentListKeys)
          key: await _setup.getEquipmentList(
            vehicleId: key == _toolsKey ? null : key,
          ),
      };
      _log.d(
        'loaded equipment lists: '
        '${lists.entries.map((e) => '${_listName(e.key)}=${e.value.length}').join(', ')}',
      );
      if (!mounted) return;
      final knownIds = {
        for (final items in lists.values)
          for (final item in items) item.id,
      };
      setState(() {
        _equipmentLists = lists;
        _packedItemIds = _packedItemIds.intersection(knownIds);
        _loadingEquipment = false;
      });
    } catch (error, stackTrace) {
      _log.e('load equipment lists failed', error, stackTrace);
      if (!mounted) return;
      setState(() => _loadingEquipment = false);
      _showSnack(friendlyError(error));
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
                // A new scroll position per step, so each step opens at the
                // top instead of where the previous step was scrolled to.
                key: ValueKey('step-$_step'),
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
                  StepIndicator(
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

  /// Step 1 needs its required fields, at least one vehicle and a PIC.
  /// Shows what's missing and returns false.
  bool _validateDetails() {
    final formValid = _formKey.currentState!.validate();
    final missing = [
      if (_selectedVehicleIds.isEmpty) 'at least one vehicle',
      if (_crewUserIds.isEmpty) 'at least one crew member',
    ];
    final noObjective = [
      for (final vehicle in _selectedVehicles)
        if (_objectivesOf(vehicle.id).isEmpty) vehicle.name,
    ];
    setState(() => _showSelectionErrors = true);
    if (missing.isNotEmpty) {
      _showSnack('Select ${missing.join(' and ')}.');
    } else if (noObjective.isNotEmpty) {
      _showSnack('Enter the objective for ${noObjective.join(', ')}.');
    }
    final valid = formValid && missing.isEmpty && noObjective.isEmpty;
    if (!valid) _log.d('step 0 invalid (form: $formValid, missing: $missing)');
    return valid;
  }

  void _next() {
    if (_step == 0 && !_validateDetails()) return;
    _log.d('next: step $_step -> ${_step + 1}');
    FocusScope.of(context).unfocus();
    setState(() => _step++);
    // Vehicles may have changed on step 1: show their lists.
    if (_step == 1) _loadEquipmentLists();
  }

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
        _VehicleCarouselSection(
          vehicles: _vehicles,
          selectedIds: _selectedVehicleIds,
          isLoading: _loadingVehicles,
          onTapVehicle: _onVehicleTapped,
          onEditVehicle: _editVehicle,
          onRemoveVehicle: _removeVehicle,
          onAddVehicle: _addVehicle,
          objectiveFieldFor: _objectiveField,
        ),
        if (_showSelectionErrors && _selectedVehicleIds.isEmpty)
          const _FieldError('Select at least one vehicle.'),
        if (_selectedVehicleIds.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildPayloadsSection(),
        ],
        const SizedBox(height: 12),
        _TeamMembersSection(
          icon: Icons.groups_outlined,
          title: 'Team members',
          users: _users,
          isLoading: _loadingUsers,
          crewUserIds: _crewUserIds,
          onAddCrew: _showCrewDialog,
          onRemoveCrew: (userId) => setState(() {
            _crewUserIds = {..._crewUserIds}..remove(userId);
          }),
        ),
        if (_showSelectionErrors && _crewUserIds.isEmpty)
          const _FieldError('Select at least one crew member.'),
      ],
    );
  }

  Widget _listLeading(String key) {
    if (key == _toolsKey) {
      return const Icon(Icons.handyman_outlined, color: AppColors.darkNavy);
    }
    final type = VehicleType.fromDb(_vehicleById(key)?.type ?? '');
    return type == null
        ? const Icon(Icons.flight, color: AppColors.darkNavy)
        : SizedBox.square(
            dimension: 26,
            child: Image.asset(type.imageAsset, color: AppColors.darkNavy),
          );
  }

  /// Splits an ordered list into (category, items) groups.
  static List<(String, List<EquipmentTemplateItem>)> _byCategory(
    List<EquipmentTemplateItem> items,
  ) {
    final groups = <(String, List<EquipmentTemplateItem>)>[];
    for (final item in items) {
      if (groups.isEmpty || groups.last.$1 != item.category) {
        groups.add((item.category, []));
      }
      groups.last.$2.add(item);
    }
    return groups;
  }

  Widget _buildEquipmentStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_loadingEquipment) ...[
          const LinearProgressIndicator(),
          const SizedBox(height: 12),
        ],
        if (_selectedVehicleIds.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'Select vehicles in step 1 to see their checklists.',
              style: AppTextStyles.secondary,
            ),
          ),
        for (final key in _equipmentListKeys) ...[
          _EquipmentListCard(
            leading: _listLeading(key),
            title: key == _toolsKey ? 'Tools · every session' : _listName(key),
            subtitle: '${(_equipmentLists[key] ?? const []).length} items',
            expanded: _isOpen(_toggledLists, key),
            onToggle: () => setState(() {
              _toggledLists = _flip(_toggledLists, key);
            }),
            child: _buildTemplateList(key),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _buildTemplateList(String key) {
    final items = _equipmentLists[key] ?? const <EquipmentTemplateItem>[];
    String count(int? value) => value == null ? '–' : '$value';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No items yet for ${_listName(key)}.',
              style: AppTextStyles.secondary,
            ),
          )
        else ...[
          const Row(
            children: [
              Expanded(child: Text('Item', style: AppTextStyles.label)),
              SizedBox(
                width: 44,
                child: Text(
                  'Qty',
                  textAlign: TextAlign.right,
                  style: AppTextStyles.label,
                ),
              ),
              SizedBox(
                width: 56,
                child: Text(
                  'Spare',
                  textAlign: TextAlign.right,
                  style: AppTextStyles.label,
                ),
              ),
              SizedBox(width: 12),
            ],
          ),
          for (final (category, groupItems) in _byCategory(items)) ...[
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Text(
                category.toUpperCase(),
                textAlign: TextAlign.center,
                style: AppTextStyles.equipmentCategory,
              ),
            ),
            for (final item in groupItems)
              InkWell(
                onTap: () => _editEquipmentItem(key, item),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.name,
                          style: AppTextStyles.equipmentItem,
                        ),
                      ),
                      SizedBox(
                        width: 44,
                        child: Text(
                          count(item.quantity),
                          textAlign: TextAlign.right,
                          style: AppTextStyles.equipmentCount,
                        ),
                      ),
                      SizedBox(
                        width: 56,
                        child: Text(
                          // No spares listed means none: show 0.
                          '${item.spares ?? 0}',
                          textAlign: TextAlign.right,
                          style: AppTextStyles.equipmentCount,
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                  ),
                ),
              ),
          ],
        ],
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () => _addEquipmentItem(key),
            icon: const Icon(Icons.add),
            label: const Text('Add item'),
          ),
        ),
      ],
    );
  }

  List<String> _categoriesOf(String key) => [
    for (final (category, _) in _byCategory(_equipmentLists[key] ?? const []))
      category,
  ];

  Future<void> _addEquipmentItem(String key) async {
    final result = await showDialog<_EquipmentItemResult>(
      context: context,
      builder: (_) => _EquipmentItemDialog(
        listName: _listName(key),
        categories: _categoriesOf(key),
      ),
    );
    if (result == null || !mounted) return;

    await _log.trace('addEquipmentItem', () async {
      try {
        final performedBy = await _resolvePerformedBy(
          widget.database,
          widget.authCubit.state,
        );
        await _setup.addEquipmentItem(
          vehicleId: key == _toolsKey ? null : key,
          category: result.category,
          name: result.name,
          quantity: result.quantity,
          spares: result.spares,
          performedBy: performedBy,
        );
        _log.i('equipment item added to ${_listName(key)}');
        await _loadEquipmentLists();
      } catch (error, stackTrace) {
        _log.e('add equipment item failed', error, stackTrace);
        _showSnack(friendlyError(error));
      }
    });
  }

  Future<void> _editEquipmentItem(
    String key,
    EquipmentTemplateItem item,
  ) async {
    final result = await showDialog<_EquipmentItemResult>(
      context: context,
      builder: (_) => _EquipmentItemDialog(
        listName: _listName(key),
        categories: _categoriesOf(key),
        item: item,
      ),
    );
    if (result == null || !mounted) return;

    await _log.trace('editEquipmentItem', () async {
      try {
        final performedBy = await _resolvePerformedBy(
          widget.database,
          widget.authCubit.state,
        );
        if (result.remove) {
          await _setup.removeEquipmentItem(
            id: item.id,
            performedBy: performedBy,
          );
          _log.i('equipment item ${item.id} removed');
        } else {
          await _setup.updateEquipmentItem(
            id: item.id,
            category: result.category,
            name: result.name,
            quantity: result.quantity,
            spares: result.spares,
            performedBy: performedBy,
          );
          _log.i('equipment item ${item.id} edited');
        }
        await _loadEquipmentLists();
      } catch (error, stackTrace) {
        _log.e('edit equipment item failed', error, stackTrace);
        _showSnack(friendlyError(error));
      }
    });
  }

  void _setPacked(String key, Iterable<String> itemIds, bool packed) {
    setState(() {
      _packedItemIds = packed
          ? {..._packedItemIds, ...itemIds}
          : ({..._packedItemIds}..removeAll(itemIds));
      // A fully packed list folds away.
      final items = _packableItems(key);
      if (items.isNotEmpty &&
          items.every((item) => _packedItemIds.contains(item.id))) {
        _toggledPacking = _closed(_toggledPacking, key);
      }
    });
  }

  Widget _buildPackingStep() {
    final keys = _equipmentListKeys;
    final all = [for (final key in keys) ..._packableItems(key)];
    final packed = all.where((item) => _packedItemIds.contains(item.id));
    final units = all.fold<int>(
      0,
      (sum, item) => sum + (item.quantity ?? 0) + (item.spares ?? 0),
    );

    if (all.isEmpty) {
      return const Text(
        'Nothing to pack yet. Go back a step and add quantities.',
        style: AppTextStyles.secondary,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: AppDecorations.section,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Total: ${packed.length} / ${all.length} items packed · '
                  '$units units',
                  style: AppTextStyles.sectionHeader,
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(value: packed.length / all.length),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        for (final key in keys)
          if (_packableItems(key).isNotEmpty) ...[
            _buildPackingCard(key),
            const SizedBox(height: 10),
          ],
      ],
    );
  }

  Widget _buildPackingCard(String key) {
    final items = _packableItems(key);
    final packedCount = items
        .where((item) => _packedItemIds.contains(item.id))
        .length;
    final done = packedCount == items.length;

    return _EquipmentListCard(
      leading: _listLeading(key),
      title: _listName(key),
      subtitle: 'packed $packedCount / ${items.length}',
      done: done,
      expanded: _isOpen(_toggledPacking, key),
      onToggle: () => setState(() {
        _toggledPacking = _flip(_toggledPacking, key);
      }),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (category, groupItems) in _byCategory(items)) ...[
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 2),
              child: Text(
                category.toUpperCase(),
                textAlign: TextAlign.center,
                style: AppTextStyles.equipmentCategory,
              ),
            ),
            for (final item in groupItems)
              _PackingRow(
                item: item,
                packed: _packedItemIds.contains(item.id),
                onChanged: (value) => _setPacked(key, [item.id], value),
              ),
          ],
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
          '${vehicle.name} '
              '(${VehicleType.fromDb(vehicle.type)?.label ?? vehicle.type})'
              '${_objectivesOf(vehicle.id).isEmpty ? '' : ' — ${_objectivesOf(vehicle.id).join('; ')}'}',
    ];
    final crew = [for (final id in _crewUserIds) userName(id)];
    final equipmentKeys = [
      for (final key in _equipmentListKeys)
        if (_packableItems(key).isNotEmpty) key,
    ];

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
              line(
                'Payloads',
                _selectedPayloadIds.isEmpty
                    ? '—'
                    : [
                        for (final payload in _payloads)
                          if (_selectedPayloadIds.contains(payload.payloadId))
                            payload.name,
                      ].join('\n'),
              ),
              line('Crew', crew.isEmpty ? '—' : crew.join(', ')),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SectionShell(
          icon: Icons.backpack_outlined,
          title: 'Equipment',
          child: equipmentKeys.isEmpty
              ? const Text(
                  'No equipment to pack.',
                  style: AppTextStyles.secondary,
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // One collapsible card per list (Tools, then vehicles)
                    // with what's still not packed.
                    for (final key in equipmentKeys) ...[
                      _buildReviewEquipmentCard(key),
                      if (key != equipmentKeys.last) const SizedBox(height: 8),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildReviewEquipmentCard(String key) {
    final items = _packableItems(key);
    final notPacked = [
      for (final item in items)
        if (!_packedItemIds.contains(item.id)) item,
    ];
    final packedCount = items.length - notPacked.length;

    return _EquipmentListCard(
      leading: _listLeading(key),
      title: _listName(key),
      subtitle: notPacked.isEmpty
          ? 'packed $packedCount / ${items.length}'
          : 'packed $packedCount / ${items.length} · '
                '${notPacked.length} not packed',
      done: notPacked.isEmpty,
      expanded: _isOpen(_toggledReview, key),
      onToggle: () => setState(() {
        _toggledReview = _flip(_toggledReview, key);
      }),
      child: notPacked.isEmpty
          ? const Text('Everything packed.', style: AppTextStyles.secondary)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Not packed', style: AppTextStyles.label),
                const SizedBox(height: 4),
                for (final (category, groupItems) in _byCategory(
                  notPacked,
                )) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 2),
                    child: Text(
                      category.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: AppTextStyles.equipmentCategory,
                    ),
                  ),
                  for (final item in groupItems)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.name,
                              style: AppTextStyles.notPackedItem,
                            ),
                          ),
                          Text(
                            _packLabel(item),
                            style: AppTextStyles.notPackedCount,
                          ),
                          const SizedBox(width: 12),
                        ],
                      ),
                    ),
                ],
              ],
            ),
    );
  }

  /// Creates the session with everything entered so far. [start] opens the
  /// session (flights); otherwise returns to the home page.
  Future<void> _saveSession({required bool start}) async {
    _log.d(start ? 'start session tapped' : 'save tapped');
    if (_step == 0 && !_validateDetails()) return;

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
            // One objective per line.
            objective: _objectivesOf(vehicleId).join('\n'),
            performedBy: createdBy,
          );
        }
        _log.d('added ${_selectedVehicleIds.length} vehicles');

        final links = await _setup.linkPayloadsToSessionVehicles(
          sessionId: sessionId,
          catalog: _payloadCatalog,
          payloadIds: _selectedPayloadIds,
          performedBy: createdBy,
        );
        _log.d('saved $links vehicle payload links');

        final teamMembers = <({String userId, String role})>[
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
        ).showSnackBar(SnackBar(content: Text(friendlyError(error))));
      } finally {
        if (mounted) {
          setState(() => _submitting = false);
        }
      }
    });
  }

  /// Stores the session's equipment snapshot: every item that's on the
  /// packing check, with whether it was ticked (FR-PFT-09).
  Future<void> _saveEquipment({
    required String sessionId,
    required String performedBy,
  }) async {
    await _log.trace('saveEquipment', () async {
      await _setup.saveSessionEquipment(
        sessionId: sessionId,
        vehicleIds: [
          for (final key in _equipmentListKeys)
            if (key != _toolsKey) key,
        ],
        loadedLists: {
          for (final entry in _equipmentLists.entries)
            entry.key == _toolsKey ? null : entry.key: entry.value,
        },
        isPackable: _isPackable,
        packedItemIds: _packedItemIds,
        performedBy: performedBy,
      );
    });
  }

  Future<void> _loadVehicles() async {
    try {
      final vehicles = await _setup.getActiveVehicles();
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
      ).showSnackBar(SnackBar(content: Text(friendlyError(error))));
    }
  }

  /// Shows the saved (local) users immediately, then refreshes them from
  /// Firestore. Offline, the saved list stays.
  Future<void> _loadUsers() async {
    Future<void> showLocal() async {
      final users = await _setup.getSelectableUsers();
      _log.d('loaded ${users.length} users');
      if (!mounted) return;
      setState(() => _users = users);
    }

    try {
      await showLocal();
      // Saved users are enough to pick from: stop waiting while the team
      // list refreshes from Firestore (up to 10 s when offline).
      if (_users.isNotEmpty && mounted) {
        setState(() => _loadingUsers = false);
      }

      await _setup.refreshUsersFromDirectory();
      await showLocal();
    } catch (error, stackTrace) {
      _log.e('load users failed', error, stackTrace);
      _showSnack(friendlyError(error));
    } finally {
      if (mounted) setState(() => _loadingUsers = false);
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
          timeLimit: AppConfig.gpsFixTimeLimit,
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
        _showSnack(
          error is TimeoutException
              ? 'Could not get a GPS fix in time. Try again or type the '
                    'coordinates.'
              : friendlyError(error),
        );
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

  /// First tap takes the vehicle (asks how many); tapping a selected
  /// vehicle removes it.
  Future<void> _onVehicleTapped(Vehicle vehicle) async {
    if (_selectedVehicleIds.contains(vehicle.id)) {
      _removeVehicle(vehicle);
      return;
    }
    _log.d('vehicle ${vehicle.id} selected');
    setState(() {
      _selectedVehicleIds = {..._selectedVehicleIds, vehicle.id};
    });
  }

  Future<void> _loadPayloads() async {
    try {
      final catalog = await _setup.loadPayloadCatalog();
      if (!mounted) return;
      setState(() => _payloadCatalog = catalog);
    } catch (error, stackTrace) {
      _log.e('load payloads failed', error, stackTrace);
    }
  }

  List<Payload> _payloadsFor(Vehicle vehicle) =>
      _payloadCatalog.payloadsFor(vehicle);

  /// Payloads that fit at least one selected vehicle, each listed once.
  List<Payload> get _payloadOptions {
    final selected = _selectedVehicles;
    return [
      for (final payload in _payloads)
        if (selected.any((vehicle) => _payloadsFor(vehicle).contains(payload)))
          payload,
    ];
  }

  List<Vehicle> get _selectedVehicles => [
    for (final vehicle in _vehicles)
      if (_selectedVehicleIds.contains(vehicle.id)) vehicle,
  ];

  void _togglePayload(Payload payload, bool selected) {
    _log.d('payload ${payload.payloadId} ${selected ? 'selected' : 'removed'}');
    setState(() {
      _selectedPayloadIds = selected
          ? {..._selectedPayloadIds, payload.payloadId}
          : ({..._selectedPayloadIds}..remove(payload.payloadId));
    });
  }

  /// Required objective for one selected vehicle (FR-PFT-05).
  Widget _objectiveField(Vehicle vehicle) {
    final controller = _objectiveFor(vehicle.id);
    final added = _objectiveLists[vehicle.id] ?? const <String>[];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          key: ValueKey('objective-${vehicle.id}'),
          controller: controller,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _addObjective(vehicle.id),
          validator: (_) => _objectivesOf(vehicle.id).isEmpty
              ? 'Add at least one objective'
              : null,
          decoration:
              AppDecorations.field(
                label: 'Objective',
                icon: Icons.flag_outlined,
              ).copyWith(
                suffixIcon: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller,
                  builder: (context, value, _) => IconButton(
                    onPressed: value.text.trim().isEmpty
                        ? null
                        : () => _addObjective(vehicle.id),
                    icon: const Icon(Icons.add),
                    tooltip: 'Add objective',
                  ),
                ),
              ),
        ),
        if (added.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var i = 0; i < added.length; i++)
                InputChip(
                  label: Text(added[i]),
                  onDeleted: () => _removeObjective(vehicle.id, i),
                  deleteButtonTooltipMessage: 'Remove objective',
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ],
      ],
    );
  }

  /// Payloads for all selected vehicles together: one chip per payload.
  Widget _buildPayloadsSection() {
    final options = _payloadOptions;

    return _SectionShell(
      icon: Icons.camera_alt_outlined,
      title: _selectedPayloadIds.isEmpty
          ? 'Payloads'
          : 'Payloads (${_selectedPayloadIds.length})',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (options.isEmpty)
            const Text(
              'No compatible payloads.',
              style: AppTextStyles.secondary,
            ),
          for (final payload in options)
            FilterChip(
              label: Text(payload.name),
              tooltip: payload.category,
              selected: _selectedPayloadIds.contains(payload.payloadId),
              onSelected: (value) => _togglePayload(payload, value),
            ),
          ActionChip(
            avatar: const Icon(Icons.add, size: 18),
            label: const Text('New payload'),
            onPressed: _addPayload,
          ),
        ],
      ),
    );
  }

  /// Creates a payload (saved to the payload list for future sessions too)
  /// and selects it.
  Future<void> _addPayload() async {
    final draft = await showDialog<_NewPayloadDraft>(
      context: context,
      builder: (_) => _NewPayloadDialog(
        // Default to the types of the vehicles selected now.
        initialTypes: {
          for (final vehicle in _selectedVehicles)
            vehicle.type.trim().toUpperCase(),
        },
      ),
    );
    if (draft == null || !mounted) return;

    await _log.trace('addPayload', () async {
      try {
        final performedBy = await _resolvePerformedBy(
          widget.database,
          widget.authCubit.state,
        );
        final payloadId = await _setup.createPayload(
          name: draft.name,
          category: draft.category,
          storageType: draft.storageType,
          storageCapacity: draft.storageCapacity,
          vehicleTypes: draft.vehicleTypes.toList(),
          performedBy: performedBy,
        );
        _log.i('payload created $payloadId');
        await _loadPayloads();
        if (!mounted) return;
        // Select it if it fits a selected vehicle.
        if (_payloadOptions.any((p) => p.payloadId == payloadId)) {
          setState(() {
            _selectedPayloadIds = {..._selectedPayloadIds, payloadId};
          });
        }
      } catch (error, stackTrace) {
        _log.e('add payload failed', error, stackTrace);
        _showSnack(friendlyError(error));
      }
    });
  }


  void _removeVehicle(Vehicle vehicle) {
    _log.d('vehicle ${vehicle.id} removed');
    setState(() {
      _selectedVehicleIds = {..._selectedVehicleIds}..remove(vehicle.id);
      // Drop payloads that no longer fit any selected vehicle.
      final stillFitting = {
        for (final payload in _payloadOptions) payload.payloadId,
      };
      _selectedPayloadIds = _selectedPayloadIds.intersection(stillFitting);
    });
  }

  Future<void> _editVehicle(Vehicle vehicle) async {
    final draft = await showDialog<_NewVehicleDraft>(
      context: context,
      builder: (_) => _VehicleDetailsDialog(vehicle: vehicle),
    );
    if (draft == null || !mounted || !_detailsChanged(vehicle, draft)) return;

    await _log.trace('editVehicle', () async {
      try {
        final performedBy = await _resolvePerformedBy(
          widget.database,
          widget.authCubit.state,
        );
        // Clearing fields and renewing the checklist for a new type are
        // handled by the repository.
        await _setup.editVehicle(
          before: vehicle,
          name: draft.name,
          type: draft.type.dbValue,
          frameMake: draft.frameMake,
          frameModel: draft.frameModel,
          motorCount: draft.motorCount,
          frameStyle: draft.frameStyle,
          firmwareTarget: draft.firmwareTarget,
          defaultFailSafeProfile: draft.defaultFailSafeProfile,
          notes: draft.notes,
          performedBy: performedBy,
        );
        _log.i('vehicle ${vehicle.id} edited');
        await _loadVehicles();
      } catch (error, stackTrace) {
        _log.e('edit vehicle failed', error, stackTrace);
        _showSnack(friendlyError(error));
      }
    });
  }

  Future<void> _addVehicle() async {
    final draft = await showDialog<_NewVehicleDraft>(
      context: context,
      builder: (_) => const _VehicleDetailsDialog(),
    );
    if (draft == null || !mounted) return;

    await _log.trace('addVehicle', () async {
      try {
        final performedBy = await _resolvePerformedBy(
          widget.database,
          widget.authCubit.state,
        );
        // Common pre-flight items plus the ones for its type.
        final vehicleId = await _setup.createVehicle(
          name: draft.name,
          type: draft.type.dbValue,
          frameMake: draft.frameMake,
          frameModel: draft.frameModel,
          motorCount: draft.motorCount,
          frameStyle: draft.frameStyle,
          firmwareTarget: draft.firmwareTarget,
          defaultFailSafeProfile: draft.defaultFailSafeProfile,
          notes: draft.notes,
          performedBy: performedBy,
        );
        _log.i('vehicle created $vehicleId (${draft.type.dbValue})');
        await _loadVehicles();
        if (!mounted) return;

        // A vehicle added here is meant to be taken: select it.
        setState(() {
          _selectedVehicleIds = {..._selectedVehicleIds, vehicleId};
        });
      } catch (error, stackTrace) {
        _log.e('add vehicle failed', error, stackTrace);
        _showSnack(friendlyError(error));
      }
    });
  }

  Future<void> _showCrewDialog() async {
    _log.d('crew picker opened');
    final selectedUserIds = await showDialog<Set<String>>(
      context: context,
      builder: (context) {
        final selectedIds = {..._crewUserIds};

        return AlertDialog(
          title: const Text('Select crew'),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              if (_loadingUsers && _users.isEmpty) {
                return const SizedBox(
                  width: 260,
                  child: LinearProgressIndicator(),
                );
              }

              if (_users.isEmpty) {
                return const SizedBox(
                  width: 260,
                  child: Text(
                    'No users yet. People appear here after they sign in to '
                    'the app once (or are added in Firestore).',
                  ),
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
                        onChanged: (value) => setDialogState(() {
                          value ?? false
                              ? selectedIds.add(user.id)
                              : selectedIds.remove(user.id);
                        }),
                        title: Text(user.name),
                        subtitle: Text(user.email),
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
      _log.d('crew picker cancelled');
      return;
    }
    _log.d('crew picked: ${selectedUserIds.length} user(s)');
    setState(() => _crewUserIds = selectedUserIds);
  }

  bool _detailsChanged(Vehicle vehicle, _NewVehicleDraft draft) {
    String? norm(String? value) =>
        (value == null || value.trim().isEmpty) ? null : value.trim();
    return vehicle.name.trim() != draft.name ||
        norm(vehicle.frameMake) != draft.frameMake ||
        norm(vehicle.frameModel) != draft.frameModel ||
        vehicle.motorCount != draft.motorCount ||
        vehicle.type != draft.type.dbValue ||
        norm(vehicle.frameStyle) != draft.frameStyle ||
        norm(vehicle.firmwareTarget) != draft.firmwareTarget ||
        norm(vehicle.defaultFailSafeProfile) != draft.defaultFailSafeProfile ||
        norm(vehicle.notes) != draft.notes;
  }


  /// The signed-in user, as a row in the local users table.
  Future<String> _resolvePerformedBy(
    AppDatabase database,
    AuthState authState,
  ) => CurrentUserRepository(database).resolvePerformedBy(authState);

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

/// "4", or "4 + 4 spare".
String _packLabel(EquipmentTemplateItem item) {
  final quantity = item.quantity ?? 0;
  final spares = item.spares ?? 0;
  if (spares == 0) return '$quantity';
  if (quantity == 0) return '$spares spare';
  return '$quantity + $spares spare';
}

class _NewPayloadDraft {
  final String name;
  final String category;
  final String? storageType;
  final String? storageCapacity;
  final Set<String> vehicleTypes;

  const _NewPayloadDraft({
    required this.name,
    required this.category,
    required this.storageType,
    required this.storageCapacity,
    required this.vehicleTypes,
  });
}

/// Add a payload: name, category, storage, and which vehicle types it fits.
class _NewPayloadDialog extends StatefulWidget {
  final Set<String> initialTypes;

  const _NewPayloadDialog({required this.initialTypes});

  @override
  State<_NewPayloadDialog> createState() => _NewPayloadDialogState();
}

class _NewPayloadDialogState extends State<_NewPayloadDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _categoryController = TextEditingController();
  final _storageTypeController = TextEditingController();
  final _storageCapacityController = TextEditingController();
  late Set<String> _types = widget.initialTypes.isEmpty
      ? {for (final type in VehicleType.values) type.dbValue}
      : {...widget.initialTypes};
  bool _showTypeError = false;

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _storageTypeController.dispose();
    _storageCapacityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Expanded(child: Text('New payload')),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
            tooltip: 'Close',
          ),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _nameController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Enter a payload name'
                      : null,
                  decoration: AppDecorations.field(
                    label: 'Payload name',
                    icon: Icons.camera_alt_outlined,
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _categoryController,
                  textCapitalization: TextCapitalization.words,
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Enter a category'
                      : null,
                  decoration: AppDecorations.field(
                    label: 'Category (e.g. RGB Camera, Thermal)',
                    icon: Icons.category_outlined,
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _storageTypeController,
                  decoration: AppDecorations.field(
                    label: 'Storage (e.g. SD card)',
                    icon: Icons.sd_storage_outlined,
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _storageCapacityController,
                  decoration: AppDecorations.field(
                    label: 'Storage capacity (e.g. 64GB)',
                    icon: Icons.storage_outlined,
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Fits vehicle types', style: AppTextStyles.label),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final type in VehicleType.values)
                      FilterChip(
                        label: Text(type.label),
                        selected: _types.contains(type.dbValue),
                        onSelected: (value) => setState(() {
                          _types = value
                              ? {..._types, type.dbValue}
                              : ({..._types}..remove(type.dbValue));
                          _showTypeError = false;
                        }),
                      ),
                  ],
                ),
                if (_showTypeError)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      'Pick at least one vehicle type.',
                      style: AppTextStyles.error,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [FilledButton(onPressed: _submit, child: const Text('Add'))],
    );
  }

  void _submit() {
    final formValid = _formKey.currentState?.validate() ?? false;
    if (_types.isEmpty) setState(() => _showTypeError = true);
    if (!formValid || _types.isEmpty) return;

    String? blankToNull(String text) =>
        text.trim().isEmpty ? null : text.trim();
    Navigator.of(context).pop(
      _NewPayloadDraft(
        name: _nameController.text.trim(),
        category: _categoryController.text.trim(),
        storageType: blankToNull(_storageTypeController.text),
        storageCapacity: blankToNull(_storageCapacityController.text),
        vehicleTypes: _types,
      ),
    );
  }
}

/// Red message under a section, like a form field's error text.
class _FieldError extends StatelessWidget {
  final String message;

  const _FieldError(this.message);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 4),
      child: Text(message, style: AppTextStyles.error),
    );
  }
}

/// Collapsible card for one equipment list (Tools or a vehicle).
class _EquipmentListCard extends StatelessWidget {
  final Widget leading;
  final String title;
  final String subtitle;
  final bool expanded;
  final bool done;
  final VoidCallback onToggle;
  final Widget child;

  const _EquipmentListCard({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.expanded,
    required this.onToggle,
    required this.child,
    this.done = false,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: AppDecorations.section,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: const BorderRadius.all(
              Radius.circular(AppSizes.panelRadius),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  leading,
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: AppTextStyles.sectionHeader),
                        Text(subtitle, style: AppTextStyles.caption),
                      ],
                    ),
                  ),
                  if (done)
                    const Padding(
                      padding: EdgeInsets.only(right: 4),
                      child: Icon(
                        Icons.check_circle,
                        color: AppColors.deepBlue,
                      ),
                    ),
                  Icon(expanded ? Icons.expand_less : Icons.expand_more),
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 4, 12),
              child: child,
            ),
        ],
      ),
    );
  }
}

/// One tickable line on the packing check, with a large count.
class _PackingRow extends StatelessWidget {
  final EquipmentTemplateItem item;
  final bool packed;
  final ValueChanged<bool> onChanged;

  const _PackingRow({
    required this.item,
    required this.packed,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final units = (item.quantity ?? 0) + (item.spares ?? 0);
    return InkWell(
      onTap: () => onChanged(!packed),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Checkbox(
              value: packed,
              onChanged: (value) => onChanged(value ?? false),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name, style: AppTextStyles.equipmentItem),
                  if ((item.spares ?? 0) > 0)
                    Text('$units units', style: AppTextStyles.caption),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(_packLabel(item), style: AppTextStyles.packingCount),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}

class _EquipmentItemResult {
  final String category;
  final String name;
  final int? quantity;
  final int? spares;
  final bool remove;

  const _EquipmentItemResult({
    required this.category,
    required this.name,
    required this.quantity,
    required this.spares,
    this.remove = false,
  });
}

/// Add / edit an equipment item: category, name, quantity, spares.
class _EquipmentItemDialog extends StatefulWidget {
  final String listName;
  final List<String> categories;

  /// Item being edited; null adds a new one.
  final EquipmentTemplateItem? item;

  const _EquipmentItemDialog({
    required this.listName,
    required this.categories,
    this.item,
  });

  @override
  State<_EquipmentItemDialog> createState() => _EquipmentItemDialogState();
}

class _EquipmentItemDialogState extends State<_EquipmentItemDialog> {
  static const _newCategory = '__new__';
  static const _suggestions = [
    'Airframe',
    'Subsystems',
    'Communication Systems',
    'Power Systems',
  ];

  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
    text: widget.item?.name ?? '',
  );
  late final _quantityController = TextEditingController(
    text: widget.item?.quantity?.toString() ?? '',
  );
  late final _sparesController = TextEditingController(
    text: widget.item?.spares?.toString() ?? '',
  );
  final _newCategoryController = TextEditingController();

  late String _category =
      widget.item?.category ??
      (widget.categories.isNotEmpty ? widget.categories.first : _newCategory);

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _sparesController.dispose();
    _newCategoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.item == null;
    final suggestions = [
      for (final suggestion in _suggestions)
        if (!widget.categories.contains(suggestion)) suggestion,
    ];

    return AlertDialog(
      title: Row(
        children: [
          Expanded(
            child: Text(
              isNew
                  ? 'Add item · ${widget.listName}'
                  : 'Edit ${widget.item!.name}',
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
            tooltip: 'Close',
          ),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  isExpanded: true,
                  decoration: AppDecorations.field(
                    label: 'Category',
                    icon: Icons.folder_outlined,
                  ),
                  items: [
                    for (final category in widget.categories)
                      DropdownMenuItem(value: category, child: Text(category)),
                    const DropdownMenuItem(
                      value: _newCategory,
                      child: Text('New category…'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _category = value);
                  },
                ),
                if (_category == _newCategory) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _newCategoryController,
                    textCapitalization: TextCapitalization.words,
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                        ? 'Enter a category'
                        : null,
                    decoration: AppDecorations.field(
                      label: 'New category',
                      icon: Icons.create_new_folder_outlined,
                    ),
                  ),
                  if (suggestions.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final suggestion in suggestions)
                          ActionChip(
                            label: Text(suggestion),
                            onPressed: () => setState(
                              () => _newCategoryController.text = suggestion,
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
                const SizedBox(height: 14),
                TextFormField(
                  controller: _nameController,
                  autofocus: isNew,
                  textCapitalization: TextCapitalization.sentences,
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Enter an item name'
                      : null,
                  decoration: AppDecorations.field(
                    label: 'Item',
                    icon: Icons.inventory_2_outlined,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _quantityController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: AppDecorations.field(
                          label: 'Quantity',
                          icon: Icons.tag,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _sparesController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: AppDecorations.field(
                          label: 'Spares',
                          icon: Icons.add_box_outlined,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        if (!isNew)
          TextButton(
            onPressed: _confirmRemove,
            style: TextButton.styleFrom(foregroundColor: AppColors.errorRed),
            child: const Text('Remove from list'),
          ),
        FilledButton(onPressed: _submit, child: Text(isNew ? 'Add' : 'Save')),
      ],
    );
  }

  Future<void> _confirmRemove() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove ${widget.item!.name}?'),
        content: Text(
          'It will no longer appear on the ${widget.listName} list for new '
          'sessions. Sessions already saved keep it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    Navigator.of(context).pop(
      _EquipmentItemResult(
        category: widget.item!.category,
        name: widget.item!.name,
        quantity: widget.item!.quantity,
        spares: widget.item!.spares,
        remove: true,
      ),
    );
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final category = _category == _newCategory
        ? _newCategoryController.text.trim()
        : _category;
    Navigator.of(context).pop(
      _EquipmentItemResult(
        category: category,
        name: _nameController.text.trim(),
        quantity: int.tryParse(_quantityController.text.trim()),
        spares: int.tryParse(_sparesController.text.trim()),
      ),
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

/// Add / edit a vehicle's details. Returns the entered details, or null on
/// Cancel.
class _VehicleDetailsDialog extends StatefulWidget {
  /// Vehicle being edited; null adds a new one.
  final Vehicle? vehicle;

  const _VehicleDetailsDialog({this.vehicle});

  @override
  State<_VehicleDetailsDialog> createState() => _VehicleDetailsDialogState();
}

class _VehicleDetailsDialogState extends State<_VehicleDetailsDialog> {
  static const _frameModels = ['Fixed', 'Folding'];

  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
    text: widget.vehicle?.name ?? '',
  );
  late final _frameMakeController = TextEditingController(
    text: widget.vehicle?.frameMake ?? '',
  );
  late final _motorCountController = TextEditingController(
    text: widget.vehicle?.motorCount?.toString() ?? '',
  );
  late final _frameStyleController = TextEditingController(
    text: widget.vehicle?.frameStyle ?? '',
  );
  late final _firmwareTargetController = TextEditingController(
    text: widget.vehicle?.firmwareTarget ?? '',
  );
  late final _failSafeController = TextEditingController(
    text: widget.vehicle?.defaultFailSafeProfile ?? '',
  );
  late final _notesController = TextEditingController(
    text: widget.vehicle?.notes ?? '',
  );

  late VehicleType _type =
      VehicleType.fromDb(widget.vehicle?.type ?? '') ?? VehicleType.multirotor;
  late String? _frameModel = _blankToNull(widget.vehicle?.frameModel);

  bool get _isNew => widget.vehicle == null;

  @override
  void initState() {
    super.initState();
    _dialogLog.t(
      _isNew ? 'opened: add vehicle' : 'opened: edit ${widget.vehicle!.id}',
    );
  }

  @override
  void dispose() {
    for (final controller in [
      _nameController,
      _frameMakeController,
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

  @override
  Widget build(BuildContext context) {
    // Keep an older free-text frame model selectable instead of crashing the
    // dropdown.
    final frameModels = [
      ..._frameModels,
      if (_frameModel != null && !_frameModels.contains(_frameModel))
        _frameModel!,
    ];

    return AlertDialog(
      title: Row(
        children: [
          SizedBox.square(
            dimension: 28,
            child: Image.asset(_type.imageAsset, color: AppColors.darkNavy),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _isNew ? 'Add vehicle' : 'Edit ${widget.vehicle!.name}',
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            // Room for the first field's floating label, which sits above
            // its border and would otherwise be clipped.
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  autofocus: _isNew,
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
                DropdownButtonFormField<VehicleType>(
                  initialValue: _type,
                  decoration: AppDecorations.field(
                    label: 'Vehicle type',
                    icon: Icons.category_outlined,
                  ),
                  items: [
                    for (final type in VehicleType.values)
                      DropdownMenuItem(value: type, child: Text(type.label)),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _type = value);
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _frameMakeController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: AppDecorations.field(
                    label: 'Frame make',
                    icon: Icons.precision_manufacturing_outlined,
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _frameModel,
                  decoration: AppDecorations.field(
                    label: 'Frame model',
                    icon: Icons.view_in_ar_outlined,
                  ),
                  items: [
                    for (final model in frameModels)
                      DropdownMenuItem(value: model, child: Text(model)),
                  ],
                  onChanged: (value) => setState(() => _frameModel = value),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _motorCountController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: AppDecorations.field(
                    // Total motors: a 4+1 VTOL (4 lift + 1 pusher) is 5.
                    label: 'Motor count (total)',
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
        TextButton(
          onPressed: () {
            _dialogLog.d('cancelled');
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: Text(_isNew ? 'Add' : 'Save')),
      ],
    );
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      _dialogLog.d('submit: invalid form');
      return;
    }
    _dialogLog.d(
      'submit: ${_isNew ? 'new' : widget.vehicle!.id} (${_type.dbValue})',
    );

    Navigator.of(context).pop(
      _NewVehicleDraft(
        name: _nameController.text.trim(),
        type: _type,
        frameMake: _blankToNull(_frameMakeController.text),
        frameModel: _frameModel,
        motorCount: int.tryParse(_motorCountController.text.trim()),
        frameStyle: _blankToNull(_frameStyleController.text),
        firmwareTarget: _blankToNull(_firmwareTargetController.text),
        defaultFailSafeProfile: _blankToNull(_failSafeController.text),
        notes: _blankToNull(_notesController.text),
      ),
    );
  }

  static String? _blankToNull(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }
}

/// "Vehicles taken": every saved vehicle in a carousel, then an "Add new
/// vehicle" card. Tap a vehicle to take it, tap again to remove it; the edit
/// button opens its details. Selected vehicles are listed below as chips
/// (tap = edit, × = remove).
class _VehicleCarouselSection extends StatefulWidget {
  final List<Vehicle> vehicles;

  final Set<String> selectedIds;
  final bool isLoading;
  final ValueChanged<Vehicle> onTapVehicle;
  final ValueChanged<Vehicle> onEditVehicle;
  final ValueChanged<Vehicle> onRemoveVehicle;
  final VoidCallback onAddVehicle;

  /// The objective field shown under each selected vehicle.
  final Widget Function(Vehicle vehicle) objectiveFieldFor;

  const _VehicleCarouselSection({
    required this.vehicles,
    required this.selectedIds,
    required this.isLoading,
    required this.onTapVehicle,
    required this.onEditVehicle,
    required this.onRemoveVehicle,
    required this.onAddVehicle,
    required this.objectiveFieldFor,
  });

  @override
  State<_VehicleCarouselSection> createState() =>
      _VehicleCarouselSectionState();
}

class _VehicleCarouselSectionState extends State<_VehicleCarouselSection> {
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
    final vehicles = widget.vehicles;
    // One page per vehicle plus the trailing "Add new vehicle" page.
    final pageCount = vehicles.length + 1;
    final page = _page.clamp(0, pageCount - 1);
    // The objective editor shows only while a selected vehicle is on screen.
    final showingSelected =
        page < vehicles.length &&
        widget.selectedIds.contains(vehicles[page].id);
    final selected = [
      for (final vehicle in vehicles)
        if (widget.selectedIds.contains(vehicle.id)) vehicle,
    ];

    return _SectionShell(
      icon: Icons.flight_takeoff_outlined,
      title: selected.isEmpty
          ? 'Vehicles taken'
          : 'Vehicles taken (${selected.length})',
      child: widget.isLoading
          ? const LinearProgressIndicator()
          : Column(
              children: [
                SizedBox(
                  height: 236,
                  child: Row(
                    children: [
                      CarouselArrow(
                        icon: Icons.chevron_left,
                        tooltip: 'Previous',
                        onPressed: page > 0 ? () => _goTo(page - 1) : null,
                      ),
                      Expanded(
                        child: PageView.builder(
                          controller: _pageController,
                          itemCount: pageCount,
                          onPageChanged: (value) =>
                              setState(() => _page = value),
                          itemBuilder: (context, index) {
                            if (index == vehicles.length) {
                              return _AddVehicleCard(
                                onTap: widget.onAddVehicle,
                              );
                            }
                            final vehicle = vehicles[index];
                            return _VehicleCard(
                              vehicle: vehicle,
                              isSelected: widget.selectedIds.contains(
                                vehicle.id,
                              ),
                              onTap: () => widget.onTapVehicle(vehicle),
                              onEdit: () => widget.onEditVehicle(vehicle),
                            );
                          },
                        ),
                      ),
                      CarouselArrow(
                        icon: Icons.chevron_right,
                        tooltip: 'Next',
                        onPressed: page < pageCount - 1
                            ? () => _goTo(page + 1)
                            : null,
                      ),
                    ],
                  ),
                ),
                // The objective editor for the vehicle on screen, outside the
                // fixed-height pages so it takes exactly the space it needs
                // and grows as objectives are added.
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  alignment: Alignment.topCenter,
                  child: showingSelected
                      ? Padding(
                          key: ValueKey('objectives-${vehicles[page].id}'),
                          padding: const EdgeInsets.fromLTRB(48, 4, 48, 0),
                          child: widget.objectiveFieldFor(vehicles[page]),
                        )
                      : const SizedBox(width: double.infinity),
                ),
                const SizedBox(height: 8),
                PageDots(count: pageCount, current: page),
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
                            avatar: VehicleType.fromDb(vehicle.type) == null
                                ? const Icon(Icons.flight, size: 18)
                                : Image.asset(
                                    VehicleType.fromDb(
                                      vehicle.type,
                                    )!.imageAsset,
                                    color: AppColors.darkNavy,
                                  ),
                            label: Text(vehicle.name),
                            tooltip: 'Edit ${vehicle.name}',
                            onPressed: () => widget.onEditVehicle(vehicle),
                            onDeleted: () => widget.onRemoveVehicle(vehicle),
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

class _VehicleCard extends StatelessWidget {
  final Vehicle vehicle;

  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  const _VehicleCard({
    required this.vehicle,
    required this.isSelected,
    required this.onTap,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final type = VehicleType.fromDb(vehicle.type);
    final meta = isSelected
        ? 'SELECTED · TAP TO REMOVE'
        : '${type?.label.toUpperCase() ?? vehicle.type} · TAP TO SELECT';

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          vehicle.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.vehicleName,
        ),
        const SizedBox(height: 10),
        Stack(
          clipBehavior: Clip.none,
          children: [
            Semantics(
              button: true,
              selected: isSelected,
              label: isSelected
                  ? 'Remove ${vehicle.name}'
                  : 'Take ${vehicle.name}',
              child: GestureDetector(
                onTap: onTap,
                behavior: HitTestBehavior.opaque,
                child: VehicleHexTile(type: type, isSelected: isSelected),
              ),
            ),
            // Edit button on the hexagon's upper-right edge.
            Positioned(
              top: 10,
              right: -18,
              child: Material(
                color: AppColors.snowWhite,
                shape: const CircleBorder(
                  side: BorderSide(color: AppColors.borderStrong),
                ),
                child: IconButton(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  tooltip: 'Edit ${vehicle.name}',
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          meta,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: isSelected
              ? AppTextStyles.vehicleMeta.copyWith(color: AppColors.darkNavy)
              : AppTextStyles.vehicleMeta,
        ),
      ],
    );
  }
}

class _AddVehicleCard extends StatelessWidget {
  final VoidCallback onTap;

  const _AddVehicleCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Add new vehicle',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('New vehicle', style: AppTextStyles.vehicleName),
            SizedBox(height: 10),
            VehicleHexTile(type: null, isSelected: false, icon: Icons.add),
            SizedBox(height: 10),
            Text('TAP TO ADD', style: AppTextStyles.vehicleMeta),
          ],
        ),
      ),
    );
  }
}

class _TeamMembersSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<User> users;
  final bool isLoading;
  final Set<String> crewUserIds;
  final VoidCallback onAddCrew;
  final ValueChanged<String> onRemoveCrew;

  const _TeamMembersSection({
    required this.icon,
    required this.title,
    required this.users,
    required this.isLoading,
    required this.crewUserIds,
    required this.onAddCrew,
    required this.onRemoveCrew,
  });

  @override
  Widget build(BuildContext context) {
    final crew = [
      for (final user in users)
        if (crewUserIds.contains(user.id)) user,
    ];

    return _SectionShell(
      icon: icon,
      title: crew.isEmpty ? title : '$title (${crew.length})',
      trailing: IconButton(
        onPressed: onAddCrew,
        icon: const Icon(Icons.add),
        tooltip: 'Add crew',
        visualDensity: VisualDensity.compact,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isLoading) ...[
            const LinearProgressIndicator(),
            const SizedBox(height: 8),
          ],
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (crew.isEmpty && !isLoading)
                const Text(
                  'No crew yet. Tap + to add.',
                  style: AppTextStyles.secondary,
                ),
              for (final user in crew)
                InputChip(
                  avatar: const Icon(Icons.person_outline, size: 18),
                  label: Text(user.name),
                  onDeleted: () => onRemoveCrew(user.id),
                  deleteButtonTooltipMessage: 'Remove',
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionShell extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  /// Optional action at the right of the header (e.g. a + button).
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
      decoration: AppDecorations.section,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppColors.darkNavy),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: AppTextStyles.sectionHeader)),
              ?trailing,
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
