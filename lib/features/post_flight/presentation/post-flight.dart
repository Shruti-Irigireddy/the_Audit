import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:the_audit/core/database/database_constants.dart';
import 'package:the_audit/core/database/app_database.dart';
import 'package:the_audit/core/utils/app_logger.dart';
import 'package:the_audit/core/utils/navbar.dart';
import 'package:the_audit/core/utils/theme.dart';
import 'package:the_audit/features/auth/data/current_user_repository.dart';
import 'package:the_audit/features/auth/data/user_repository.dart';
import 'package:the_audit/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:the_audit/features/post_flight/data/repositories/post_flight_repository_impl.dart';
import 'package:the_audit/features/post_flight/domain/entities/post_flight_note_entity.dart';
import 'package:the_audit/features/post_flight/presentation/cubit/post_flight_cubit.dart';
import 'package:the_audit/features/post_flight/presentation/cubit/post_flight_state.dart';
import 'package:the_audit/features/pre_flight/data/repositories/pre_flight_repository_impl.dart';

const _log = AppLogger('PostFlight');

/// Post-flight notes for one sortie (SRS FR-POST-01..08). Saving closes the
/// sortie (not the session); a closed sortie can still be edited, and each
/// edit is logged as an amendment.
class PostFlightNotesPage extends StatefulWidget {
  final AppDatabase database;
  final AuthCubit authCubit;
  final String flightId;

  const PostFlightNotesPage({
    super.key,
    required this.database,
    required this.authCubit,
    required this.flightId,
  });

  @override
  State<PostFlightNotesPage> createState() => _PostFlightNotesPageState();
}

class _PostFlightNotesPageState extends State<PostFlightNotesPage> {
  late final PostFlightCubit _cubit;

  final _objectiveNotes = TextEditingController();
  final _batteryVoltage = TextEditingController();
  final _batteryPercent = TextEditingController();
  final _durationMinutes = TextEditingController();
  final _issues = TextEditingController();
  final _damage = TextEditingController();
  final _logLocation = TextEditingController();
  final _logNotes = TextEditingController();
  final _followUpNotes = TextEditingController();
  final _notes = TextEditingController();

  String _objectiveResult = 'YES';
  int _stars = 0;

  /// Structural damage? null until answered (required).
  bool? _hasDamage;
  String? _logStoredAt;

  /// Null until the user flips the switch: follow-up is then flagged
  /// automatically (FR-POST-06).
  bool? _followUpChoice;
  String? _followUpAssignedTo;
  String _followUpStatus = 'PENDING';

  /// The sortie's PIC and VOs, who a follow-up can be assigned to.
  Map<String, String> _people = {};

  /// Fields filled from the saved note once, on first load.
  bool _prefilled = false;

  /// Open sections: Objective and Follow-up start open (still collapsible),
  /// the rest collapsed.
  Set<String> _open = {'objective', 'followUp'};

  static const _structuralDamagePrefix = 'Structural damage: ';

