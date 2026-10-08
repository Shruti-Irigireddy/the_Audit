import 'package:the_audit/features/battery/domain/entities/battery_entity.dart';
import 'package:the_audit/features/payload/domain/entities/payload_entity.dart';
import 'package:the_audit/features/pre_flight/domain/dtos/pre_flight_dtos.dart';
import 'package:the_audit/features/pre_flight/domain/entities/checklist_override_entity.dart';
import 'package:the_audit/features/pre_flight/domain/entities/checklist_response_entity.dart';
import 'package:the_audit/features/pre_flight/domain/entities/pre_flight_setup_entity.dart';
import 'package:the_audit/features/pre_flight/domain/entities/ready_to_arm_validation_result_entity.dart';
import 'package:the_audit/features/pre_flight/domain/entities/sortie_battery_entity.dart';
import 'package:the_audit/features/pre_flight/domain/entities/sortie_entity.dart';
import 'package:the_audit/features/pre_flight/domain/entities/sortie_payload_entity.dart';
import 'package:the_audit/features/pre_flight/domain/entities/sortie_user_entity.dart';
import 'package:the_audit/features/vehicle/domain/entities/checklist_item_entity.dart';

abstract class PreFlightRepository {
  Future<String> createSortie({
    String? flightId,
    required String sessionId,
    required String sessionVehicleId,
    required String picUserId,
    String? objective,
    required String performedBy,
    List<String> selectedPayloadIds,
  });

  Future<SortieEntity?> getSortieById(String flightId);

  Future<List<SortieEntity>> getSortiesForSession(String sessionId);

  /// The session's sorties, updated live.
  Stream<List<SortieEntity>> watchSortiesForSession(String sessionId);

  Future<PreFlightSetupEntity> getPreFlightSetup(String flightId);

  Future<void> updateSortieBasicInfo({
    required String flightId,
    String? picUserId,
    String? objective,
    required String performedBy,
  });

  Future<void> addUserToSortie({
    required String flightId,
    required String userId,
    required String role,
    required String performedBy,
  });

  Future<void> removeUserFromSortie({
    required String flightId,
    required String userId,
    required String role,
    required String performedBy,
  });

  Future<void> replaceSortieUsers({
    required String flightId,
    required List<SortieUserDraft> users,
    required String performedBy,
  });

  Future<List<SortieUserWithUserEntity>> getSortieUsers(String flightId);

  Future<List<PayloadEntity>> getSelectablePayloadsForSortie(String flightId);

  Future<void> addPayloadToSortie({
    required String flightId,
    required String payloadId,
    required String createdBy,
  });

  Future<void> removePayloadFromSortie({
    required String flightId,
    required String payloadId,
    required String performedBy,
  });

  Future<void> replaceSortiePayloads({
    required String flightId,
    required List<String> payloadIds,
    required String performedBy,
  });

  Future<List<SortiePayloadWithPayloadEntity>> getSortiePayloads(
    String flightId,
  );

  Future<List<BatteryEntity>> getSelectableBatteriesForSortie(String flightId);

  Future<void> addBatteryToSortie({
    required String flightId,
    required String batteryId,
    double? voltageStart,
    int? percentStart,
    required String createdBy,
  });

  Future<void> replaceAllSortieBatteries({
    required String flightId,
    required List<SortieBatteryDraft> batteries,
    required String performedBy,
  });

  Future<void> replaceSortieBattery({
    required String flightId,
    required String oldBatteryId,
    required String newBatteryId,
    double? voltageStart,
    int? percentStart,
    required String performedBy,
  });

  Future<void> updateSortieBatteryStartState({
    required String flightId,
    required String batteryId,
    double? voltageStart,
    int? percentStart,
    required String performedBy,
  });

  Future<void> removeBatteryFromSortie({
    required String flightId,
    required String batteryId,
    required String performedBy,
  });

  Future<List<SortieBatteryWithBatteryEntity>> getSortieBatteries(
    String flightId,
  );

  Future<BatteryStartDefaults?> getLatestBatteryEndStateAsStartDefault({
    required String batteryId,
    String? excludeFlightId,
  });

  Future<List<ChecklistItemEntity>> loadChecklistForSortie(String flightId);

  Future<List<ChecklistItemEntity>> loadBlockingChecklistItemsForSortie(
    String flightId,
  );

  Future<void> saveChecklistResponse({
    required String flightId,
    required String itemId,
    required String response,
    String? valueText,
    double? valueNumber,
    String? notes,
    required String createdBy,
  });

  Future<void> saveChecklistResponses({
    required String flightId,
    required List<ChecklistResponseDraft> responses,
    required String createdBy,
  });

  Future<List<ChecklistResponseWithItemEntity>> getChecklistResponsesForFlight(
    String flightId,
  );

  Future<ReadyToArmValidationResultEntity> validateReadyToArm(String flightId);

  Future<List<String>> validatePreflightCompletion(String flightId);

  Future<void> createChecklistOverride({
    required String flightId,
    required String itemId,
    required String overriddenReason,
    required String overriddenBy,
  });

  Future<List<ChecklistOverrideEntity>> getOverridesForFlight(String flightId);

  Future<void> submitGoNoGoDecision({
    required String flightId,
    required String finalDecision,
    String? decisionReason,
    required String decisionBy,
  });

  Future<void> markFlightInProgress({
    required String flightId,
    DateTime? takeoffAt,
    required String performedBy,
  });

  Future<void> recordLanding({
    required String flightId,
    DateTime? landingAt,
    required String performedBy,
  });

  Future<void> abortSortie({
    required String flightId,
    required String reason,
    required String performedBy,
  });
}
