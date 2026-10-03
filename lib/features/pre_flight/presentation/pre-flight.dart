import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:the_audit/core/database/app_database.dart';
import 'package:the_audit/core/utils/navbar.dart';
import 'package:the_audit/core/utils/theme.dart';
import 'package:the_audit/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:the_audit/features/pre_flight/data/repositories/pre_flight_repository_impl.dart';
import 'package:the_audit/features/pre_flight/presentation/cubit/pre_flight_cubit.dart';
import 'package:the_audit/features/pre_flight/presentation/cubit/pre_flight_state.dart';

class PreFlightChecklistPage extends StatefulWidget {
  final AppDatabase database;
  final AuthCubit authCubit;
  final String flightId;

  const PreFlightChecklistPage({
    super.key,
    required this.database,
    required this.authCubit,
    required this.flightId,
  });

  @override
  State<PreFlightChecklistPage> createState() => _PreFlightChecklistPageState();
}

class _PreFlightChecklistPageState extends State<PreFlightChecklistPage> {
  late final PreFlightCubit _cubit;
  final _decisionReasonController = TextEditingController();
  String _finalDecision = 'GO';
  String? _decisionByUserId;

  @override
  void initState() {
    super.initState();
    _cubit = PreFlightCubit(
      PreFlightRepositoryImpl(widget.database.preFlightDao),
    )..loadSetup(widget.flightId);
  }

  @override
  void dispose() {
    _cubit.close();
    _decisionReasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: BlocConsumer<PreFlightCubit, PreFlightState>(
        listener: (context, state) {
          if (!state.hasError) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.errorMessage!)));
        },
        builder: (context, state) {
          final canStartFlight =
              state.readyToArmValidation?.canProceed == true &&
              state.selectedSortie?.finalDecision == 'GO';

          return Scaffold(
            appBar: const NavBar(),
            body: SafeArea(
              child: ListView(
                padding: AppSizes.pageInsets,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back),
                        tooltip: 'Back',
                      ),
                      const Expanded(
                        child: Text(
                          'Pre-flight checklist',
                          style: AppTextStyles.pageTitle,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (state.isLoading) const LinearProgressIndicator(),
                  for (final item in state.checklistItems)
                    _ChecklistItemTile(
                      label: item.label,
                      section: item.section,
                      response: _responseForItem(state, item.id),
                      onResponse: (response) =>
                          _saveResponse(item.id, response),
                    ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: state.isSaving ? null : _validate,
                    icon: const Icon(Icons.fact_check_outlined),
                    label: const Text('Validate ready to arm'),
                  ),
                  const SizedBox(height: 10),
                  _DecisionCard(
                    state: state,
                    finalDecision: _finalDecision,
                    decisionByUserId: _decisionByUserId,
                    reasonController: _decisionReasonController,
                    onDecisionChanged: (value) {
                      if (value == null) return;
                      setState(() => _finalDecision = value);
                    },
                    onDecisionByChanged: (value) {
                      setState(() => _decisionByUserId = value);
                    },
                    onSubmit: _submitDecision,
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: state.isSaving
                        ? null
                        : () => _markTakeoff(canStartFlight: canStartFlight),
                    icon: const Icon(Icons.flight_takeoff),
                    label: const Text('Start flight'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: state.isSaving ? null : _recordLanding,
                    icon: const Icon(Icons.flight_land),
                    label: const Text('Record landing'),
                  ),
                  for (final issue in state.completionIssues)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        issue,
                        style: AppTextStyles.error,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String? _responseForItem(PreFlightState state, String itemId) {
    for (final response in state.checklistResponses) {
      if (response.checklistItem.id == itemId) {
        return response.checklistResponse.response;
      }
    }
    return null;
  }

  Future<void> _saveResponse(String itemId, String response) async {
    final performedBy = await _performedBy();
    return _cubit.saveChecklistResponse(
      flightId: widget.flightId,
      itemId: itemId,
      response: response,
      createdBy: performedBy,
    );
  }

  Future<void> _validate() {
    return _cubit.validateReadyToArm(widget.flightId);
  }

  Future<void> _markTakeoff({required bool canStartFlight}) async {
    if (!canStartFlight) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Validate ready to arm and save a GO decision first.'),
        ),
      );
      return;
    }

    final performedBy = await _performedBy();
    final takeoffAt = await _pickDateTime(title: 'Takeoff time');
    if (takeoffAt == null) return;

    return _cubit.markFlightInProgress(
      flightId: widget.flightId,
      takeoffAt: takeoffAt,
      performedBy: performedBy,
    );
  }

  Future<void> _recordLanding() async {
    final performedBy = await _performedBy();
    final landingAt = await _pickDateTime(title: 'Landing time');
    if (landingAt == null) return;

    return _cubit.recordLanding(
      flightId: widget.flightId,
      landingAt: landingAt,
      performedBy: performedBy,
    );
  }

  Future<void> _submitDecision() async {
    if (_cubit.state.readyToArmValidation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Run ready-to-arm validation before final decision.'),
        ),
      );
      return;
    }

    final decisionBy = _decisionByUserId ?? await _performedBy();
    return _cubit.submitGoNoGoDecision(
      flightId: widget.flightId,
      finalDecision: _finalDecision,
      decisionReason: _nullable(_decisionReasonController.text),
      decisionBy: decisionBy,
    );
  }

  Future<DateTime?> _pickDateTime({required String title}) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: title,
    );
    if (date == null || !mounted) return null;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      helpText: title,
    );
    if (time == null) return null;

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
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

    return uid ?? email ?? 'unknown';
  }
}

