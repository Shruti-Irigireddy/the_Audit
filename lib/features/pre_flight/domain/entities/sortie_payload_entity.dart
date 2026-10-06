import 'package:the_audit/features/payload/domain/entities/payload_entity.dart';

class SortiePayloadEntity {
  final String id;
  final String flightId;
  final String payloadId;
  final DateTime createdAt;

  const SortiePayloadEntity({
    required this.id,
    required this.flightId,
    required this.payloadId,
    required this.createdAt,
  });
}

class SortiePayloadWithPayloadEntity {
  final SortiePayloadEntity sortiePayload;
  final PayloadEntity payload;

  const SortiePayloadWithPayloadEntity({
    required this.sortiePayload,
    required this.payload,
  });
}
