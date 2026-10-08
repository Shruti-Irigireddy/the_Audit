/// App-wide timings, in one place to tune.
class AppConfig {
  /// How long the splash logo zooms before login / home shows.
  static const splashDuration = Duration(milliseconds: 2500);

  /// How long to wait for the team list from Firestore before using the
  /// users saved on the phone.
  static const userSyncTimeout = Duration(seconds: 10);

  /// How long to wait for a fresh GPS fix before keeping the last known
  /// position.
  static const gpsFixTimeLimit = Duration(seconds: 15);

  /// A typed checklist value saves this long after typing stops.
  static const valueSaveDelay = Duration(milliseconds: 500);
}
