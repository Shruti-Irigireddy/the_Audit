/// A vehicle's type: the one shared definition for the whole app. Stored in
/// the database as [dbValue] (MULTIROTOR / VTOL / FIXED_WING).
enum VehicleType {
  multirotor('Multirotor', 'MULTIROTOR'),
  vtol('VTOL', 'VTOL'),
  fixedWing('Fixed wing', 'FIXED_WING');

  final String label;
  final String dbValue;

  const VehicleType(this.label, this.dbValue);

  String get imageAsset => switch (this) {
    VehicleType.multirotor => 'assets/images/vehicles/multirotor.png',
    VehicleType.vtol => 'assets/images/vehicles/vtol.png',
    VehicleType.fixedWing => 'assets/images/vehicles/fixed_wing.png',
  };

  static VehicleType? fromDb(String value) {
    for (final type in values) {
      if (type.dbValue == value.toUpperCase()) return type;
    }
    return null;
  }
}
