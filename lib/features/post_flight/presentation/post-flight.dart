import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:the_audit/core/database/app_database.dart';
import 'package:the_audit/core/utils/navbar.dart';
import 'package:the_audit/core/utils/theme.dart';
import 'package:the_audit/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:the_audit/features/post_flight/data/repositories/post_flight_repository_impl.dart';
import 'package:the_audit/features/post_flight/presentation/cubit/post_flight_cubit.dart';
import 'package:the_audit/features/post_flight/presentation/cubit/post_flight_state.dart';
import 'package:the_audit/features/pre_flight/data/mappers/pre_flight_mapper.dart';
import 'package:the_audit/features/pre_flight/domain/entities/sortie_user_entity.dart';

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
  final _objectiveNotesController = TextEditingController();
  final _structuralDamageController = TextEditingController();
  final _issuesController = TextEditingController();
  final _logStoredAtController = TextEditingController();
  final _logLocationController = TextEditingController();
  final _logNotesController = TextEditingController();
  final _followUpNotesController = TextEditingController();
  final _notesController = TextEditingController();

  String _objectiveResult = 'YES';
  double _missionRating = 0;
  bool _followUpRequired = false;
  String? _followUpAssignedTo;
  String _followUpStatus = 'PENDING';
  List<SortieUserWithUserEntity> _sortieUsers = [];

  @override
  void initState() {
    super.initState();
    _cubit = PostFlightCubit(
      PostFlightRepositoryImpl(widget.database.postFlightDao),
    )..loadSetup(widget.flightId);
    _loadSortieUsers();
  }

  @override
  void dispose() {
    _cubit.close();
    _objectiveNotesController.dispose();
    _structuralDamageController.dispose();
    _issuesController.dispose();
    _logStoredAtController.dispose();
    _logLocationController.dispose();
    _logNotesController.dispose();
    _followUpNotesController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: BlocConsumer<PostFlightCubit, PostFlightState>(
        listener: (context, state) {
          if (!state.hasError) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.errorMessage!)));
        },
        builder: (context, state) {
          return Scaffold(
            appBar: const NavBar(),
            backgroundColor: AppColors.iceBlue,
            body: SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
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
                          'Post-flight notes',
                          style: TextStyle(
                            color: AppColors.darkNavy,
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (state.isLoading) const LinearProgressIndicator(),
                  DropdownButtonFormField<String>(
                    initialValue: _objectiveResult,
                    decoration: _inputDecoration('Objective result'),
                    items: const [
                      DropdownMenuItem(value: 'YES', child: Text('Yes')),
                      DropdownMenuItem(
                        value: 'PARTIAL',
                        child: Text('Partial'),
                      ),
                      DropdownMenuItem(value: 'NO', child: Text('No')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _objectiveResult = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  _MissionRatingField(
                    value: _missionRating,
                    onChanged: (value) {
                      setState(() => _missionRating = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  _NotesField(
                    controller: _objectiveNotesController,
                    label: 'Objective notes',
                  ),
                  const SizedBox(height: 12),
                  _NotesField(
                    controller: _issuesController,
                    label: 'Issues encountered',
                  ),
                  const SizedBox(height: 12),
                  _NotesField(
                    controller: _structuralDamageController,
                    label: 'Structural damage',
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _nullable(_logStoredAtController.text),
                    decoration: _inputDecoration('Log stored at'),
                    items: const [
                      DropdownMenuItem(value: 'LOCAL', child: Text('Local')),
                      DropdownMenuItem(value: 'CLOUD', child: Text('Cloud')),
                      DropdownMenuItem(value: 'BOTH', child: Text('Both')),
                    ],
                    onChanged: (value) {
                      _logStoredAtController.text = value ?? '';
                    },
                  ),
                  const SizedBox(height: 12),
                  _NotesField(
                    controller: _logLocationController,
                    label: 'Log location',
                    minLines: 1,
                  ),
                  const SizedBox(height: 12),
                  _NotesField(
                    controller: _logNotesController,
                    label: 'Log notes',
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    value: _followUpRequired,
                    onChanged: (value) {
                      setState(() => _followUpRequired = value);
                    },
                    title: const Text('Follow-up required'),
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (_followUpRequired) ...[
                    const SizedBox(height: 12),
                    _NotesField(
                      controller: _followUpNotesController,
                      label: 'Follow-up notes',
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _followUpAssignedTo,
                      decoration: _inputDecoration('Follow-up assigned to'),
                      items: [
                        for (final user in _followUpUsers)
                          DropdownMenuItem(
                            value: user.user.id,
                            child: Text(user.user.name),
                          ),
                      ],
                      onChanged: (value) {
                        setState(() => _followUpAssignedTo = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _followUpStatus,
                      decoration: _inputDecoration('Follow-up status'),
                      items: const [
                        DropdownMenuItem(
                          value: 'PENDING',
                          child: Text('Pending'),
                        ),
                        DropdownMenuItem(
                          value: 'IN_PROGRESS',
                          child: Text('In progress'),
                        ),
                        DropdownMenuItem(value: 'DONE', child: Text('Done')),
                        DropdownMenuItem(
                          value: 'CANCELLED',
                          child: Text('Cancelled'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _followUpStatus = value);
                      },
                    ),
                  ],
                  const SizedBox(height: 12),
                  _NotesField(controller: _notesController, label: 'Notes'),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: state.isSaving ? null : _save,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Save notes'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: state.isSaving ? null : _closeSortie,
                    icon: const Icon(Icons.lock_outline),
                    label: const Text('Close sortie'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _save() async {
    final performedBy = await _performedBy();
    return _cubit.savePostFlightNote(
      flightId: widget.flightId,
      objectiveResult: _objectiveResult,
      objectiveNotes: _nullable(_objectiveNotesController.text),
      missionRating: _formatRating(_missionRating),
      issuesEncountered: _combinedIssues(),
      logStoredAt: _nullable(_logStoredAtController.text),
      logLocation: _nullable(_logLocationController.text),
      logNotes: _nullable(_logNotesController.text),
      followUpRequired: _followUpRequired,
      followUpNotes: _followUpRequired
          ? _nullable(_followUpNotesController.text)
          : null,
      followUpAssignedTo: _followUpRequired ? _followUpAssignedTo : null,
      followUpStatus: _followUpRequired ? _followUpStatus : 'PENDING',
      notes: _nullable(_notesController.text),
      createdBy: performedBy,
    );
  }

  Future<void> _closeSortie() async {
    final performedBy = await _performedBy();
    return _cubit.closeSortie(flightId: widget.flightId, closedBy: performedBy);
  }

  String? _nullable(String value) {
    final clean = value.trim();
    return clean.isEmpty ? null : clean;
  }

  String _formatRating(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }

  String? _combinedIssues() {
    final issues = _nullable(_issuesController.text);
    final structuralDamage = _nullable(_structuralDamageController.text);

    if (structuralDamage == null) return issues;
    if (issues == null) return 'Structural damage: $structuralDamage';
    return '$issues\nStructural damage: $structuralDamage';
  }

  List<SortieUserWithUserEntity> get _followUpUsers {
    return _sortieUsers
        .where(
          (item) =>
              item.sortieUser.role == 'PIC' ||
              item.sortieUser.role == 'VO' ||
              item.sortieUser.role == 'CREW',
        )
        .toList();
  }

  Future<void> _loadSortieUsers() async {
    final users = await widget.database.preFlightDao.getSortieUsers(
      widget.flightId,
    );
    if (!mounted) return;
    setState(() {
      _sortieUsers = users.map((item) => item.toEntity()).toList();
    });
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

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: AppColors.snowWhite,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}

class _NotesField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final int minLines;

  const _NotesField({
    required this.controller,
    required this.label,
    this.minLines = 3,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      minLines: minLines,
      maxLines: 5,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppColors.snowWhite,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _MissionRatingField extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const _MissionRatingField({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: 'Mission rating',
        filled: true,
        fillColor: AppColors.snowWhite,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (var index = 1; index <= 5; index++)
                IconButton(
                  onPressed: () => onChanged(index.toDouble()),
                  icon: Icon(_iconFor(index)),
                  color: AppColors.deepBlue,
                  tooltip: '$index star',
                ),
            ],
          ),
          Slider(
            value: value,
            min: 0,
            max: 5,
            divisions: 10,
            label: _label,
            onChanged: onChanged,
          ),
          Text(_label),
        ],
      ),
    );
  }

  IconData _iconFor(int index) {
    if (value >= index) return Icons.star;
    if (value >= index - 0.5) return Icons.star_half;
    return Icons.star_border;
  }

  String get _label {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }
}
