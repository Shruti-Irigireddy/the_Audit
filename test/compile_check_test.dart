// Fast compile check: importing these screens makes `flutter test` compile
// them (and everything they import), catching type errors when the full
// analyzer is too slow.
import 'package:flutter_test/flutter_test.dart';
import 'package:the_audit/features/dashboard/presentation/home.dart';
import 'package:the_audit/features/auth/presentation/login.dart';
import 'package:the_audit/features/pre_field/presentation/pre-field.dart';
import 'package:the_audit/features/pre_field/presentation/session_screen.dart';
import 'package:the_audit/features/pre_flight/presentation/pre-flight.dart';
import 'package:the_audit/features/post_flight/presentation/post-flight.dart';
import 'package:the_audit/features/vehicle/presentation/add_vehicle.dart';
import 'package:the_audit/features/vehicle/presentation/cubit/vehicle_cubit.dart';

void main() {
  test('screens compile', () {
    expect(CreateSessionPage, isNotNull);
    expect(HomePage, isNotNull);
    expect(LoginPage, isNotNull);
    expect(SessionScreen, isNotNull);
    expect(PreFlightChecklistPage, isNotNull);
    expect(PostFlightNotesPage, isNotNull);
    expect(AddVehicle, isNotNull);
    expect(VehicleCubit, isNotNull);
  });
}
