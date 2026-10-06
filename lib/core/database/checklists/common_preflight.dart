/// Response types a checklist item can have.
class ChecklistResponseTypes {
  /// Pass or Fail.
  static const passFail = 'PASS_FAIL';

  /// Pass or Not applicable.
  static const passNa = 'PASS_NA';

  /// Pass only (a confirmation).
  static const passOnly = 'PASS_ONLY';

  /// A value to enter as text (e.g. GPS sat count / HDOP).
  static const value = 'VALUE';

  /// A number to enter, decimals allowed (e.g. battery start voltage).
  static const number = 'NUMBER';

  /// Pass or Fail, plus an optional value (e.g. RSSI).
  static const passFailValue = 'PASS_FAIL_VALUE';

  /// Older templates: Pass, Fail or N/A.
  static const passFailNa = 'PASS_FAIL_NA';

  static const all = {
    passFail,
    passNa,
    passOnly,
    value,
    number,
    passFailValue,
    passFailNa,
  };
}

/// One checklist item definition. `blocksArming` marks the SRS [A] items.
typedef PreflightItem = ({
  String section,
  String label,
  String responseType,
  bool blocksArming,
});

/// SRS §5.1 Common Preflight: loads for every vehicle. `blocksArming` marks
/// the [A] items (block arming by default).
const commonPreflightChecklist = <PreflightItem>[
  (
    section: 'Documentation',
    label: 'Mission / objective confirmed for this flight',
    responseType: ChecklistResponseTypes.passNa,
    blocksArming: false,
  ),
  (
    section: 'Documentation',
    label: 'Airspace & permissions OK for site',
    responseType: ChecklistResponseTypes.passOnly,
    blocksArming: true,
  ),
  (
    section: 'Airframe',
    label: 'Frame, booms, fasteners inspected — secure, no damage',
    responseType: ChecklistResponseTypes.passFail,
    blocksArming: true,
  ),
  (
    section: 'Airframe',
    label: 'Props / rotors secure, correct, undamaged (where applicable)',
    responseType: ChecklistResponseTypes.passFail,
    blocksArming: true,
  ),
  (
    section: 'Power',
    label: 'Battery installed & secured; start voltage logged',
    responseType: ChecklistResponseTypes.number,
    blocksArming: true,
  ),
  (
    section: 'Payload',
    label: 'Payload mounted & secured; lens / sensor clean',
    responseType: ChecklistResponseTypes.passFail,
    blocksArming: false,
  ),
  (
    section: 'Payload',
    label: 'Storage present with free space; test capture OK',
    responseType: ChecklistResponseTypes.passFail,
    blocksArming: false,
  ),
  (
    section: 'Comms',
    label: 'GCS connected',
    responseType: ChecklistResponseTypes.passFail,
    blocksArming: true,
  ),
  (
    section: 'Comms',
    label: 'Telemetry link established, signal acceptable',
    responseType: ChecklistResponseTypes.passFailValue,
    blocksArming: true,
  ),
  (
    section: 'Comms',
    label: 'RC link established, sticks / switches respond',
    responseType: ChecklistResponseTypes.passFail,
    blocksArming: true,
  ),
  (
    section: 'Navigation',
    label: 'GPS fix acquired — sat count / HDOP logged',
    responseType: ChecklistResponseTypes.value,
    blocksArming: true,
  ),
  (
    section: 'Navigation',
    label: 'Compass / IMU healthy, aircraft level',
    responseType: ChecklistResponseTypes.passFail,
    blocksArming: true,
  ),
  (
    section: 'Navigation',
    label: 'Home point set',
    responseType: ChecklistResponseTypes.passFail,
    blocksArming: true,
  ),
  (
    section: 'Safety',
    label: 'Failsafe (RTL / RTH) configured (link-loss, low-battery, fence)',
    responseType: ChecklistResponseTypes.passFail,
    blocksArming: true,
  ),
  (
    section: 'Safety',
    label: 'Geofence set (if used)',
    responseType: ChecklistResponseTypes.passNa,
    blocksArming: false,
  ),
  (
    section: 'Safety',
    label: 'Flight modes verified on switches',
    responseType: ChecklistResponseTypes.passFail,
    blocksArming: true,
  ),
  (
    section: 'Environment',
    label: 'Weather within limits (wind, visibility, precip)',
    responseType: ChecklistResponseTypes.passFail,
    blocksArming: true,
  ),
];

/// SRS §5.2 Quad / Multirotor: additional items.
const multirotorPreflightChecklist = <PreflightItem>[
  (
    section: 'Multirotor',
    label: 'Motor spin / direction test',
    responseType: ChecklistResponseTypes.passFail,
    blocksArming: true,
  ),
  (
    section: 'Multirotor',
    label: 'Prop orientation correct (CW / CCW positions)',
    responseType: ChecklistResponseTypes.passFail,
    blocksArming: true,
  ),
  (
    section: 'Multirotor',
    label: 'Arm / boom locks engaged (folding frames)',
    responseType: ChecklistResponseTypes.passFail,
    blocksArming: true,
  ),
  (
    section: 'Multirotor',
    label: 'Landing gear secure',
    responseType: ChecklistResponseTypes.passFail,
    blocksArming: false,
  ),
  (
    section: 'Multirotor',
    label: 'CG balanced',
    responseType: ChecklistResponseTypes.passFail,
    blocksArming: false,
  ),
];

