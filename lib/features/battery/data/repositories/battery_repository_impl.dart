import 'package:the_audit/core/database/daos/battery/battery_dao.dart';
import 'package:the_audit/features/battery/data/mappers/battery_mapper.dart';
import 'package:the_audit/features/battery/domain/entities/battery_entity.dart';
import 'package:the_audit/features/battery/domain/repositories/battery_repository.dart';

class BatteryRepositoryImpl implements BatteryRepository {
  final BatteryDao _batteryDao;

  const BatteryRepositoryImpl({
    required BatteryDao batteryDao,
  }) : _batteryDao = batteryDao;

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
    final battery = await _batteryDao.getBatteryById(batteryId);
    return battery?.toEntity();
  }

  @override
  Future<List<BatteryEntity>> getActiveBatteries() async {
    final batteries = await _batteryDao.getAllActiveBatteries();
    return batteries.toEntities();
  }

  @override
  Future<List<BatteryEntity>> getAllBatteries() async {
    final batteries = await _batteryDao.getAllBatteries();
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
    return _batteryDao.incrementCycleCount(
      batteryId: batteryId,
      performedBy: performedBy,
    );
  }
}