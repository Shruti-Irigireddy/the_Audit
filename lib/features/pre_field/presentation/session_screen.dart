import 'package:drift/drift.dart' show InsertMode;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import 'package:the_audit/core/database/app_database.dart';
import 'package:the_audit/core/utils/navbar.dart';
import 'package:the_audit/core/utils/theme.dart';
import 'package:the_audit/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:the_audit/features/post_flight/data/repositories/post_flight_repository_impl.dart';
import 'package:the_audit/features/post_flight/presentation/cubit/post_flight_cubit.dart';
import 'package:the_audit/features/post_flight/presentation/cubit/post_flight_state.dart';
import 'package:the_audit/features/pre_field/data/repositories/pre_field_repository_impl.dart';
import 'package:the_audit/features/pre_field/domain/entities/field_session_entity.dart';
import 'package:the_audit/features/pre_field/domain/entities/session_user_entity.dart';
import 'package:the_audit/features/pre_field/domain/entities/session_vehicle_entity.dart';
import 'package:the_audit/features/pre_field/presentation/cubit/pre_field_cubit.dart';
import 'package:the_audit/features/pre_field/presentation/cubit/pre_field_state.dart';
import 'package:the_audit/features/pre_flight/data/repositories/pre_flight_repository_impl.dart';
import 'package:the_audit/features/pre_flight/domain/dtos/pre_flight_dtos.dart';
import 'package:the_audit/features/pre_flight/domain/entities/sortie_entity.dart';
import 'package:the_audit/features/pre_flight/presentation/cubit/pre_flight_cubit.dart';
import 'package:the_audit/features/pre_flight/presentation/cubit/pre_flight_state.dart';

const _uuid = Uuid();

enum _LoopStep { setup, checklist, postFlight }

class SessionScreen extends StatefulWidget {
  final AppDatabase database;
  final AuthCubit authCubit;
  final String sessionId;

  const SessionScreen({
    super.key,
    required this.database,
    required this.authCubit,
    required this.sessionId,
  });

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  late final PreFieldCubit _preFieldCubit;
  late final PreFlightCubit _preFlightCubit;
  late final PostFlightCubit _postFlightCubit;

  final _objectiveController = TextEditingController();
  final _objectiveNotesController = TextEditingController();
  final _issuesController = TextEditingController();
  final _notesController = TextEditingController();