/// SRS §5.3 VTOL: additional items (superset of multirotor lift checks).
const vtolPreflightChecklist = <PreflightItem>[
  (
    section: 'VTOL',
    label: 'All lift-motor checks (as multirotor)',
    responseType: ChecklistResponseTypes.passFail,
    blocksArming: true,
  ),
  (
    section: 'VTOL',
    label: 'Forward / pusher motor & prop secure and clear',
    responseType: ChecklistResponseTypes.passFail,
    blocksArming: true,
  ),
  (
    section: 'VTOL',
    label:
        'Control surfaces (aileron / elevator / rudder / ruddervator) free & correct direction',
    responseType: ChecklistResponseTypes.passFail,
    blocksArming: true,
  ),
  (
    section: 'VTOL',
    label: 'Pitot / airspeed sensor clear & reading valid',
    responseType: ChecklistResponseTypes.passFail,
    blocksArming: true,
  ),
  (
    section: 'VTOL',
    label: 'Transition parameters / Q-assist confirmed',
    responseType: ChecklistResponseTypes.passFail,
    blocksArming: true,
  ),
  (
    section: 'VTOL',
    label: 'Transition altitude set',
    responseType: ChecklistResponseTypes.passFail,
    blocksArming: false,
  ),
  (
    section: 'VTOL',
    label: 'CG within fixed-wing envelope (critical)',
    responseType: ChecklistResponseTypes.passFail,
    blocksArming: true,
  ),
];

/// SRS §5.4 Fixed Wing: additional items.
const fixedWingPreflightChecklist = <PreflightItem>[
  (
    section: 'Fixed wing',
    label: 'Control surfaces free, correct direction & throw',
    responseType: ChecklistResponseTypes.passFail,
    blocksArming: true,
  ),
  (
    section: 'Fixed wing',
    label: 'Pitot tube uncapped; airspeed reading valid',
    responseType: ChecklistResponseTypes.passFail,
    blocksArming: true,
  ),
  (
    section: 'Fixed wing',
    label: 'CG check (critical)',
    responseType: ChecklistResponseTypes.passFail,
    blocksArming: true,
  ),
  (
    section: 'Fixed wing',
    label: 'Launch method ready (hand / bungee / catapult / runway)',
    responseType: ChecklistResponseTypes.passFail,
    blocksArming: true,
  ),
  (
    section: 'Fixed wing',
    label: 'Throttle cut / safe state on launch',
    responseType: ChecklistResponseTypes.passFail,
    blocksArming: true,
  ),
  (
    section: 'Fixed wing',
    label: 'Prop secure & propeller arc clear',
    responseType: ChecklistResponseTypes.passFail,
    blocksArming: true,
  ),
  (
    section: 'Fixed wing',
    label: 'Tail / empennage secure',
    responseType: ChecklistResponseTypes.passFail,
    blocksArming: false,
  ),
];

/// The extra items for a vehicle type (MULTIROTOR / VTOL / FIXED_WING);
/// empty for other types.
List<PreflightItem> typePreflightChecklist(String vehicleType) =>
    switch (vehicleType.trim().toUpperCase()) {
      'MULTIROTOR' => multirotorPreflightChecklist,
      'VTOL' => vtolPreflightChecklist,
      'FIXED_WING' => fixedWingPreflightChecklist,
      _ => const [],
    };

/// Section name of the Ready-to-Arm gate.
const readyToArmSection = 'Ready to Arm';

/// SRS §5.5 Ready-to-Arm gate: the final section for every vehicle. (The
/// sheet's last row, "Final Go / No-Go", is the decision step itself, not a
/// checklist item.)
const readyToArmGateChecklist = <PreflightItem>[
  (
    section: readyToArmSection,
    label: 'Take-off / landing area clear',
    responseType: ChecklistResponseTypes.passOnly,
    blocksArming: true,
  ),
  (
    section: readyToArmSection,
    label: 'Team & bystanders at safe distance',
    responseType: ChecklistResponseTypes.passOnly,
    blocksArming: true,
  ),
  (
    section: readyToArmSection,
    label: 'VO in position, eyes on aircraft / airspace',
    responseType: ChecklistResponseTypes.passOnly,
    blocksArming: true,
  ),
  (
    section: readyToArmSection,
    label: 'PIC confirms airspace clear',
    responseType: ChecklistResponseTypes.passOnly,
    blocksArming: true,
  ),
  (
    section: readyToArmSection,
    label: 'Logging / recording started',
    responseType: ChecklistResponseTypes.passNa,
    blocksArming: false,
  ),
];

/// A vehicle's full pre-flight checklist: common items, its type's items,
/// then the Ready-to-Arm gate.
List<PreflightItem> preflightChecklistFor(String vehicleType) => [
  ...commonPreflightChecklist,
  ...typePreflightChecklist(vehicleType),
  ...readyToArmGateChecklist,
];
