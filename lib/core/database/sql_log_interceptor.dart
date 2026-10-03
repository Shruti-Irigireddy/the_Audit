import 'package:drift/drift.dart';
import 'package:the_audit/core/utils/app_logger.dart';

/// Debug-only drift interceptor: logs every SQL statement with its
/// arguments, row count and duration, and transaction boundaries.
/// Attached in [AppDatabase] only when `kDebugMode` is true.
class SqlLogInterceptor extends QueryInterceptor {
  static const _log = AppLogger('SQL');

  Future<T> _run<T>(
    String statement,
    List<Object?> args,
    Future<T> Function() action, {
    String Function(T result)? describe,
  }) async {
    final watch = Stopwatch()..start();
    try {
      final result = await action();
      final detail = describe == null ? '' : ' → ${describe(result)}';
      _log.t(
        '${_short(statement)} ${_args(args)}$detail '
        '(${watch.elapsedMilliseconds} ms)',
      );
      return result;
    } catch (error, stackTrace) {
      _log.e('${_short(statement)} ${_args(args)} failed', error, stackTrace);
      rethrow;
    }
  }

  static String _short(String sql) {
    final oneLine = sql.replaceAll(RegExp(r'\s+'), ' ').trim();
    return oneLine.length <= 300 ? oneLine : '${oneLine.substring(0, 300)}…';
  }

  static String _args(List<Object?> args) {
    if (args.isEmpty) return '';
    final text = args.toString();
    return text.length <= 200 ? text : '${text.substring(0, 200)}…]';
  }

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) => _run(
    statement,
    args,
    () => executor.runSelect(statement, args),
    describe: (rows) => '${rows.length} rows',
  );

  @override
  Future<int> runInsert(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) => _run(statement, args, () => executor.runInsert(statement, args));

  @override
  Future<int> runUpdate(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) => _run(
    statement,
    args,
    () => executor.runUpdate(statement, args),
    describe: (count) => '$count updated',
  );

  @override
  Future<int> runDelete(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) => _run(
    statement,
    args,
    () => executor.runDelete(statement, args),
    describe: (count) => '$count deleted',
  );

  @override
  Future<void> runCustom(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) => _run(statement, args, () => executor.runCustom(statement, args));

  @override
  Future<void> runBatched(
    QueryExecutor executor,
    BatchedStatements statements,
  ) {
    _log.t('batch: ${statements.statements.length} statements');
    return executor.runBatched(statements);
  }

  @override
  TransactionExecutor beginTransaction(QueryExecutor parent) {
    _log.t('BEGIN TRANSACTION');
    return super.beginTransaction(parent);
  }

  @override
  Future<void> commitTransaction(TransactionExecutor inner) {
    _log.t('COMMIT');
    return super.commitTransaction(inner);
  }

  @override
  Future<void> rollbackTransaction(TransactionExecutor inner) {
    _log.w('ROLLBACK');
    return super.rollbackTransaction(inner);
  }
}
