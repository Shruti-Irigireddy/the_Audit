import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:the_audit/features/auth/data/user_repository.dart';
import 'package:the_audit/features/auth/data/current_user_repository.dart';
import 'package:the_audit/core/database/app_database.dart';
import 'package:the_audit/core/utils/app_logger.dart';
import 'package:the_audit/core/utils/navbar.dart';
import 'package:the_audit/core/utils/step_indicator.dart';
import 'package:the_audit/core/database/checklists/common_preflight.dart';
import 'package:the_audit/core/utils/theme.dart';
import 'package:the_audit/features/vehicle/domain/entities/checklist_item_entity.dart';
import 'package:the_audit/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:the_audit/features/pre_flight/data/repositories/pre_flight_repository_impl.dart';
import 'package:the_audit/features/pre_flight/domain/entities/checklist_response_entity.dart';
import 'package:the_audit/features/pre_flight/presentation/cubit/pre_flight_cubit.dart';
import 'package:the_audit/features/pre_flight/presentation/cubit/pre_flight_state.dart';

const _log = AppLogger('PreFlight');

/// Each checklist item's answer and arming state, worked out once per build
/// instead of searching every saved answer for every item.
class ChecklistProgress {
  final Map<String, ChecklistResponseEntity> _saved;

  /// Values as currently typed (item id -> text), not saved yet.
  final Map<String, String> _typed;

  ChecklistProgress(
    List<ChecklistResponseWithItemEntity> responses,
    this._typed,
  ) : _saved = {
        for (final saved in responses)
          saved.checklistItem.id: saved.checklistResponse,
      };

  String? response(String itemId) => _saved[itemId]?.response;

  /// An item's value as saved in the database, as text.
  String? savedValue(String itemId) {
    final saved = _saved[itemId];
    if (saved == null) return null;
    if (saved.valueText != null) return saved.valueText;
    final number = saved.valueNumber;
    if (number == null) return null;
    return number == number.roundToDouble()
        ? number.toInt().toString()
        : number.toString();
  }

  /// An item's value (start voltage, sat count / HDOP, RSSI) as text: what's
  /// typed in the field, else the saved value.
  String? value(String itemId) => _typed[itemId] ?? savedValue(itemId);

  bool isAnswered(ChecklistItemEntity item) =>
      response(item.id) != null || (value(item.id) ?? '').isNotEmpty;

  /// A blocking [A] item that hasn't passed yet.
  bool isBlocking(ChecklistItemEntity item) =>
      item.blocksArming &&
      !isCleared(item.responseType, response(item.id), value(item.id));

