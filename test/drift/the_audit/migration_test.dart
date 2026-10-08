import 'dart:ffi';

import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/open.dart';
import 'package:the_audit/core/database/app_database.dart';

import 'generated/schema.dart';

/// Every saved schema snapshot (drift_schemas/) must upgrade to exactly the
/// tables and columns the app declares. New snapshots come
/// from `dart run drift_dev make-migrations` after a schema change.
void main() {
  // Some Linux hosts only ship the versioned library name.
  open.overrideFor(
    OperatingSystem.linux,
    () => DynamicLibrary.open('libsqlite3.so.0'),
  );
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  // Every saved version must upgrade to the current schema.
  const versions = GeneratedHelper.versions;
  final current = versions.last;
  for (final fromVersion in versions.where((v) => v != current)) {
    test('from $fromVersion to $current', () async {
      final schema = await verifier.schemaAt(fromVersion);
      final db = AppDatabase.forTesting(schema.newConnection());
      await verifier.migrateAndValidate(db, current);
      await db.close();
    });
  }
}