  @override
  void initState() {
    super.initState();
    _log.t('initState flight ${widget.flightId}');
    _cubit = PostFlightCubit(
      PostFlightRepositoryImpl(widget.database.postFlightDao),
    )..loadSetup(widget.flightId);
    _loadPeople();
    // Typing an incident can flag follow-up and fill a section's tick.
    for (final controller in [_objectiveNotes, _issues, _damage, _notes]) {
      controller.addListener(_refresh);
    }
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _log.t('dispose');
    _cubit.close();
    for (final controller in [
      _objectiveNotes,
      _batteryVoltage,
      _batteryPercent,
      _durationMinutes,
      _issues,
      _damage,
      _logLocation,
      _logNotes,
      _followUpNotes,
      _notes,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  bool get _hasIncident => _hasDamage == true;

  /// Flagged automatically when the objective wasn't met or an incident was
  /// written, unless the user chose otherwise.
  bool get _followUpRequired =>
      _followUpChoice ?? (_objectiveResult != 'YES' || _hasIncident);

  /// Required battery & duration fields still empty.
  List<String> get _missingBattery => [
    if (_batteryVoltage.text.trim().isEmpty) 'voltage',
    if (_batteryPercent.text.trim().isEmpty) '%',
    if (_durationMinutes.text.trim().isEmpty) 'duration',
  ];

  /// Required mission fields still empty.
  List<String> get _missingRating => [
    if (_stars == 0) 'rating',
    if (_issues.text.trim().isEmpty) 'anomalies',
    if (_hasDamage == null) 'structural damage',
    if (_hasDamage == true && _damage.text.trim().isEmpty) 'what was damaged',
  ];

  bool get _needsObjectiveNotes => _objectiveResult != 'YES';

  void _toggle(String key) => setState(() {
    _open = _open.contains(key)
        ? ({..._open}..remove(key))
        : {..._open, key};
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: BlocConsumer<PostFlightCubit, PostFlightState>(
        listener: (context, state) {
          final note = state.note;
          if (!_prefilled && note != null) _prefill(note);
          if (state.hasError) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.errorMessage!)));
          }
        },
        builder: (context, state) {
          final closed = state.setup?.sortie.flightStatus == FlightStatus.closed;
          return Scaffold(
            appBar: const NavBar(),
            body: SafeArea(
              child: GestureDetector(
                // Tapping outside a field closes the keyboard.
                onTap: () => FocusScope.of(context).unfocus(),
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
                            'Post-flight notes',
                            style: AppTextStyles.pageTitle,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (state.isLoading && state.setup == null)
                      const LinearProgressIndicator(),
                    if (closed) ...[
                      const _ClosedBanner(),
                      const SizedBox(height: 12),
                    ],
                    DecoratedBox(
                      decoration: AppDecorations.panel,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _objectiveSection(),
                            _batterySection(),
                            _ratingSection(),
                            _logsSection(),
                            _followUpSection(),
                            _notesSection(),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: state.isSaving ? null : _save,
                      icon: Icon(
                        closed ? Icons.save_outlined : Icons.lock_outline,
                      ),
                      label: Text(
                        closed ? 'Save changes' : 'Save & close sortie',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // Sections

  Widget _objectiveSection() {
    final notesMissing =
        _needsObjectiveNotes && _objectiveNotes.text.trim().isEmpty;
    return _FormSection(
      title: 'Objective achieved?',
      summary: notesMissing
          ? 'Notes needed for ${_label(_objectiveResult)}'
          : _label(_objectiveResult),
      done: !notesMissing,
      expanded: _open.contains('objective'),
      onToggle: () => _toggle('objective'),
      children: [
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(
              value: 'YES',
              icon: Icon(Icons.check_circle_outline),
              label: Text('Yes'),
            ),
            ButtonSegment(
              value: 'PARTIAL',
              icon: Icon(Icons.timelapse),
              label: Text('Partial'),
            ),
            ButtonSegment(
              value: 'NO',
              icon: Icon(Icons.cancel_outlined),
              label: Text('No'),
            ),
          ],
          selected: {_objectiveResult},
          showSelectedIcon: false,
          onSelectionChanged: (values) {
            _log.d('objective: ${values.first}');
            setState(() => _objectiveResult = values.first);
          },
        ),
        if (_needsObjectiveNotes) ...[
          const SizedBox(height: 10),
          _textField(
            _objectiveNotes,
            label: 'What was not achieved, and why',
            icon: Icons.notes_outlined,
            lines: 3,
          ),
        ],
      ],
    );
  }

  Widget _batterySection() {
    final missing = _missingBattery;
    return _FormSection(
      title: 'Battery & duration',
      summary: missing.isEmpty
          ? _batterySummary()
          : 'Required: ${missing.join(', ')}',
      done: missing.isEmpty,
      required: missing.isNotEmpty,
      expanded: _open.contains('battery'),
      onToggle: () => _toggle('battery'),
      children: [
        Row(
          children: [
            Expanded(
              child: _numberField(
                _batteryVoltage,
                label: 'Landed battery voltage (V)',
                icon: Icons.battery_charging_full,
                decimal: true,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _numberField(
                _batteryPercent,
                label: 'Landed battery %',
                icon: Icons.percent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _numberField(
          _durationMinutes,
          label: 'Flight duration (minutes)',
          icon: Icons.timer_outlined,
        ),
      ],
    );
  }

  Widget _ratingSection() {
    final missing = _missingRating;
    return _FormSection(
      title: 'How the mission went',
      summary: missing.isNotEmpty
          ? 'Required: ${missing.join(', ')}'
          : '$_stars / 5${_hasIncident ? ' · structural damage' : ''}',
      done: missing.isEmpty,
      required: missing.isNotEmpty,
      expanded: _open.contains('rating'),
      onToggle: () => _toggle('rating'),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var star = 1; star <= 5; star++)
              IconButton(
                onPressed: () => setState(
                  // Tapping the current rating again clears it.
                  () => _stars = _stars == star ? 0 : star,
                ),
                icon: Icon(
                  star <= _stars ? Icons.star : Icons.star_border,
                  size: 32,
                ),
                color: AppColors.deepBlue,
                tooltip: '$star star${star == 1 ? '' : 's'}',
              ),
          ],
        ),
        const SizedBox(height: 6),
        _textField(
          _issues,
          label: 'Anomalies, behaviour, incidents',
          icon: Icons.report_outlined,
          lines: 3,
        ),
        const SizedBox(height: 12),
        Text('Structural damage?', style: AppTextStyles.label),
        const SizedBox(height: 6),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(
              value: false,
              icon: Icon(Icons.check_circle_outline),
              label: Text('No'),
            ),
            ButtonSegment(
              value: true,
              icon: Icon(Icons.build_outlined),
              label: Text('Yes'),
            ),
          ],
          selected: {?_hasDamage},
          emptySelectionAllowed: true,
          showSelectedIcon: false,
          onSelectionChanged: (values) {
            if (values.isEmpty) return;
            _log.d('structural damage: ${values.first}');
            setState(() => _hasDamage = values.first);
          },
        ),
        if (_hasDamage == true) ...[
          const SizedBox(height: 10),
          _textField(
            _damage,
            label: 'What was damaged',
            icon: Icons.build_outlined,
            lines: 2,
          ),
        ],
      ],
    );
  }

  Widget _logsSection() {
    return _FormSection(
      title: 'Logs & data',
      summary: _logStoredAt == null
          ? 'Where the logs are stored'
          : '${_label(_logStoredAt!)}'
                '${_logLocation.text.trim().isEmpty ? '' : ' · ${_logLocation.text.trim()}'}',
      done: _logStoredAt != null,
      expanded: _open.contains('logs'),
      onToggle: () => _toggle('logs'),
      children: [
        Wrap(
          spacing: 8,
          children: [
            for (final place in const ['LOCAL', 'CLOUD', 'BOTH'])
              ChoiceChip(
                label: Text(_label(place)),
                selected: _logStoredAt == place,
                onSelected: (selected) => setState(
                  () => _logStoredAt = selected ? place : null,
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        _textField(
          _logLocation,
          label: 'Flight log ID / GCS path / folder',
          icon: Icons.folder_outlined,
        ),
        const SizedBox(height: 10),
        _textField(
          _logNotes,
          label: 'Log notes',
          icon: Icons.notes_outlined,
          lines: 2,
        ),
      ],
    );
  }

  Widget _followUpSection() {
    final required = _followUpRequired;
    final auto = _followUpChoice == null && required;
    return _FormSection(
      title: 'Follow-up',
      summary: required
          ? (auto ? 'Flagged: objective not met or incident' : 'Flagged')
          : 'Not needed',
      done: true,
      flagged: required,
      expanded: _open.contains('followUp'),
      onToggle: () => _toggle('followUp'),
      children: [
        SwitchListTile(
          value: required,
          onChanged: (value) {
            _log.d('follow-up required: $value');
            setState(() => _followUpChoice = value);
          },
          title: const Text('Flag for follow-up'),
          subtitle: auto
              ? const Text('Flagged automatically', style: AppTextStyles.caption)
              : null,
          contentPadding: EdgeInsets.zero,
        ),
        if (required) ...[
          DropdownButtonFormField<String>(
            initialValue: _people.containsKey(_followUpAssignedTo)
                ? _followUpAssignedTo
                : null,
            decoration: AppDecorations.field(
              label: 'Assigned to',
              icon: Icons.person_outline,
            ),
            items: [
              for (final entry in _people.entries)
                DropdownMenuItem(value: entry.key, child: Text(entry.value)),
            ],
            onChanged: (value) => setState(() => _followUpAssignedTo = value),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _followUpStatus,
            decoration: AppDecorations.field(
              label: 'Status',
              icon: Icons.flag_outlined,
            ),
            items: const [
              DropdownMenuItem(value: 'PENDING', child: Text('Pending')),
              DropdownMenuItem(
                value: 'IN_PROGRESS',
                child: Text('In progress'),
              ),
              DropdownMenuItem(value: 'DONE', child: Text('Done')),
              DropdownMenuItem(value: 'CANCELLED', child: Text('Cancelled')),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _followUpStatus = value);
            },
          ),
          const SizedBox(height: 10),
          _textField(
            _followUpNotes,
            label: 'What needs following up',
            icon: Icons.notes_outlined,
            lines: 2,
          ),
        ],
      ],
    );
  }

  Widget _notesSection() {
    return _FormSection(
      title: 'Other notes',
      summary: _notes.text.trim().isEmpty ? 'Optional' : 'Added',
      done: _notes.text.trim().isNotEmpty,
      expanded: _open.contains('notes'),
      onToggle: () => _toggle('notes'),
      children: [
        _textField(
          _notes,
          label: 'Notes',
          icon: Icons.edit_note_outlined,
          lines: 3,
        ),
      ],
    );
  }

  // Fields

  Widget _textField(
    TextEditingController controller, {
    required String label,
    required IconData icon,
    int lines = 1,
  }) {
    return TextField(
      controller: controller,
      minLines: lines,
      maxLines: lines == 1 ? 1 : 6,
      textCapitalization: TextCapitalization.sentences,
      decoration: AppDecorations.field(label: label, icon: icon),
    );
  }

  Widget _numberField(
    TextEditingController controller, {
    required String label,
    required IconData icon,
    bool decimal = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      inputFormatters: [
        // Ignore a keystroke that would make it not a number.
        TextInputFormatter.withFunction(
          (oldValue, newValue) =>
              RegExp(decimal ? r'^\d*\.?\d*$' : r'^\d*$').hasMatch(
                newValue.text,
              )
              ? newValue
              : oldValue,
        ),
      ],
      onChanged: (_) => _refresh(),
      decoration: AppDecorations.field(label: label, icon: icon),
    );
  }

  // Load / save

  void _prefill(PostFlightNoteEntity note) {
    _log.d('prefill from saved note');
    _prefilled = true;
    _objectiveResult = note.objectiveResult.toUpperCase();
    _objectiveNotes.text = note.objectiveNotes ?? '';
    _stars = _starsFrom(note.missionRating);
    // Incidents and structural damage share one column.
    final issueLines = <String>[];
    final damageLines = <String>[];
    for (final line in (note.issueEncountered ?? '').split('\n')) {
      if (line.startsWith(_structuralDamagePrefix)) {
        damageLines.add(line.substring(_structuralDamagePrefix.length));
      } else if (line.trim().isNotEmpty) {
        issueLines.add(line);
      }
    }
    _issues.text = issueLines.join('\n');
    _damage.text = damageLines.join('\n');
    _hasDamage = damageLines.isNotEmpty;
    _logStoredAt = note.logStoredAt?.toUpperCase();
    _logLocation.text = note.logLocation ?? '';
    _logNotes.text = note.logNotes ?? '';
    final seconds = note.flightDurationSeconds;
    _durationMinutes.text = seconds == null ? '' : '${(seconds / 60).round()}';
    final voltage = note.landedBatteryVoltage;
    _batteryVoltage.text = voltage == null
        ? ''
        : (voltage == voltage.roundToDouble()
              ? voltage.toInt().toString()
              : voltage.toString());
    _batteryPercent.text = note.landedBatteryPercent?.toString() ?? '';
    _followUpChoice = note.followUpRequired;
    _followUpAssignedTo = note.followUpAssignedTo;
    _followUpStatus = (note.followUpStatus ?? 'PENDING').toUpperCase();
    _followUpNotes.text = note.followUpNotes ?? '';
    _notes.text = note.notes ?? '';
  }

  Future<void> _save() => _log.trace('save', () async {
    final closedBefore =
        _cubit.state.setup?.sortie.flightStatus == FlightStatus.closed;
    _log.i(
      'save tapped (objective: $_objectiveResult, stars: $_stars, '
      'followUp: $_followUpRequired, wasClosed: $closedBefore)',
    );
    if (_needsObjectiveNotes && _objectiveNotes.text.trim().isEmpty) {
      setState(() => _open = {..._open, 'objective'});
      _snack(
        'Add notes on why the objective was '
        '${_label(_objectiveResult).toLowerCase()}.',
      );
      return;
    }
    if (_missingBattery.isNotEmpty) {
      setState(() => _open = {..._open, 'battery'});
      _snack('Battery & duration: add ${_missingBattery.join(', ')}.');
      return;
    }
    if (_missingRating.isNotEmpty) {
      setState(() => _open = {..._open, 'rating'});
      _snack('How the mission went: add ${_missingRating.join(', ')}.');
      return;
    }
    final percent = int.tryParse(_batteryPercent.text.trim());
    if (percent != null && percent > 100) {
      setState(() => _open = {..._open, 'battery'});
      _snack('Landed battery % must be between 0 and 100.');
      return;
    }

    final minutes = int.tryParse(_durationMinutes.text.trim());
    final performedBy = await _performedBy();
    final saved = await _cubit.saveAndClose(
      flightId: widget.flightId,
      objectiveResult: _objectiveResult,
      objectiveNotes: _nullable(_objectiveNotes.text),
      missionRating: _stars == 0 ? null : '$_stars',
      issuesEncountered: _combinedIssues(),
      logStoredAt: _logStoredAt,
      logLocation: _nullable(_logLocation.text),
      logNotes: _nullable(_logNotes.text),
      flightDurationSeconds: minutes == null ? null : minutes * 60,
      landedBatteryVoltage: double.tryParse(_batteryVoltage.text.trim()),
      landedBatteryPercent: percent,
      followUpRequired: _followUpRequired,
      followUpNotes: _followUpRequired ? _nullable(_followUpNotes.text) : null,
      followUpAssignedTo: _followUpRequired ? _followUpAssignedTo : null,
      followUpStatus: _followUpRequired ? _followUpStatus : 'PENDING',
      notes: _nullable(_notes.text),
      performedBy: performedBy,
    );
    if (!saved || !mounted) return;

    // Back to the session; it can close once every sortie is closed.
    _snack(closedBefore ? 'Changes saved and logged.' : 'Sortie closed.');
    Navigator.of(context).pop();
  });

  /// The sortie's PIC (kept on the sortie) and its VOs.
  Future<void> _loadPeople() async {
    final names = await UserRepository(widget.database).getUserNames();
    final sortie = await widget.database.preFlightDao.getSortieById(
      widget.flightId,
    );
    final crew = await PreFlightRepositoryImpl(
      widget.database.preFlightDao,
    ).getSortieUsers(widget.flightId);
    if (!mounted) return;
    setState(() {
      _people = {
        if (sortie != null)
          sortie.picUserId: names[sortie.picUserId] ?? 'PIC',
        for (final member in crew)
          if (member.sortieUser.role == 'VO' || member.sortieUser.role == 'PIC')
            member.user.id: member.user.name,
      };
    });
  }

  String? _combinedIssues() {
    final issues = _nullable(_issues.text);
    final damage = _hasDamage == true ? _nullable(_damage.text) : null;
    if (damage == null) return issues;
    final damageText = damage
        .split('\n')
        .map((line) => '$_structuralDamagePrefix$line')
        .join('\n');
    return issues == null ? damageText : '$issues\n$damageText';
  }

  String _batterySummary() {
    final parts = [
      if (_batteryVoltage.text.trim().isNotEmpty)
        '${_batteryVoltage.text.trim()} V',
      if (_batteryPercent.text.trim().isNotEmpty)
        '${_batteryPercent.text.trim()}%',
      if (_durationMinutes.text.trim().isNotEmpty)
        '${_durationMinutes.text.trim()} min',
    ];
    return parts.join(' · ');
  }

  static int _starsFrom(String? rating) => switch (rating?.toUpperCase()) {
    'EXCELLENT' => 5,
    'GOOD' => 4,
    'AVERAGE' => 3,
    'POOR' => 2,
    final value? => (int.tryParse(value) ?? 0).clamp(0, 5),
    null => 0,
  };

  /// YES -> Yes, IN_PROGRESS -> In progress.
  static String _label(String value) {
    final words = value.toLowerCase().replaceAll('_', ' ');
    return words.isEmpty ? words : words[0].toUpperCase() + words.substring(1);
  }

  String? _nullable(String value) {
    final clean = value.trim();
    return clean.isEmpty ? null : clean;
  }

  void _snack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// The signed-in user, as a row in the local users table.
  Future<String> _performedBy() => CurrentUserRepository(
    widget.database,
  ).resolvePerformedBy(widget.authCubit.state);
}

/// Shown on a closed sortie: it can still be edited, and edits are logged.
class _ClosedBanner extends StatelessWidget {
  const _ClosedBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.successGreen.withValues(alpha: 0.08),
        borderRadius: const BorderRadius.all(
          Radius.circular(AppSizes.panelRadius),
        ),
        border: Border.all(color: AppColors.successGreen),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline, color: AppColors.successGreen),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Sortie closed · changes are logged as amendments',
              style: AppTextStyles.success.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A collapsible form section, styled like the pre-flight checklist
/// sections: title, a one-line summary, a tick when filled in.
class _FormSection extends StatelessWidget {
  final String title;
  final String summary;
  final bool done;

  /// Shows a flag instead of the tick (follow-up raised).
  final bool flagged;

  /// Required fields are still empty: the summary is shown in red.
  final bool required;
  final bool expanded;
  final VoidCallback onToggle;
  final List<Widget> children;

  const _FormSection({
    required this.title,
    required this.summary,
    required this.done,
    this.flagged = false,
    this.required = false,
    required this.expanded,
    required this.onToggle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
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
                            summary,
                            style: required
                                ? AppTextStyles.error
                                : AppTextStyles.caption,
                          ),
                        ],
                      ),
                    ),
                    if (flagged)
                      const Icon(
                        Icons.flag,
                        size: 18,
                        color: AppColors.errorRed,
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
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