  _LoopStep _step = _LoopStep.setup;
  String? _sessionVehicleId;
  String? _picUserId;
  SortieEntity? _sortie;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _preFieldCubit = PreFieldCubit(
      PreFieldRepositoryImpl(widget.database.preFieldDao),
    )..loadSession(widget.sessionId);
    _preFlightCubit = PreFlightCubit(
      PreFlightRepositoryImpl(widget.database.preFlightDao),
    );
    _postFlightCubit = PostFlightCubit(
      PostFlightRepositoryImpl(widget.database.postFlightDao),
    );
  }

  @override
  void dispose() {
    _objectiveController.dispose();
    _objectiveNotesController.dispose();
    _issuesController.dispose();
    _notesController.dispose();
    _preFieldCubit.close();
    _preFlightCubit.close();
    _postFlightCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _preFieldCubit),
        BlocProvider.value(value: _preFlightCubit),
        BlocProvider.value(value: _postFlightCubit),
      ],
      child: Scaffold(
        appBar: const NavBar(),
        backgroundColor: AppColors.iceBlue,
        body: SafeArea(
          child: BlocConsumer<PreFieldCubit, PreFieldState>(
            listener: _showPreFieldError,
            builder: (context, preFieldState) {
              return BlocConsumer<PreFlightCubit, PreFlightState>(
                listener: _showPreFlightError,
                builder: (context, preFlightState) {
                  return BlocConsumer<PostFlightCubit, PostFlightState>(
                    listener: _showPostFlightError,
                    builder: (context, postFlightState) {
                      final isSaving =
                          _busy ||
                          preFlightState.isSaving ||
                          postFlightState.isSaving;

                      return ListView(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                        children: [
                          _Header(
                            title: 'Session loop',
                            onBack: () => Navigator.of(context).pop(),
                          ),
                          const SizedBox(height: 16),
                          _LoopStepper(step: _step),
                          const SizedBox(height: 16),
                          if (preFieldState.isLoading)
                            const LinearProgressIndicator()
                          else
                            _buildStep(
                              preFieldState: preFieldState,
                              preFlightState: preFlightState,
                              postFlightState: postFlightState,
                              isSaving: isSaving,
                            ),
                        ],
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildStep({
    required PreFieldState preFieldState,
    required PreFlightState preFlightState,
    required PostFlightState postFlightState,
    required bool isSaving,
  }) {
    return switch (_step) {
      _LoopStep.setup => _SetupPanel(
        session: preFieldState.selectedSession,
        vehicles: preFieldState.sessionVehicles,
        users: preFieldState.sessionUsers,
        objectiveController: _objectiveController,
        selectedSessionVehicleId: _sessionVehicleId,
        selectedPicUserId: _picUserId,
        isSaving: isSaving,
        onVehicleChanged: (value) => setState(() => _sessionVehicleId = value),
        onPicChanged: (value) => setState(() => _picUserId = value),
        onCreateSortie: _createSortie,
        onCloseSession: _closeSession,
      ),
      _LoopStep.checklist => _ChecklistPanel(
        sortie: _sortie,
        state: preFlightState,
        isSaving: isSaving,
        onStartFlight: _completePreFlightAndStart,
      ),
      _LoopStep.postFlight => _PostFlightPanel(
        sortie: _sortie,
        state: postFlightState,
        objectiveNotesController: _objectiveNotesController,
        issuesController: _issuesController,
        notesController: _notesController,
        isSaving: isSaving,
        onSaveAndRepeat: () => _savePostFlight(closeSession: false),
        onSaveAndCloseSession: () => _savePostFlight(closeSession: true),
      ),
    };
  }

  Future<void> _createSortie() async {
    final sessionVehicleId = _sessionVehicleId;
    final picUserId = _picUserId;

    if (sessionVehicleId == null || picUserId == null) {
      _showMessage('Select a vehicle and PIC.');
      return;
    }

    await _runBusy(() async {
      final performedBy = await _resolvePerformedBy();
      await _preFlightCubit.createSortie(
        sessionId: widget.sessionId,
        sessionVehicleId: sessionVehicleId,
        picUserId: picUserId,
        objective: _objectiveController.text.trim().isEmpty
            ? null
            : _objectiveController.text.trim(),
        performedBy: performedBy,
      );

      final sortie = _preFlightCubit.state.selectedSortie;
      if (sortie == null) {
        throw Exception('Sortie was not created.');
      }

      _sortie = sortie;
      setState(() => _step = _LoopStep.checklist);
    });
  }

  Future<void> _completePreFlightAndStart() async {
    final sortie = _sortie;
    if (sortie == null) return;

    await _runBusy(() async {
      final performedBy = await _resolvePerformedBy();
      final checklistResponses = [
        for (final item in _preFlightCubit.state.checklistItems)
          ChecklistResponseDraft(
            itemId: item.id,
            response: _defaultChecklistResponse(item.responseType),
          ),
      ];

      if (checklistResponses.isNotEmpty) {
        await _preFlightCubit.saveChecklistResponses(
          flightId: sortie.flightId,
          responses: checklistResponses,
          createdBy: performedBy,
        );
      }

      await _preFlightCubit.submitGoNoGoDecision(
        flightId: sortie.flightId,
        finalDecision: 'GO',
        decisionBy: performedBy,
      );
      await _preFlightCubit.markFlightInProgress(
        flightId: sortie.flightId,
        takeoffAt: DateTime.now(),
        performedBy: performedBy,
      );
      await _preFlightCubit.recordLanding(
        flightId: sortie.flightId,
        landingAt: DateTime.now(),
        performedBy: performedBy,
      );
      await _postFlightCubit.loadSetup(sortie.flightId);
      setState(() => _step = _LoopStep.postFlight);
    });
  }

  Future<void> _savePostFlight({required bool closeSession}) async {
    final sortie = _sortie;
    if (sortie == null) return;

    await _runBusy(() async {
      final performedBy = await _resolvePerformedBy();
      await _postFlightCubit.savePostFlightNote(
        flightId: sortie.flightId,
        objectiveResult: 'COMPLETED',
        objectiveNotes: _emptyToNull(_objectiveNotesController.text),
        issuesEncountered: _emptyToNull(_issuesController.text),
        notes: _emptyToNull(_notesController.text),
        followUpRequired: _issuesController.text.trim().isNotEmpty,
        followUpStatus: _issuesController.text.trim().isEmpty ? null : 'OPEN',
        createdBy: performedBy,
      );

      await _postFlightCubit.closeSortie(
        flightId: sortie.flightId,
        closedBy: performedBy,
      );

      if (closeSession) {
        await _preFieldCubit.closeFieldSession(
          sessionId: widget.sessionId,
          closedBy: performedBy,
        );
        if (!mounted) return;
        Navigator.of(context).pop();
        return;
      }

      _objectiveController.clear();
      _objectiveNotesController.clear();
      _issuesController.clear();
      _notesController.clear();
      _sessionVehicleId = null;
      _picUserId = null;
      _sortie = null;
      await _preFieldCubit.loadSession(widget.sessionId);
      setState(() => _step = _LoopStep.setup);
    });
  }

  Future<void> _closeSession() async {
    await _runBusy(() async {
      final performedBy = await _resolvePerformedBy();
      await _preFieldCubit.closeFieldSession(
        sessionId: widget.sessionId,
        closedBy: performedBy,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    });
  }

  Future<void> _runBusy(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      _showMessage(error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _defaultChecklistResponse(String responseType) {
    return switch (responseType) {
      'CHECKBOX' => 'CHECKED',
      'VALUE' => 'VALUE',
      'TEXT' => 'TEXT',
      _ => 'PASS',
    };
  }

  Future<String> _resolvePerformedBy() async {
    final authState = widget.authCubit.state;
    final uid = authState.uid?.trim();
    if (uid != null && uid.isNotEmpty) {
      final user = await (widget.database.select(
        widget.database.users,
      )..where((row) => row.id.equals(uid))).getSingleOrNull();
      if (user != null) return user.id;
    }

    final email = authState.email?.trim();
    if (email != null && email.isNotEmpty) {
      final user = await (widget.database.select(
        widget.database.users,
      )..where((row) => row.email.equals(email))).getSingleOrNull();
      if (user != null) return user.id;
    }

    final userId = uid != null && uid.isNotEmpty ? uid : _uuid.v4();
    await widget.database
        .into(widget.database.users)
        .insert(
          UsersCompanion.insert(
            id: userId,
            name: 'User',
            role: 'PIC',
            email: email ?? '$userId@local.the-audit',
          ),
          mode: InsertMode.insertOrIgnore,
        );

    return userId;
  }

  void _showPreFieldError(BuildContext context, PreFieldState state) {
    if (state.hasError) _showMessage(state.errorMessage!);
  }

  void _showPreFlightError(BuildContext context, PreFlightState state) {
    if (state.hasError) _showMessage(state.errorMessage!);
  }

  void _showPostFlightError(BuildContext context, PostFlightState state) {
    if (state.hasError) _showMessage(state.errorMessage!);
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String? _emptyToNull(String value) {
    final cleanValue = value.trim();
    return cleanValue.isEmpty ? null : cleanValue;
  }
}

class _Header extends StatelessWidget {
  final String title;
  final VoidCallback onBack;

  const _Header({required this.title, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back),
          color: AppColors.darkNavy,
          tooltip: 'Back',
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: AppColors.darkNavy,
              fontSize: 26,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _LoopStepper extends StatelessWidget {
  final _LoopStep step;

  const _LoopStepper({required this.step});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StepChip(label: 'Pre flight', active: step == _LoopStep.setup),
        const SizedBox(width: 8),
        _StepChip(label: 'Checklist', active: step == _LoopStep.checklist),
        const SizedBox(width: 8),
        _StepChip(label: 'Post flight', active: step == _LoopStep.postFlight),
      ],
    );
  }
}

class _StepChip extends StatelessWidget {
  final String label;
  final bool active;

  const _StepChip({required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: active ? AppColors.deepBlue : AppColors.cardWhite,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.steelBlue.withValues(alpha: 0.2)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: active ? AppColors.snowWhite : AppColors.darkNavy,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

class _SetupPanel extends StatelessWidget {
  final FieldSessionEntity? session;
  final List<SessionVehicleWithVehicleEntity> vehicles;
  final List<SessionUserWithUserEntity> users;
  final TextEditingController objectiveController;
  final String? selectedSessionVehicleId;
  final String? selectedPicUserId;
  final bool isSaving;
  final ValueChanged<String?> onVehicleChanged;
  final ValueChanged<String?> onPicChanged;
  final VoidCallback onCreateSortie;
  final VoidCallback onCloseSession;

  const _SetupPanel({
    required this.session,
    required this.vehicles,
    required this.users,
    required this.objectiveController,
    required this.selectedSessionVehicleId,
    required this.selectedPicUserId,
    required this.isSaving,
    required this.onVehicleChanged,
    required this.onPicChanged,
    required this.onCreateSortie,
    required this.onCloseSession,
  });

  @override
  Widget build(BuildContext context) {
    final picUsers = users.where((item) => item.sessionUser.role == 'PIC');

    return _Panel(
      children: [
        Text(
          session == null
              ? 'Loading session'
              : '${session!.locationName} - ${session!.missionType}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          initialValue: selectedSessionVehicleId,
          decoration: _inputDecoration(
            label: 'Vehicle',
            icon: Icons.flight_takeoff_outlined,
          ),
          items: vehicles
              .map(
                (item) => DropdownMenuItem(
                  value: item.sessionVehicle.id,
                  child: Text(item.vehicle.name),
                ),
              )
              .toList(),
          onChanged: isSaving ? null : onVehicleChanged,
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          initialValue: selectedPicUserId,
          decoration: _inputDecoration(
            label: 'PIC',
            icon: Icons.person_outline,
          ),
          items: picUsers
              .map(
                (item) => DropdownMenuItem(
                  value: item.user.id,
                  child: Text(item.user.name),
                ),
              )
              .toList(),
          onChanged: isSaving ? null : onPicChanged,
        ),
        const SizedBox(height: 14),
        TextField(
          controller: objectiveController,
          minLines: 2,
          maxLines: 4,
          decoration: _inputDecoration(
            label: 'Objective',
            icon: Icons.flag_outlined,
          ),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: isSaving ? null : onCreateSortie,
          icon: const Icon(Icons.play_arrow),
          label: const Text('Start pre-flight checklist'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: isSaving ? null : onCloseSession,
          icon: const Icon(Icons.lock_outline),
          label: const Text('Close session'),
        ),
      ],
    );
  }
}

class _ChecklistPanel extends StatelessWidget {
  final SortieEntity? sortie;
  final PreFlightState state;
  final bool isSaving;
  final VoidCallback onStartFlight;

  const _ChecklistPanel({
    required this.sortie,
    required this.state,
    required this.isSaving,
    required this.onStartFlight,
  });

  @override
  Widget build(BuildContext context) {
    return _Panel(
      children: [
        Text(
          sortie == null ? 'Checklist' : 'Flight ${sortie!.sequenceNo}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        if (state.isLoading)
          const LinearProgressIndicator()
        else if (state.checklistItems.isEmpty)
          const Text('No checklist items found.')
        else
          for (final item in state.checklistItems)
            CheckboxListTile(
              value: true,
              onChanged: null,
              title: Text(item.label),
              subtitle: Text(item.section),
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
            ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: isSaving ? null : onStartFlight,
          icon: const Icon(Icons.flight_land),
          label: const Text('Complete flight'),
        ),
      ],
    );
  }
}

class _PostFlightPanel extends StatelessWidget {
  final SortieEntity? sortie;
  final PostFlightState state;
  final TextEditingController objectiveNotesController;
  final TextEditingController issuesController;
  final TextEditingController notesController;
  final bool isSaving;
  final VoidCallback onSaveAndRepeat;
  final VoidCallback onSaveAndCloseSession;

  const _PostFlightPanel({
    required this.sortie,
    required this.state,
    required this.objectiveNotesController,
    required this.issuesController,
    required this.notesController,
    required this.isSaving,
    required this.onSaveAndRepeat,
    required this.onSaveAndCloseSession,
  });

  @override
  Widget build(BuildContext context) {
    return _Panel(
      children: [
        Text(
          sortie == null
              ? 'Post-flight notes'
              : 'Post-flight ${sortie!.sequenceNo}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: objectiveNotesController,
          minLines: 2,
          maxLines: 4,
          decoration: _inputDecoration(
            label: 'Objective notes',
            icon: Icons.assignment_turned_in_outlined,
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: issuesController,
          minLines: 2,
          maxLines: 4,
          decoration: _inputDecoration(
            label: 'Issues encountered',
            icon: Icons.report_problem_outlined,
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: notesController,
          minLines: 2,
          maxLines: 4,
          decoration: _inputDecoration(
            label: 'Notes',
            icon: Icons.notes_outlined,
          ),
        ),
        if (state.hasBlockingIssues) ...[
          const SizedBox(height: 14),
          for (final issue in state.completionIssues)
            Text(issue, style: const TextStyle(color: AppColors.errorRed)),
        ],
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: isSaving ? null : onSaveAndRepeat,
          icon: const Icon(Icons.replay),
          label: const Text('Save and start next flight'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: isSaving ? null : onSaveAndCloseSession,
          icon: const Icon(Icons.lock_outline),
          label: const Text('Save and close session'),
        ),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  final List<Widget> children;

  const _Panel({required this.children});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.steelBlue.withValues(alpha: 0.18)),
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
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