  /// Whether an answer clears a blocking item (same rule as the database's
  /// ready-to-arm check): Pass, or a value for value items. Fail, N/A or no
  /// answer keeps arming blocked.
  static bool isCleared(String responseType, String? response, String? value) {
    final answer = response?.trim().toUpperCase();
    if (answer == 'FAIL' || answer == 'NO_GO') return false;
    if (answer == 'PASS' || answer == 'GO') return true;
    if (responseType == ChecklistResponseTypes.number) {
      return value != null && double.tryParse(value.trim()) != null;
    }
    if (responseType == ChecklistResponseTypes.value) {
      return value != null && value.trim().isNotEmpty;
    }
    return false;
  }
}

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
  /// Show the detailed completion issues (after Ready to arm is tapped).
  bool _showIssues = false;

  /// Ready to arm succeeded: the Go / No-Go decision is open.
  bool _armed = false;

  /// Values as currently typed (item id -> text), so the arming count follows
  /// the field while typing, before the value is saved.
  final Map<String, String> _typedValues = {};

  /// Checklist groups / sections currently open. The first checklist
  /// (Common pre-flight) and its first section start open; the rest start
  /// collapsed.
  Set<String> _openSections = {
    'common',
    'common/${commonPreflightChecklist.first.section}',
  };

  /// Sections of the SRS §5.1 common checklist; anything else is the
  /// vehicle type's own checklist.
  static final _commonSections = {
    for (final item in commonPreflightChecklist) item.section,
  };

  void _toggle(String key) => setState(() {
    _openSections = _openSections.contains(key)
        ? ({..._openSections}..remove(key))
        : {..._openSections, key};
  });

  /// One card: "Common pre-flight" and the vehicle's checklist, each
  /// collapsible, with their sections collapsible inside.
  Widget _buildChecklistCard(
    PreFlightState state,
    ChecklistProgress progress,
  ) {
    final items = state.checklistItems;
    final common = [
      for (final item in items)
        if (_commonSections.contains(item.section)) item,
    ];
    final gate = [
      for (final item in items)
        if (item.section == readyToArmSection) item,
    ];
    final vehicle = [
      for (final item in items)
        if (!_commonSections.contains(item.section) &&
            item.section != readyToArmSection)
          item,
    ];
    // The gate is the final step: it opens once everything above passed.
    final gateOpen = [
      ...common,
      ...vehicle,
    ].every((item) => !progress.isBlocking(item));
    final vehicleTitle = vehicle.isEmpty
        ? 'Vehicle checklist'
        : 'Vehicle checklist · ${vehicle.first.section}';

    Widget group(
      String key,
      String title,
      List<ChecklistItemEntity> groupItems, {
      bool locked = false,
    }) {
      final sections = _sections(groupItems);
      return _ChecklistSection(
        title: title,
        answered: groupItems.where((i) => progress.isAnswered(i)).length,
        total: groupItems.length,
        stillBlocking: groupItems.where((i) => progress.isBlocking(i)).length,
        expanded: _openSections.contains(key),
        onToggle: () => _toggle(key),
        children: [
          if (locked)
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text(
                'Pass every blocking check above first.',
                style: AppTextStyles.secondary,
              ),
            ),
          // A single-section group (e.g. the vehicle type) shows its items
          // directly; otherwise each section collapses on its own.
          if (!locked && sections.length == 1)
            for (final item in groupItems) _itemTile(progress, item)
          else if (!locked)
            for (final (section, sectionItems) in sections)
              _ChecklistSection(
                title: section,
                answered: sectionItems
                    .where((i) => progress.isAnswered(i))
                    .length,
                total: sectionItems.length,
                stillBlocking: sectionItems
                    .where((i) => progress.isBlocking(i))
                    .length,
                expanded: _openSections.contains('$key/$section'),
                onToggle: () => _toggle('$key/$section'),
                children: [
                  for (final item in sectionItems) _itemTile(progress, item),
                ],
              ),
        ],
      );
    }

    return DecoratedBox(
      decoration: AppDecorations.panel,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (common.isNotEmpty) group('common', 'Common pre-flight', common),
            if (vehicle.isNotEmpty) group('vehicle', vehicleTitle, vehicle),
            if (gate.isNotEmpty)
              group('gate', 'Ready-to-Arm gate', gate, locked: !gateOpen),
          ],
        ),
      ),
    );
  }

  /// Item tiles by item id, reused while nothing they show has changed so
  /// Flutter skips rebuilding them when another item is answered.
  final Map<String, _ChecklistItemTile> _tiles = {};

  Widget _itemTile(ChecklistProgress progress, ChecklistItemEntity item) {
    final response = progress.response(item.id);
    // The saved value: the field compares against it to know what's new.
    final value = progress.savedValue(item.id);
    final cleared = !progress.isBlocking(item) && item.blocksArming;

    final cached = _tiles[item.id];
    if (cached != null &&
        cached.label == item.label &&
        cached.responseType == item.responseType &&
        cached.blocksArming == item.blocksArming &&
        cached.response == response &&
        cached.value == value &&
        cached.cleared == cleared) {
      return cached;
    }
    return _tiles[item.id] = _ChecklistItemTile(
      key: ValueKey('item-${item.id}'),
      label: item.label,
      // The section is the card's title already.
      section: '',
      responseType: item.responseType,
      blocksArming: item.blocksArming,
      response: response,
      value: value,
      cleared: cleared,
      onResponse: (response, value) =>
          _saveResponse(item.id, response, value: value),
      onValueChanged: (text) => _onValueTyped(item, text),
    );
  }

  /// Keeps what's typed so the counts follow the field; redraws only when
  /// the item's answered / passed state flips, not on every keystroke.
  void _onValueTyped(ChecklistItemEntity item, String text) {
    ChecklistProgress now() =>
        ChecklistProgress(_cubit.state.checklistResponses, _typedValues);
    final before = now();
    final wasAnswered = before.isAnswered(item);
    final wasBlocking = before.isBlocking(item);
    _typedValues[item.id] = text;
    final after = now();
    if (after.isAnswered(item) != wasAnswered ||
        after.isBlocking(item) != wasBlocking) {
      setState(() {});
    }
  }

  /// Items grouped by section, in checklist order.
  static List<(String, List<ChecklistItemEntity>)> _sections(
    List<ChecklistItemEntity> items,
  ) {
    final groups = <(String, List<ChecklistItemEntity>)>[];
    for (final item in items) {
      if (groups.isEmpty || groups.last.$1 != item.section) {
        groups.add((item.section, []));
      }
      groups.last.$2.add(item);
    }
    return groups;
  }

  late final PreFlightCubit _cubit;
  final _decisionReasonController = TextEditingController();
  String _finalDecision = 'GO';
  String? _decisionByUserId;

  /// Every user's name by id, for showing the PIC.
  Map<String, String> _userNames = {};

  @override
  void initState() {
    super.initState();
    _log.t('initState flight ${widget.flightId}');
    _cubit = PreFlightCubit(
      PreFlightRepositoryImpl(widget.database.preFlightDao),
    )..loadSetup(widget.flightId);
    _loadUserNames();
  }

  Future<void> _loadUserNames() async {
    final names = await UserRepository(widget.database).getUserNames();
    if (!mounted) return;
    setState(() => _userNames = names);
  }

  @override
  void dispose() {
    _log.t('dispose');
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
          final goSaved = state.selectedSortie?.finalDecision == 'GO';
          // Every item's answer and arming state, looked up once.
          final progress = ChecklistProgress(
            state.checklistResponses,
            _typedValues,
          );

          return Scaffold(
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
                        child: Text(
                          'Pre-flight checklist',
                          style: AppTextStyles.pageTitle,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Flight flow: 1 prepare sortie, 2 pre-flight, 3 post-flight.
                  // Step 1 goes back to the session loop.
                  StepIndicator(
                    current: 1,
                    count: 3,
                    onStepTap: (index) {
                      if (index == 0) Navigator.of(context).pop();
                    },
                  ),
                  const SizedBox(height: 16),
                  // Only while the checklist first opens: answering an item
                  // updates in place, so nothing here may change size then.
                  if (state.isLoading && state.checklistItems.isEmpty)
                    const LinearProgressIndicator(),
                  _ArmingStatusBar(
                    blocking: state.checklistItems
                        .where((item) => item.blocksArming)
                        .length,
                    stillBlocked: state.checklistItems
                        .where(progress.isBlocking)
                        .length,
                  ),
                  const SizedBox(height: 12),
                  _buildChecklistCard(state, progress),
                  const SizedBox(height: 16),
                  // Enabled only when every blocking item (gate included) has
                  // passed; then it runs the final check and opens Go/No-Go.
                  // Gone once Go is saved.
                  if (!goSaved) ...[
                    FilledButton.icon(
                      onPressed:
                          state.isSaving ||
                              state.checklistItems.any(progress.isBlocking)
                          ? null
                          : _readyToArm,
                      icon: const Icon(Icons.verified_user_outlined),
                      label: const Text('READY TO ARM'),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (_armed || state.selectedSortie?.finalDecision != null)
                    _DecisionCard(
                      state: state,
                      finalDecision: _finalDecision,
                      decisionByUserId: _decisionByUserId,
                      userNames: _userNames,
                      reasonController: _decisionReasonController,
                      onDecisionChanged: (value) {
                        if (value == null) return;
                        _log.d('decision selected: $value');
                        setState(() => _finalDecision = value);
                      },
                      onDecisionByChanged: (value) {
                        _log.d('decision by selected: $value');
                        setState(() => _decisionByUserId = value);
                      },
                      onSubmit: _submitDecision,
                    ),
                  // Detailed issues only after "Validate ready to arm"; the
                  // status bar above already shows what still blocks.
                  if (_showIssues)
                    for (final issue in state.completionIssues)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(issue, style: AppTextStyles.error),
                      ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _saveResponse(
    String itemId,
    String response, {
    String? value,
  }) async {
    _log.d('response $itemId: $response${value == null ? '' : ' (value)'}');
    final performedBy = await _performedBy();
    final text = value?.trim();
    await _cubit.saveChecklistResponse(
      flightId: widget.flightId,
      itemId: itemId,
      response: response,
      valueText: text == null || text.isEmpty ? null : text,
      valueNumber: text == null ? null : double.tryParse(text),
      createdBy: performedBy,
    );
    // The cubit re-checks ready-to-arm as part of the same save.
  }

  Future<void> _readyToArm() async {
    _log.i('ready to arm tapped');
    setState(() => _showIssues = true);
    await _cubit.validateReadyToArm(widget.flightId);
    if (!mounted) return;
    final validation = _cubit.state.readyToArmValidation;
    if (validation?.canProceed == true) {
      setState(() => _armed = true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Not ready to arm yet: see the items listed below.'),
        ),
      );
    }
  }

  Future<void> _submitDecision() => _log.trace('submitDecision', () async {
    _log.i(
      'save decision tapped: $_finalDecision '
      '(hasReason: ${_decisionReasonController.text.trim().isNotEmpty})',
    );
    if (_cubit.state.readyToArmValidation == null) {
      _log.w('decision blocked: not ready to arm');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Tap READY TO ARM first.')));
      return;
    }
    final isNoGo = _finalDecision == 'NO_GO';
    final reason = _nullable(_decisionReasonController.text);
    if (isNoGo && reason == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the reason for No-Go.')),
      );
      return;
    }

    // Made by the sortie's PIC unless another PIC was picked.
    final decisionBy =
        _decisionByUserId ??
        _cubit.state.selectedSortie?.picUserId ??
        await _performedBy();
    await _cubit.submitGoNoGoDecision(
      flightId: widget.flightId,
      finalDecision: _finalDecision,
      // Go needs no reason.
      decisionReason: isNoGo ? reason : null,
      decisionBy: decisionBy,
    );
    if (!mounted || _cubit.state.hasError) return;

    // Back to the session: No-Go aborts the sortie, Go makes it Ready for
    // post-flight (both saved by the database).
    final status = _cubit.state.selectedSortie?.flightStatus;
    if (status == 'ABORTED' || status == 'READY') {
      _log.i('decision saved ($status); back to session');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isNoGo ? 'No-Go saved: sortie aborted.' : 'Go saved: sortie ready.',
          ),
        ),
      );
      Navigator.of(context).pop();
    }
  });

  String? _nullable(String value) {
    final clean = value.trim();
    return clean.isEmpty ? null : clean;
  }

  /// The signed-in user, as a row in the local users table.
  Future<String> _performedBy() => CurrentUserRepository(
    widget.database,
  ).resolvePerformedBy(widget.authCubit.state);
}

