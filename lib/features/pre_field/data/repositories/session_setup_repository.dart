import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

import 'package:the_audit/core/database/app_database.dart';
import 'package:the_audit/core/database/checklists/common_preflight.dart';
import 'package:the_audit/core/database/dtos/equipment_dtos.dart';
import 'package:the_audit/core/utils/app_logger.dart';
import 'package:the_audit/features/auth/data/user_directory.dart';
import 'package:the_audit/features/vehicle/domain/dtos/vehicle_dtos.dart';

/// Active payloads and which vehicles each one fits.
class PayloadCatalog {
  final List<Payload> payloads;

  /// Payload id -> vehicle types it fits (empty = any type).
  final Map<String, Set<String>> types;

  /// Payload id -> the only vehicles it fits, for vehicle-limited payloads.
  final Map<String, Set<String>> vehicleLimits;

  const PayloadCatalog({
    required this.payloads,
    required this.types,
    required this.vehicleLimits,
  });

  static const empty = PayloadCatalog(
    payloads: [],
    types: {},
    vehicleLimits: {},
  );

  /// Payloads [vehicle] can carry: a payload limited to specific vehicles
  /// fits only those; otherwise it fits by vehicle type (no types = any).
  List<Payload> payloadsFor(Vehicle vehicle) {
    final type = vehicle.type.trim().toUpperCase();
    bool fits(Payload payload) {
      final limit = vehicleLimits[payload.payloadId];
      if (limit != null) return limit.contains(vehicle.id);
      final fitting = types[payload.payloadId] ?? const <String>{};
      return fitting.isEmpty || fitting.contains(type);
    }

    return [
      for (final payload in payloads)
        if (fits(payload)) payload,
    ];
  }
}

/// Everything Create session reads and writes besides the session itself:
/// vehicles, people, payloads and equipment lists.
class SessionSetupRepository {
  static const _log = AppLogger('SessionSetupRepository');

  final AppDatabase _db;

  const SessionSetupRepository(this._db);

  // Vehicles

  Future<List<Vehicle>> getActiveVehicles() =>
      _db.vehicleDao.getActiveVehicles();

  /// A new vehicle with the common pre-flight checklist plus its type's.
  Future<String> createVehicle({
    required String name,
    required String type,
    String? frameMake,
    String? frameModel,
    int? motorCount,
    String? frameStyle,
    String? firmwareTarget,
    String? defaultFailSafeProfile,
    String? notes,
    required String performedBy,
  }) {
    return _db.vehicleDao.createVehicleWithChecklist(
      name: name,
      type: type,
      frameMake: frameMake,
      frameModel: frameModel,
      motorCount: motorCount,
      frameStyle: frameStyle,
      firmwareTarget: firmwareTarget,
      defaultFailSafeProfile: defaultFailSafeProfile,
      notes: notes,
      createdByUserId: performedBy,
      checklistItems: _checklistFor(type),
    );
  }

  /// Saves edited details. A cleared text field (null) is written as '' to
  /// actually clear it. A new type gets that type's checklist as a fresh
  /// version; flights keep the version they used.
  Future<void> editVehicle({
    required Vehicle before,
    required String name,
    required String type,
    String? frameMake,
    String? frameModel,
    int? motorCount,
    String? frameStyle,
    String? firmwareTarget,
    String? defaultFailSafeProfile,
    String? notes,
    required String performedBy,
  }) async {
    // updateVehicle treats null as "unchanged".
    String? edited(String? old, String? value) =>
        value ?? (old == null ? null : '');

    await _db.vehicleDao.updateVehicle(
      vehicleId: before.id,
      name: name,
      type: type,
      frameMake: edited(before.frameMake, frameMake),
      frameModel: edited(before.frameModel, frameModel),
      // null keeps the old count (an int can't be cleared to '').
      motorCount: motorCount,
      frameStyle: edited(before.frameStyle, frameStyle),
      firmwareTarget: edited(before.firmwareTarget, firmwareTarget),
      defaultFailSafeProfile: edited(
        before.defaultFailSafeProfile,
        defaultFailSafeProfile,
      ),
      notes: edited(before.notes, notes),
      performedBy: performedBy,
    );

    if (type != before.type.trim().toUpperCase()) {
      await _db.vehicleDao.createNewChecklistVersionForVehicle(
        vehicleId: before.id,
        checklistItems: _checklistFor(type),
        createdBy: performedBy,
        deactivationReason: 'Vehicle type changed to $type',
      );
      _log.i('vehicle ${before.id} checklist renewed for $type');
    }
  }

  static List<ChecklistItemDraft> _checklistFor(String type) => [
    for (final item in preflightChecklistFor(type))
      ChecklistItemDraft(
        section: item.section,
        label: item.label,
        responseType: item.responseType,
        blocksArming: item.blocksArming,
      ),
  ];

  // People

  Future<List<User>> getSelectableUsers() =>
      _db.preFieldDao.getSelectableUsers();

  /// Adds the signed-in user to the team directory, then copies the
  /// directory from Firestore. Offline, the saved users stay.
  Future<void> refreshUsersFromDirectory() async {
    final directory = UserDirectory(_db);
    final current = firebase_auth.FirebaseAuth.instance.currentUser;
    if (current != null) await directory.registerSignedInUser(current);
    try {
      await directory.syncToLocal();
    } catch (error, stackTrace) {
      _log.w('user sync failed; using saved users', error, stackTrace);
    }
  }

