/// The team's standard "equipment to bring" lists (from the team's sheets):
/// Tools for every session, plus each fleet vehicle's list. Written once,
/// when the database is first created; afterwards the lists are edited in
/// Create session. "4+1" counts are stored as 5.
///
/// Each item's id comes from its list and name
/// (`equipment:<vehicle key or tools>:<category>:<name>`), not its position,
/// so reordering items is safe. Renaming an item gives it a new id on new
/// installs only.
library;

/// (name, quantity, spares); null = blank on the sheet.
typedef SeedEquipmentItem = (String, int?, int?);

/// (category, items) in display order.
typedef SeedEquipmentCategory = (String, List<SeedEquipmentItem>);

/// Tools: taken to every session, whatever the vehicles.
const seedTools = <SeedEquipmentItem>[
  ('Tweezers', 1, null),
  ('Nipper', 1, null),
  ('Nose Plier', 1, null),
  ('Cutting Plier', 1, null),
  ('Bosch Kit', 1, null),
  ('Cutter', 1, null),
  ('GF Tape', 2, null),
  ('3M Tape', 1, null),
  ('Double Sided Tape', 1, null),
  ('Insulation tape', 1, null),
  ('Stapler', 1, null),
  ('Chordless Drill', 1, null),
  ('Drill bit set', 1, null),
  ('Zip Ties Set', 3, null),
  ('MobileTripod', 1, null),
  ('RTK Tripod(If required)', 1, null),
  ('Alen key set', 1, null),
  ('Heat Shrink Set', 1, null),
  ('Gas Torch', 1, null),
  ('Multimeter', 1, null),
  ('Clampmeter', 1, null),
  ('Temperature gun', 1, null),
  ('Rubber Bands', null, null),
  ('Soldering iron', 1, null),
  ('Soldering tin lead', 1, null),
  ('Soldering Flux', 1, null),
  ('Feviquick', 1, null),
];
const _powerSystems = <SeedEquipmentItem>[
  ('Batteries', null, null),
  ('Battery Charger', 1, null),
  ('Battery Charging Chord', 1, null),
  ('Battery XT60 to XT90 Connectors', 2, null),
  ('Power Station', 1, null),
  ('Power Station Chord', 1, null),
  ('Power Station plug extension', 1, null),
];
const _elrsP900Comms = <SeedEquipmentItem>[
  ('Transmitter MKIII', 1, null),
  ('ELRS Module (In case of MKII)', 1, null),
  ('ELRS receiver', 1, null),
  ('ELRS Antennas', 2, null),
  ('P900 Air unit', 1, null),
  ('P900 Ground unit', 1, null),
  ('P900 Antenas', 2, null),
  ('3S Battery', 1, null),
  ('3S Battery Connector', 1, null),
  ('Type C-USB Cable', 1, null),
];

/// Each fleet vehicle's list, by its key in `seedFleet`.
const seedVehicleEquipment = <String, List<SeedEquipmentCategory>>{
  'kari': [
    (
      'Airframe',
      [
        ('Drone Frame', 1, null),
        ('Motors', 4, null),
        ('Propellers', 4, 4),
        ('Propeller Bolts(If props are not installed)', 4, null),
        ('Battery Straps', 2, null),
      ],
    ),
    (
      'Subsystems',
      [('GPS', 1, 1), ('Battery XT60 to XT90 connector', 2, null)],
    ),
    (
      'Communication Systems',
      [
        ('Transmitter MKII', 1, null),
        ('PPM receiver', 1, null),
        ('P900 Antennas AU', 2, null),
        ('RFD900 Air unit', 1, null),
        ('RFD900 Ground unit', 1, null),
        ('RFD900 Antenas GU', 2, null),
      ],
    ),
    ('Power Systems', _powerSystems),
  ],
  'dorsata': [
    (
      'Airframe',
      [
        ('Drone Frame', 1, null),
        ('Motors', 4, null),
        ('Propellers', 4, 4),
        ('Propeller Bolts(If props are not installed)', 4, null),
        ('Battery Straps', 2, null),
      ],
    ),
    (
      'Subsystems',
      [
        ('GPS', 1, 1),
        ('Battery Y Splitter', 1, null),
        ('Battery XT60 to XT90 connector', 2, null),
      ],
    ),
    ('Communication Systems', _elrsP900Comms),
    ('Power Systems', _powerSystems),
  ],
  'cerana': _ceranaAndStriver,
  // Same list as Cerana (its own copy: editing one doesn't change the other).
  'striver': _ceranaAndStriver,
};

/// Cerana's list, also used for Striver.
const _ceranaAndStriver = <SeedEquipmentCategory>[
  (
    'Airframe',
    [
      ('Fuselage', 1, null),
      ('Wings', 2, null),
      ('Spars', 2, null),
      ('Motors', 5, null), // 4+1
      ('Propellers', 5, 5), // 4+1, spares 4+1
      ('Propeller Bolts(If props are not installed)', 5, null), // 4+1
      ('Pusher Motor Bolt', 1, null),
      ('Battery Straps', 2, null),
      ('Canopies', 2, null),
      ('Canopy Bolts', null, null),
    ],
  ),
  (
    'Subsystems',
    [
      ('GPS', 1, 1),
      ('Airspeed Sensor cap', 1, null),
      ('Battery Y Splitter', 1, null),
      ('Battery XT60 to XT90 connector', 2, null),
    ],
  ),
  ('Communication Systems', _elrsP900Comms),
  ('Power Systems', _powerSystems),
];