/// Final Go / No-Go, opened by READY TO ARM: the decision, who gave it,
/// and a reason (only for No-Go).
class _DecisionCard extends StatelessWidget {
  final PreFlightState state;
  final String finalDecision;
  final String? decisionByUserId;

  /// Every user's name by id: the PIC is kept on the sortie, not in its crew.
  final Map<String, String> userNames;
  final TextEditingController reasonController;
  final ValueChanged<String?> onDecisionChanged;
  final ValueChanged<String?> onDecisionByChanged;
  final VoidCallback onSubmit;

  const _DecisionCard({
    required this.state,
    required this.finalDecision,
    required this.decisionByUserId,
    required this.userNames,
    required this.reasonController,
    required this.onDecisionChanged,
    required this.onDecisionByChanged,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final isNoGo = finalDecision == 'NO_GO';
    final sortie = state.selectedSortie;
    // Once a Go is saved the decision is shown, not edited.
    final locked = sortie?.finalDecision == 'GO';
    // The decision is made by the sortie's PIC (the sortie's own PIC first,
    // then any other crew listed as PIC).
    final crewNames = {
      for (final item in state.users) item.user.id: item.user.name,
    };
    String nameOf(String id) => userNames[id] ?? crewNames[id] ?? id;
    final people = {
      if (sortie != null && sortie.picUserId.isNotEmpty)
        sortie.picUserId: nameOf(sortie.picUserId),
      for (final item in state.users)
        if (item.sortieUser.role == 'PIC') item.user.id: nameOf(item.user.id),
    };
    final selectedId = locked
        ? sortie?.decisionBy
        : decisionByUserId ?? sortie?.picUserId;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Final Go / No-Go', style: AppTextStyles.cardTitle),
            if (state.selectedSortie?.decisionAt != null) ...[
              const SizedBox(height: 6),
              Text(
                'Decision at ${_formatDateTime(state.selectedSortie!.decisionAt!)}',
                style: AppTextStyles.secondary,
              ),
            ],
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'GO',
                  icon: Icon(Icons.flight_takeoff),
                  label: Text('Go'),
                ),
                ButtonSegment(
                  value: 'NO_GO',
                  icon: Icon(Icons.block),
                  label: Text('No-Go'),
                ),
              ],
              selected: {locked ? 'GO' : finalDecision},
              showSelectedIcon: false,
              onSelectionChanged: locked
                  ? null
                  : (values) => onDecisionChanged(values.first),
            ),
            const SizedBox(height: 12),
            // One PIC (or a saved decision): just the name. Several PICs:
            // pick who made the decision.
            if (locked || people.length <= 1)
              InputDecorator(
                decoration: AppDecorations.field(
                  label: 'Decision by (PIC)',
                  icon: Icons.person_outline,
                ),
                child: Text(
                  selectedId == null ? '–' : nameOf(selectedId),
                  style: AppTextStyles.bodyStrong,
                ),
              )
            else
              DropdownButtonFormField<String>(
                initialValue: people.containsKey(selectedId)
                    ? selectedId
                    : null,
                decoration: AppDecorations.field(
                  label: 'Decision by (PIC)',
                  icon: Icons.person_outline,
                ),
                items: [
                  for (final entry in people.entries)
                    DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                ],
                onChanged: onDecisionByChanged,
              ),
            // A reason is only needed when the flight is called off.
            if (isNoGo && !locked) ...[
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                textCapitalization: TextCapitalization.sentences,
                decoration: AppDecorations.field(
                  label: 'Reason for No-Go',
                  icon: Icons.notes_outlined,
                ),
                minLines: 2,
                maxLines: 4,
              ),
            ],
            if (!locked) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: onSubmit,
                icon: const Icon(Icons.how_to_reg_outlined),
                label: Text(isNoGo ? 'Save No-Go' : 'Save Go'),
              ),
            ],
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

