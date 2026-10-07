import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:the_audit/core/database/app_database.dart';
import 'package:the_audit/core/utils/app_logger.dart';
import 'package:the_audit/core/utils/theme.dart';
import 'package:the_audit/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:the_audit/core/utils/navbar.dart';
import 'package:the_audit/features/pre_field/presentation/pre-field.dart';
import 'package:the_audit/features/pre_field/presentation/session_loop.dart';
import 'package:the_audit/features/profile/presentation/profile_page.dart';
import 'package:the_audit/features/records/data/repositories/records_repository_impl.dart';
import 'package:the_audit/features/records/domain/entities/record_entity.dart';
import 'package:the_audit/features/records/presentation/cubit/records_cubit.dart';
import 'package:the_audit/features/records/presentation/cubit/records_state.dart';

const _log = AppLogger('Home');

class HomePage extends StatefulWidget {
  final AppDatabase database;
  final AuthCubit authCubit;
  const HomePage({super.key, required this.database, required this.authCubit});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final RecordsCubit _records;

  @override
  void initState() {
    super.initState();
    _log.t('initState');
    _records = RecordsCubit(RecordRepositoryImpl(widget.database.recordDao))
      ..loadRecentSessions();
  }

  @override
  void dispose() {
    _log.t('dispose');
    _records.close();
    super.dispose();
  }

  Future<void> _reload() {
    _log.d('reloading sessions');
    return _records.loadRecentSessions();
  }

  Future<void> _createSession() async {
    _log.i('new session tapped');
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'CreateSession'),
        builder: (_) => CreateSessionPage(
          database: widget.database,
          authCubit: widget.authCubit,
        ),
      ),
    );
    if (mounted) _reload();
  }

  Future<void> _openSession(FieldSessionEntity session) async {
    _log.i(
      'open session ${session.sessionId} (status: ${session.sessionStatus})',
    );
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'SessionLoop'),
        builder: (_) => SessionLoopPage(
          database: widget.database,
          authCubit: widget.authCubit,
          sessionId: session.sessionId,
        ),
      ),
    );
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createSession,
        icon: const Icon(Icons.add),
        label: const Text('New session'),
      ),
      appBar: NavBar(
        onProfileTap: () {
          _log.d('profile tapped');
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              settings: const RouteSettings(name: 'Profile'),
              builder: (_) => ProfilePage(
                database: widget.database,
                authCubit: widget.authCubit,
              ),
            ),
          );
        },
      ),
      body: SafeArea(
        child: BlocBuilder<RecordsCubit, RecordsState>(
          bloc: _records,
          builder: (context, state) {
            // Spinner only until the first list arrives; a refresh keeps it.
            if (state.isLoading && state.sessions.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state.status == RecordsStatus.failure) {
              return const Center(
                child: Text(
                  'Sessions could not be loaded.',
                  style: AppTextStyles.error,
                ),
              );
            }

            final sessions = state.sessions;
            return RefreshIndicator(
              onRefresh: _reload,
              child: ListView(
                padding: AppSizes.pageInsets.copyWith(bottom: 96),
                children: [
                  const Text('Sessions', style: AppTextStyles.pageTitle),
                  const SizedBox(height: 16),
                  if (sessions.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 48),
                      child: Text(
                        'No sessions yet. Tap “New session” to plan one.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.secondary,
                      ),
                    )
                  else
                    for (final session in sessions)
                      _SessionTile(
                        session: session,
                        onTap: () => _openSession(session),
                      ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  final FieldSessionEntity session;
  final VoidCallback onTap;

  const _SessionTile({required this.session, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final date = session.date;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        leading: const Icon(Icons.event_note_outlined),
        title: Text(session.locationName, style: AppTextStyles.bodyStrong),
        subtitle: Text(
          '${date.day}/${date.month}/${date.year} · '
          '${_titleCase(session.missionType)}',
        ),
        trailing: _StatusChip(status: session.sessionStatus),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final isOpen = status != 'CLOSED';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: AppDecorations.stepChip(active: isOpen),
      child: Text(
        _titleCase(status),
        style: isOpen
            ? AppTextStyles.chipLabel.copyWith(color: AppColors.snowWhite)
            : AppTextStyles.chipLabel,
      ),
    );
  }
}

/// IN_PROGRESS -> In progress, DATA_COLLECTION -> Data collection.
String _titleCase(String value) {
  final words = value.toLowerCase().replaceAll('_', ' ');
  return words.isEmpty ? words : words[0].toUpperCase() + words.substring(1);
}
