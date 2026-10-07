import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:the_audit/core/errors/app_failure.dart';
import 'package:the_audit/core/utils/app_logger.dart';

import '../../app_database.dart';
import '../../dao_write_helpers.dart';
import '../../dtos/equipment_dtos.dart';

part 'equipment_dao.g.dart';

const _uuid = Uuid();

/// Standard "equipment to bring" lists (per vehicle, plus Tools for every
/// session) and each session's packed snapshot.
@DriftAccessor(
  tables: [
    EquipmentTemplateItems,
    SessionEquipmentItems,
    AuditEvents,
    SyncQueue,
  ],
)
class EquipmentDao extends DatabaseAccessor<AppDatabase>
    with _$EquipmentDaoMixin, DaoWriteHelpers {
  EquipmentDao(super.db);

  static const _log = AppLogger('EquipmentDao');

  /// Active items of one list ([vehicleId] null = Tools), in display order.
  Future<List<EquipmentTemplateItem>> getTemplateItems({String? vehicleId}) {
    _log.t('getTemplateItems(vehicleId: ${vehicleId ?? 'TOOLS'})');
    return (select(equipmentTemplateItems)
          ..where(
            (t) =>
                t.isActive.equals(true) &
                (vehicleId == null
                    ? t.vehicleId.isNull()
                    : t.vehicleId.equals(vehicleId)),
          )
          ..orderBy([
            (t) => OrderingTerm.asc(t.categoryOrder),
            (t) => OrderingTerm.asc(t.sortOrder),
          ]))
        .get();
  }

  /// Adds an item to the end of its category; a new category goes after the
  /// existing ones.
  Future<String> addTemplateItem({
    String? vehicleId,
    required String category,
    required String name,
    int? quantity,
    int? spares,
    required String performedBy,
  }) async {
    _log.t(
      'addTemplateItem(vehicleId: ${vehicleId ?? 'TOOLS'}, '
      'category: $category, qty: $quantity, spares: $spares)',
    );
    _validate(
      category: category,
      name: name,
      quantity: quantity,
      spares: spares,
    );

    return _log.trace('addTemplateItem', () async {
      final existing = await getTemplateItems(vehicleId: vehicleId);
      final cleanCategory = category.trim();
      final inCategory = existing.where(
        (item) => item.category.toLowerCase() == cleanCategory.toLowerCase(),
      );
      final categoryOrder = inCategory.isNotEmpty
          ? inCategory.first.categoryOrder
          : existing.fold<int>(
                  -1,
                  (max, item) =>
                      item.categoryOrder > max ? item.categoryOrder : max,
                ) +
                1;
      final sortOrder =
          inCategory.fold<int>(
            -1,
            (max, item) => item.sortOrder > max ? item.sortOrder : max,
          ) +
          1;
      final id = _uuid.v4();

      await transaction(() async {
        await into(equipmentTemplateItems).insert(
          EquipmentTemplateItemsCompanion.insert(
            id: id,
            vehicleId: Value(vehicleId),
            category: inCategory.isNotEmpty
                ? inCategory.first.category
                : cleanCategory,
            name: name.trim(),
            quantity: Value(quantity),
            spares: Value(spares),
            categoryOrder: categoryOrder,
            sortOrder: sortOrder,
          ),
        );
        await insertAuditEvent(
          entityType: 'EQUIPMENT_ITEM',
          entityId: id,
          action: 'CREATE',
          description: 'Equipment item added to ${vehicleId ?? 'Tools'} list',
          performedBy: performedBy,
        );
        await enqueueSync(
          entityType: 'EQUIPMENT_ITEM',
          entityId: id,
          operation: 'INSERT',
        );
      });
      return id;
    });
  }

  /// Updates an item. Null leaves a field unchanged; [clearQuantity] /
  /// [clearSpares] blank the numbers.
  Future<void> updateTemplateItem({
    required String id,
    String? category,
    String? name,
    int? quantity,
    int? spares,
    bool clearQuantity = false,
    bool clearSpares = false,
    required String performedBy,
  }) async {
    _log.t('updateTemplateItem(id: $id, qty: $quantity, spares: $spares)');
    if ((category != null && category.trim().isEmpty) ||
        (name != null && name.trim().isEmpty)) {
      _log.w('Equipment item name and category cannot be empty.');
      throw AppFailure('Equipment item name and category cannot be empty.');
    }
    _validateCounts(quantity: quantity, spares: spares);

    return _log.trace('updateTemplateItem', () async {
      final item = await _requireTemplateItem(id);

      // Moving to another category appends it there.
      var categoryOrder = item.categoryOrder;
      var sortOrder = item.sortOrder;
      final newCategory = category?.trim();
      if (newCategory != null &&
          newCategory.toLowerCase() != item.category.toLowerCase()) {
        final existing = await getTemplateItems(vehicleId: item.vehicleId);
        final inCategory = existing.where(
          (other) => other.category.toLowerCase() == newCategory.toLowerCase(),
        );
        categoryOrder = inCategory.isNotEmpty
            ? inCategory.first.categoryOrder
            : existing.fold<int>(
                    -1,
                    (max, other) =>
                        other.categoryOrder > max ? other.categoryOrder : max,
                  ) +
                  1;
        sortOrder =
            inCategory.fold<int>(
              -1,
              (max, other) => other.sortOrder > max ? other.sortOrder : max,
            ) +
            1;
      }

      await transaction(() async {
        await (update(
          equipmentTemplateItems,
        )..where((t) => t.id.equals(id))).write(
          EquipmentTemplateItemsCompanion(
            category: newCategory == null
                ? const Value.absent()
                : Value(newCategory),
            name: name == null ? const Value.absent() : Value(name.trim()),
            quantity: clearQuantity
                ? const Value(null)
                : quantity == null
                ? const Value.absent()
                : Value(quantity),
            spares: clearSpares
                ? const Value(null)
                : spares == null
                ? const Value.absent()
                : Value(spares),
            categoryOrder: Value(categoryOrder),
            sortOrder: Value(sortOrder),
            updatedAt: Value(DateTime.now()),
          ),
        );
        await insertAuditEvent(
          entityType: 'EQUIPMENT_ITEM',
          entityId: id,
          action: 'UPDATE',
          description: 'Equipment item updated',
          performedBy: performedBy,
        );
        await enqueueSync(
          entityType: 'EQUIPMENT_ITEM',
          entityId: id,
          operation: 'UPDATE',
        );
      });
    });
  }

  /// Removes an item from its list (kept in the database, marked inactive).
  Future<void> deactivateTemplateItem({
    required String id,
    required String performedBy,
  }) async {
    _log.t('deactivateTemplateItem(id: $id)');
    return _log.trace('deactivateTemplateItem', () async {
      await _requireTemplateItem(id);
      await transaction(() async {
        await (update(
          equipmentTemplateItems,
        )..where((t) => t.id.equals(id))).write(
          EquipmentTemplateItemsCompanion(
            isActive: const Value(false),
            updatedAt: Value(DateTime.now()),
          ),
        );
        await insertAuditEvent(
          entityType: 'EQUIPMENT_ITEM',
          entityId: id,
          action: 'DEACTIVATE',
          description: 'Equipment item removed from list',
          performedBy: performedBy,
        );
        await enqueueSync(
          entityType: 'EQUIPMENT_ITEM',
          entityId: id,
          operation: 'UPDATE',
        );
      });
    });
  }

  /// Stores what a session takes, as a snapshot independent of later list
  /// edits.
  Future<void> saveSessionEquipment({
    required String sessionId,
    required List<SessionEquipmentDraft> items,
    required String performedBy,
  }) async {
    _log.t(
      'saveSessionEquipment(sessionId: $sessionId, items: ${items.length})',
    );
    if (items.isEmpty) return;

    return _log.trace('saveSessionEquipment', () async {
      final now = DateTime.now();
      await transaction(() async {
        for (final item in items) {
          await into(sessionEquipmentItems).insert(
            SessionEquipmentItemsCompanion.insert(
              id: _uuid.v4(),
              sessionId: sessionId,
              sessionVehicleId: Value(item.sessionVehicleId),
              templateItemId: Value(item.templateItemId),
              category: item.category,
              name: item.name,
              quantity: Value(item.quantity),
              spares: Value(item.spares),
              isPacked: Value(item.isPacked),
              packedAt: Value(item.isPacked ? now : null),
              packedBy: Value(item.isPacked ? performedBy : null),
              categoryOrder: item.categoryOrder,
              sortOrder: item.sortOrder,
            ),
          );
        }
        final packed = items.where((item) => item.isPacked).length;
        await insertAuditEvent(
          entityType: 'FIELD_SESSION',
          entityId: sessionId,
          action: 'UPDATE',
          description:
              'Equipment checklist saved: $packed / ${items.length} packed',
          performedBy: performedBy,
        );
        await enqueueSync(
          entityType: 'FIELD_SESSION',
          entityId: sessionId,
          operation: 'UPDATE',
        );
      });
      _log.i('session equipment saved: ${items.length} items');
    });
  }

  /// A session's saved equipment, Tools first, then by vehicle and order.
  Future<List<SessionEquipmentItem>> getSessionEquipmentItems(
    String sessionId,
  ) {
    _log.t('getSessionEquipmentItems(sessionId: $sessionId)');
    return (select(sessionEquipmentItems)
          ..where((t) => t.sessionId.equals(sessionId))
          ..orderBy([
            (t) => OrderingTerm(
              expression: t.sessionVehicleId,
              nulls: NullsOrder.first,
            ),
            (t) => OrderingTerm.asc(t.categoryOrder),
            (t) => OrderingTerm.asc(t.sortOrder),
          ]))
        .get();
  }

  Future<EquipmentTemplateItem> _requireTemplateItem(String id) async {
    final item = await (select(
      equipmentTemplateItems,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (item == null) {
      _log.w('Equipment item not found: $id');
      throw AppFailure('Equipment item not found: $id');
    }
    return item;
  }

  void _validate({
    required String category,
    required String name,
    int? quantity,
    int? spares,
  }) {
    if (category.trim().isEmpty || name.trim().isEmpty) {
      _log.w('Equipment item name and category are required.');
      throw AppFailure('Equipment item name and category are required.');
    }
    _validateCounts(quantity: quantity, spares: spares);
  }

  void _validateCounts({int? quantity, int? spares}) {
    if ((quantity != null && quantity < 0) || (spares != null && spares < 0)) {
      _log.w('Quantity and spares cannot be negative.');
      throw AppFailure('Quantity and spares cannot be negative.');
    }
  }
}