/// A collapsible checklist section: title, "answered / total", and a red
/// lock while any of its blocking items hasn't passed.
class _ChecklistSection extends StatelessWidget {
  final String title;
  final int answered;
  final int total;
  final int stillBlocking;
  final bool expanded;
  final VoidCallback onToggle;
  final List<Widget> children;

  const _ChecklistSection({
    required this.title,
    required this.answered,
    required this.total,
    required this.stillBlocking,
    required this.expanded,
    required this.onToggle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final done = answered == total && stillBlocking == 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
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
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: AppTextStyles.sectionHeader),
                          Text(
                            '$answered / $total answered',
                            style: AppTextStyles.caption,
                          ),
                        ],
                      ),
                    ),
                    if (stillBlocking > 0)
                      Tooltip(
                        message: '$stillBlocking item(s) still block arming',
                        child: const Icon(
                          Icons.lock_outline,
                          size: 18,
                          color: AppColors.errorRed,
                        ),
                      )
                    else if (done)
                      const Icon(
                        Icons.check_circle,
                        size: 18,
                        color: AppColors.successGreen,
                      ),
                    const SizedBox(width: 6),
                    Icon(expanded ? Icons.expand_less : Icons.expand_more),
                  ],
                ),
              ),
            ),
            if (expanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: Column(children: children),
              ),
          ],
        ),
      ),
    );
  }
}

