/// The team's standard payloads: written once, when the database is first
/// created. Afterwards payloads live in the `payloads` table.
///
/// [key] makes each payload's id (`payload:<key>`), the same on every
/// install. Never change or reuse a key.
typedef SeedPayload = ({
  String key,
  String name,
  String category,
  String? storageType,
  String? storageCapacity,

  /// Vehicle types it fits (MULTIROTOR / VTOL / FIXED_WING).
  List<String> vehicleTypes,

  /// Keys of the only fleet vehicles it fits ([] = any vehicle of a type
  /// above).
  List<String> onlyVehicles,
});

const _allTypes = ['MULTIROTOR', 'VTOL', 'FIXED_WING'];

const seedPayloads = <SeedPayload>[
  (
    key: 'jetson-orin-nano-8gb',
    name: 'Jetson Orin Nano 8GB',
    category: 'Companion Computer',
    storageType: 'SD card + NVMe SSD',
    storageCapacity: '64GB / 128GB SD',
    vehicleTypes: _allTypes,
    onlyVehicles: [],
  ),
  (
    key: 'pi-5-8gb',
    name: 'Pi 5 – 8GB',
    category: 'Companion Computer',
    storageType: 'SD card',
    storageCapacity: '64GB',
    vehicleTypes: _allTypes,
    onlyVehicles: [],
  ),
  (
    key: 'flir-camera-usb',
    name: 'FLIR Camera – USB',
    category: 'Mono Camera, RGB',
    storageType: null,
    storageCapacity: null,
    vehicleTypes: _allTypes,
    onlyVehicles: [],
  ),
  (
    key: 'lucid-camera-ethernet',
    name: 'Lucid Camera – Ethernet',
    category: 'RGB Camera',
    storageType: null,
    storageCapacity: null,
    vehicleTypes: _allTypes,
    onlyVehicles: [],
  ),
  (
    key: 'motion-metrics-ip-ethernet',
    name: 'Motion Metrics IP – Ethernet',
    category: 'Thermal',
    storageType: null,
    storageCapacity: null,
    vehicleTypes: ['MULTIROTOR', 'VTOL'],
    // Not Kari (for now).
    onlyVehicles: ['dorsata', 'cerana'],
  ),
];
