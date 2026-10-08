import 'dart:ffi';

import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/open.dart';
import 'package:the_audit/core/database/app_database.dart';

import 'generated/schema.dart';

/// Every upgrade between saved schema snapshots (drift_schemas/) must end
/// with exactly the tables and columns the app declares. New snapshots come
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

  const versions = GeneratedHelper.versions;
  for (final (i, fromVersion) in versions.indexed) {
    group('from $fromVersion', () {
      for (final toVersion in versions.skip(i + 1)) {
        test('to $toVersion', () async {
          final schema = await verifier.schemaAt(fromVersion);
          final db = AppDatabase.forTesting(schema.newConnection());
          await verifier.migrateAndValidate(db, toVersion);
          await db.close();
        });
      }
    });
  }
}