/// Live arming status: red while any blocking item hasn't passed, green
/// once all of them have.
class _ArmingStatusBar extends StatelessWidget {
  final int blocking;
  final int stillBlocked;

  const _ArmingStatusBar({required this.blocking, required this.stillBlocked});

  @override
  Widget build(BuildContext context) {
    if (blocking == 0) return const SizedBox.shrink();
    final released = stillBlocked == 0;
    final color = released ? AppColors.successGreen : AppColors.errorRed;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: const BorderRadius.all(
          Radius.circular(AppSizes.panelRadius),
        ),
        border: Border.all(color: color),
      ),
      child: Row(
        children: [
          Icon(
            released ? Icons.lock_open_outlined : Icons.lock_outline,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              released
                  ? 'All blocking items passed: ready to arm'
                  : 'Arming blocked: $stillBlocked of $blocking items still '
                        'to pass',
              style: (released ? AppTextStyles.success : AppTextStyles.error)
                  .copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// One checklist item. Its controls follow the item's response type:
/// Pass / Fail, Pass / N/A, Pass only, a value, or Pass / Fail plus a value
/// (RSSI). Items that block arming are marked.
class _ChecklistItemTile extends StatefulWidget {
  final String label;
  final String section;
  final String responseType;
  final bool blocksArming;
  final String? response;
  final String? value;

  /// Whether this item's answer currently clears it for arming.
  final bool cleared;
  final void Function(String response, String? value) onResponse;

  /// Every keystroke in the value field, so the arming count can follow it.
  final ValueChanged<String> onValueChanged;

  const _ChecklistItemTile({
    super.key,
    required this.label,
    required this.section,
    required this.responseType,
    required this.blocksArming,
    required this.response,
    required this.value,
    required this.cleared,
    required this.onResponse,
    required this.onValueChanged,
  });

  @override
  State<_ChecklistItemTile> createState() => _ChecklistItemTileState();
}

class _ChecklistItemTileState extends State<_ChecklistItemTile> {
  late final _valueController = TextEditingController(text: widget.value ?? '');
  final _valueFocus = FocusNode();

  static const _pass = ButtonSegment(
    value: 'PASS',
    icon: Icon(Icons.check_circle_outline),
    label: Text('Pass'),
  );
  static const _fail = ButtonSegment(
    value: 'FAIL',
    icon: Icon(Icons.cancel_outlined),
    label: Text('Fail'),
  );
  static const _na = ButtonSegment(
    value: 'NA',
    icon: Icon(Icons.remove_circle_outline),
    label: Text('N/A'),
  );

  /// Saves a typed value once typing pauses, so it saves without leaving the
  /// field.
  static const _saveDelay = Duration(milliseconds: 500);
  Timer? _saveTimer;

  @override
  void initState() {
    super.initState();
    // Also save straight away when the field loses focus.
    _valueFocus.addListener(() {
      if (!_valueFocus.hasFocus) _saveValue();
    });
  }

  @override
  void didUpdateWidget(covariant _ChecklistItemTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      // A save landed (or was undone): the same text may be sent again.
      _lastSentValue = null;
      // Never replace what's being typed.
      if (!_valueFocus.hasFocus) _valueController.text = widget.value ?? '';
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _valueController.dispose();
    _valueFocus.dispose();
    super.dispose();
  }

  bool get _isNumber => widget.responseType == ChecklistResponseTypes.number;
  bool get _isValueOnly =>
      _isNumber || widget.responseType == ChecklistResponseTypes.value;
  bool get _hasValue =>
      _isValueOnly ||
      widget.responseType == ChecklistResponseTypes.passFailValue;

  List<ButtonSegment<String>> get _segments => switch (widget.responseType) {
    ChecklistResponseTypes.passFail ||
    ChecklistResponseTypes.passFailValue => const [_pass, _fail],
    ChecklistResponseTypes.passNa => const [_pass, _na],
    ChecklistResponseTypes.passOnly => const [_pass],
    ChecklistResponseTypes.value || ChecklistResponseTypes.number => const [],
    _ => const [_pass, _fail, _na],
  };

  /// The last value sent, so "Done" followed by leaving the field doesn't
  /// save the same value twice.
  String? _lastSentValue;

  void _onValueChanged(String text) {
    widget.onValueChanged(text);
    _saveTimer?.cancel();
    _saveTimer = Timer(_saveDelay, _saveValue);
  }

  void _saveValue() {
    _saveTimer?.cancel();
    final text = _valueController.text.trim();
    if (text == (widget.value ?? '').trim() || text == _lastSentValue) return;
    _lastSentValue = text;
    if (_isValueOnly) {
      // An emptied field is saved too, so the item blocks arming again.
      widget.onResponse('VALUE', text);
    } else if (widget.response != null) {
      // Pass / Fail + value: keep the chosen result, update the value.
      widget.onResponse(widget.response!, text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final segments = _segments;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(widget.section, style: AppTextStyles.label),
                ),
                if (widget.blocksArming)
                  Tooltip(
                    message: widget.cleared
                        ? 'Passed: no longer blocks arming'
                        : 'Blocks arming until it passes',
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          widget.cleared
                              ? Icons.lock_open_outlined
                              : Icons.lock_outline,
                          size: 16,
                          color: widget.cleared
                              ? AppColors.successGreen
                              : AppColors.errorRed,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          widget.cleared ? 'Released' : 'Blocks arming',
                          style: widget.cleared
                              ? AppTextStyles.success
                              : AppTextStyles.error,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(widget.label, style: AppTextStyles.bodyStrong),
            const SizedBox(height: 10),
            if (segments.isNotEmpty)
              SegmentedButton<String>(
                segments: segments,
                // Keep the ✓ / ✗ / – symbols on the chosen answer.
                showSelectedIcon: false,
                selected: {
                  if (widget.response != null &&
                      segments.any((s) => s.value == widget.response))
                    widget.response!,
                },
                emptySelectionAllowed: true,
                onSelectionChanged: (values) {
                  if (values.isEmpty) return;
                  final text = _valueController.text.trim();
                  widget.onResponse(
                    values.first,
                    _hasValue && text.isNotEmpty ? text : null,
                  );
                },
              ),
            if (_hasValue) ...[
              if (segments.isNotEmpty) const SizedBox(height: 10),
              TextField(
                controller: _valueController,
                focusNode: _valueFocus,
                textInputAction: TextInputAction.done,
                onChanged: _onValueChanged,
                onSubmitted: (_) => _saveValue(),
                // Number items: digits and one decimal point only.
                keyboardType: _isNumber
                    ? const TextInputType.numberWithOptions(decimal: true)
                    : TextInputType.text,
                inputFormatters: _isNumber
                    ? [
                        // Ignore a keystroke that would make it not a number
                        // (letters, a second dot) instead of clearing it.
                        TextInputFormatter.withFunction(
                          (oldValue, newValue) =>
                              RegExp(r'^\d*\.?\d*$').hasMatch(newValue.text)
                              ? newValue
                              : oldValue,
                        ),
                      ]
                    : null,
                decoration: AppDecorations.field(
                  label: _isNumber
                      ? 'Value (number, e.g. 25.2)'
                      : _isValueOnly
                      ? 'Value'
                      : 'RSSI (optional)',
                  icon: _isNumber
                      ? Icons.pin_outlined
                      : Icons.edit_note_outlined,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