class _DecisionCard extends StatelessWidget {
  final PreFlightState state;
  final String finalDecision;
  final String? decisionByUserId;
  final TextEditingController reasonController;
  final ValueChanged<String?> onDecisionChanged;
  final ValueChanged<String?> onDecisionByChanged;
  final VoidCallback onSubmit;

  const _DecisionCard({
    required this.state,
    required this.finalDecision,
    required this.decisionByUserId,
    required this.reasonController,
    required this.onDecisionChanged,
    required this.onDecisionByChanged,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Final decision',
              style: AppTextStyles.cardTitle,
            ),
            if (state.selectedSortie?.decisionAt != null) ...[
              const SizedBox(height: 6),
              Text(
                'Decision at ${_formatDateTime(state.selectedSortie!.decisionAt!)}',
                style: AppTextStyles.secondary,
              ),
            ],
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: finalDecision,
              decoration: const InputDecoration(labelText: 'Decision'),
              items: const [
                DropdownMenuItem(value: 'GO', child: Text('Go')),
                DropdownMenuItem(value: 'NO_GO', child: Text('No-go')),
              ],
              onChanged: onDecisionChanged,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(labelText: 'Reason'),
              minLines: 2,
              maxLines: 4,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: decisionByUserId,
              decoration: const InputDecoration(labelText: 'Decision by'),
              items: [
                for (final item in state.users)
                  DropdownMenuItem(
                    value: item.user.id,
                    child: Text(item.user.name),
                  ),
              ],
              onChanged: onDecisionByChanged,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onSubmit,
              icon: const Icon(Icons.how_to_reg_outlined),
              label: const Text('Save decision'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '${value.day}/${value.month}/${value.year} $hour:$minute';
  }
}

class _ChecklistItemTile extends StatelessWidget {
  final String label;
  final String section;
  final String? response;
  final ValueChanged<String> onResponse;

  const _ChecklistItemTile({
    required this.label,
    required this.section,
    required this.response,
    required this.onResponse,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              section,
              style: AppTextStyles.label,
            ),
            const SizedBox(height: 4),
            Text(label, style: AppTextStyles.bodyStrong),
            const SizedBox(height: 10),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'PASS', label: Text('Pass')),
                ButtonSegment(value: 'FAIL', label: Text('Fail')),
                ButtonSegment(value: 'NA', label: Text('N/A')),
              ],
              selected: {if (response != null) response!},
              emptySelectionAllowed: true,
              onSelectionChanged: (values) {
                if (values.isEmpty) return;
                onResponse(values.first);
              },
            ),
          ],
        ),
      ),
    );
  }
}