  // Payloads

  Future<PayloadCatalog> loadPayloadCatalog() async {
    final dao = _db.payloadDao;
    final payloads = [
      for (final payload in await dao.getAllPayloads())
        if (payload.status == 'ACTIVE') payload,
    ];
    final types = <String, Set<String>>{};
    final limits = <String, Set<String>>{};
    for (final payload in payloads) {
      types[payload.payloadId] = {
        for (final type in await dao.getCompatibleVehicleTypes(
          payload.payloadId,
        ))
          type.trim().toUpperCase(),
      };
      final vehicleIds = await dao.getLimitedVehicleIds(payload.payloadId);
      if (vehicleIds.isNotEmpty) limits[payload.payloadId] = {...vehicleIds};
    }
    _log.d(
      'loaded ${payloads.length} payloads (${limits.length} vehicle-limited)',
    );
    return PayloadCatalog(
      payloads: payloads,
      types: types,
      vehicleLimits: limits,
    );
  }

  Future<String> createPayload({
    required String name,
    required String category,
    String? storageType,
    String? storageCapacity,
    required List<String> vehicleTypes,
    required String performedBy,
  }) {
    return _db.payloadDao.createPayload(
      name: name,
      category: category,
      storageType: storageType,
      storageCapacity: storageCapacity,
      compatibleVehicleTypes: vehicleTypes,
      performedBy: performedBy,
    );
  }

  /// Links each chosen payload to every session vehicle it fits
  /// (FR-PFT-06). Returns how many links were made.
  Future<int> linkPayloadsToSessionVehicles({
    required String sessionId,
    required PayloadCatalog catalog,
    required Set<String> payloadIds,
    required String performedBy,
  }) async {
    if (payloadIds.isEmpty) return 0;
    final dao = _db.preFieldDao;
    var count = 0;
    for (final row in await dao.getSessionVehicles(sessionId)) {
      for (final payload in catalog.payloadsFor(row.vehicle)) {
        if (!payloadIds.contains(payload.payloadId)) continue;
        await dao.addPayloadToSessionVehicle(
          sessionVehicleId: row.sessionVehicle.id,
          payloadId: payload.payloadId,
          performedBy: performedBy,
        );
        count++;
      }
    }
    return count;
  }

  // Equipment lists

  /// Tools (no [vehicleId]) or one vehicle's equipment list.
  Future<List<EquipmentTemplateItem>> getEquipmentList({String? vehicleId}) =>
      _db.equipmentDao.getTemplateItems(vehicleId: vehicleId);

  Future<void> addEquipmentItem({
    String? vehicleId,
    required String category,
    required String name,
    int? quantity,
    int? spares,
    required String performedBy,
  }) async {
    await _db.equipmentDao.addTemplateItem(
      vehicleId: vehicleId,
      category: category,
      name: name,
      quantity: quantity,
      spares: spares,
      performedBy: performedBy,
    );
  }

  /// Saves an edited item; an empty quantity or spares clears it.
  Future<void> updateEquipmentItem({
    required String id,
    required String category,
    required String name,
    int? quantity,
    int? spares,
    required String performedBy,
  }) {
    return _db.equipmentDao.updateTemplateItem(
      id: id,
      category: category,
      name: name,
      quantity: quantity,
      spares: spares,
      clearQuantity: quantity == null,
      clearSpares: spares == null,
      performedBy: performedBy,
    );
  }

  Future<void> removeEquipmentItem({
    required String id,
    required String performedBy,
  }) {
    return _db.equipmentDao.deactivateTemplateItem(
      id: id,
      performedBy: performedBy,
    );
  }

  /// Stores the session's equipment snapshot (FR-PFT-09): every item of
  /// Tools and of each listed vehicle that [isPackable] keeps, with whether
  /// it was ticked. Lists not in [loadedLists] are read first (e.g. Save on
  /// step 1, before they were opened).
  Future<void> saveSessionEquipment({
    required String sessionId,
    required List<String> vehicleIds,
    required Map<String?, List<EquipmentTemplateItem>> loadedLists,
    required bool Function(EquipmentTemplateItem item) isPackable,
    required Set<String> packedItemIds,
    required String performedBy,
  }) async {
    final sessionVehicleIds = {
      for (final row in await _db.preFieldDao.getSessionVehicles(sessionId))
        row.vehicle.id: row.sessionVehicle.id,
    };

    final drafts = <SessionEquipmentDraft>[];
    // null = Tools, which belongs to no vehicle.
    for (final vehicleId in <String?>[null, ...vehicleIds]) {
      final sessionVehicleId = vehicleId == null
          ? null
          : sessionVehicleIds[vehicleId];
      if (vehicleId != null && sessionVehicleId == null) continue;
      final items =
          loadedLists[vehicleId] ??
          await getEquipmentList(vehicleId: vehicleId);
      for (final item in items.where(isPackable)) {
        drafts.add(
          SessionEquipmentDraft(
            sessionVehicleId: sessionVehicleId,
            templateItemId: item.id,
            category: item.category,
            name: item.name,
            quantity: item.quantity,
            spares: item.spares,
            isPacked: packedItemIds.contains(item.id),
            categoryOrder: item.categoryOrder,
            sortOrder: item.sortOrder,
          ),
        );
      }
    }

    await _db.equipmentDao.saveSessionEquipment(
      sessionId: sessionId,
      items: drafts,
      performedBy: performedBy,
    );
  }
}
