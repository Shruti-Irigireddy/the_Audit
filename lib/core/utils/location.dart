import 'dart:async';

import 'package:geolocator/geolocator.dart';

import 'package:the_audit/core/config/app_config.dart';
import 'package:the_audit/core/errors/app_failure.dart';
import 'package:the_audit/core/utils/app_logger.dart';

const _log = AppLogger('Location');

/// The device's GPS position; works without internet.
///
/// Asks for permission when needed. [onQuickFix] gets the last known
/// position at once (when there is one) while a fresh fix is taken; if the
/// fresh fix times out, the last known one is returned. With
/// [openSettings], a disabled GPS or a permanently denied permission opens
/// the relevant settings screen.
///
/// Throws an [AppFailure] with a message for the user when no position can
/// be had.
Future<Position> currentPosition({
  void Function(Position position)? onQuickFix,
  bool openSettings = true,
}) async {
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  _log.d('location permission: ${permission.name}');
  if (permission == LocationPermission.denied) {
    throw const AppFailure('Location permission denied.');
  }
  if (permission == LocationPermission.deniedForever) {
    if (openSettings) await Geolocator.openAppSettings();
    throw const AppFailure(
      'Location permission is off for this app. Enable it in app settings.',
    );
  }
  if (!await Geolocator.isLocationServiceEnabled()) {
    if (openSettings) await Geolocator.openLocationSettings();
    throw const AppFailure('Location is turned off. Turn on GPS / location.');
  }

  final lastKnown = await Geolocator.getLastKnownPosition();
  if (lastKnown != null) onQuickFix?.call(lastKnown);

  try {
    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: AppConfig.gpsFixTimeLimit,
      ),
    );
  } on TimeoutException {
    if (lastKnown != null) {
      _log.w('fresh fix timed out; using last known position');
      return lastKnown;
    }
    throw const AppFailure(
      'Could not get a GPS fix in time. Try again in the open.',
    );
  }
}
