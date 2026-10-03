import 'package:the_audit/core/database/daos/battery/battery_dao.dart';
import 'package:the_audit/core/utils/app_logger.dart';
import 'package:the_audit/features/battery/data/mappers/battery_mapper.dart';
import 'package:the_audit/features/battery/domain/entities/battery_entity.dart';
import 'package:the_audit/features/battery/domain/repositories/battery_repository.dart';

class BatteryRepositoryImpl implements BatteryRepository {
  static const _log = AppLogger('BatteryRepositoryImpl');

  final BatteryDao _batteryDao;

  const BatteryRepositoryImpl({required BatteryDao batteryDao})
    : _batteryDao = batteryDao;

  @override
  Future<String> createBattery({
    String? batteryId,
    required String config,
    int? capacity,
    double? voltage,
    int? cycleCount,
    String? status,
    required String performedBy,
  }) {
    _log.t('createBattery(batteryId: $batteryId, status: $status)');
    return _batteryDao.createBattery(
      batteryId: batteryId,
      config: config,
      capacity: capacity,
      voltage: voltage,
      cycleCount: cycleCount,
      status: status,
      performedBy: performedBy,
    );
  }

  @override
  Future<BatteryEntity?> getBatteryById(String batteryId) async {
    _log.t('getBatteryById(batteryId: $batteryId)');
    final battery = await _batteryDao.getBatteryById(batteryId);
    return battery?.toEntity();
  }

  @override
  Future<List<BatteryEntity>> getActiveBatteries() async {
    _log.t('getActiveBatteries()');
    final batteries = await _batteryDao.getAllActiveBatteries();
    _log.d('getActiveBatteries: ${batteries.length} items');
    return batteries.toEntities();
  }

  @override
  Future<List<BatteryEntity>> getAllBatteries() async {
    _log.t('getAllBatteries()');
    final batteries = await _batteryDao.getAllBatteries();
    _log.d('getAllBatteries: ${batteries.length} items');
    return batteries.toEntities();
  }

  @override
  Future<void> updateBattery({
    required String batteryId,
    String? config,
    int? capacity,
    double? voltage,
    int? cycleCount,
    String? status,
    required String performedBy,
  }) {
    _log.t('updateBattery(batteryId: $batteryId, status: $status)');
    return _batteryDao.updateBattery(
      batteryId: batteryId,
      config: config,
      capacity: capacity,
      voltage: voltage,
      cycleCount: cycleCount,
      status: status,
      performedBy: performedBy,
    );
  }

  @override
  Future<void> retireBattery({
    required String batteryId,
    required String performedBy,
  }) {
    _log.t('retireBattery(batteryId: $batteryId)');
    return _batteryDao.retireBattery(
      batteryId: batteryId,
      performedBy: performedBy,
    );
  }

  @override
  Future<void> incrementCycleCount({
    required String batteryId,
    required String performedBy,
  }) {
    _log.t('incrementCycleCount(batteryId: $batteryId)');
    return _batteryDao.incrementCycleCount(
      batteryId: batteryId,
      performedBy: performedBy,
    );
  }
}
