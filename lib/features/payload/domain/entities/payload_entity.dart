class PayloadEntity {
  final String payloadId;
  final String name;
  final String category;
  final String? storageType;
  final String? storageCapacity;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PayloadEntity({
    required this.payloadId,
    required this.name,
    required this.category,
    this.storageType,
    this.storageCapacity,
    required this.createdAt,
    required this.updatedAt,  
  });

  bool get hasStorageInfo {
    return (storageType != null && storageType!.trim().isNotEmpty) ||
        (storageCapacity != null && storageCapacity!.trim().isNotEmpty);
  }
}