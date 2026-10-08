/// The team's standard fleet: written once, when the database is first
/// created. Afterwards vehicles live in (and are edited in) the `vehicles`
/// table; changing this list affects new installs only.
///
/// [key] makes each vehicle's id (`vehicle:<key>`), the same on every
/// install. Never change or reuse a key; a new vehicle needs a new key.
typedef SeedVehicle = ({
  String key,
  String name,
  String type,
  int motorCount,
  String frameMake,
  String frameModel,
});

const seedFleet = <SeedVehicle>[
  (
    key: 'cerana',
    name: 'Cerana',
    type: 'VTOL',
    motorCount: 5, // 4 lift + 1 pusher
    frameMake: 'Carbon composite',
    frameModel: 'Fixed',
  ),
  (
    key: 'dorsata',
    name: 'Dorsata',
    type: 'MULTIROTOR',
    motorCount: 4,
    frameMake: 'Carbon composite',
    frameModel: 'Fixed',
  ),
  (
    key: 'kari',
    name: 'Kari',
    type: 'MULTIROTOR',
    motorCount: 4,
    frameMake: 'Carbon fiber',
    frameModel: 'Fixed',
  ),
  (
    key: 'striver',
    name: 'Striver',
    type: 'VTOL',
    motorCount: 5, // 4 lift + 1 pusher
    frameMake: 'EPP and carbon',
    frameModel: 'Folding',
  ),
];
