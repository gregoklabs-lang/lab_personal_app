class DeviceSummary {
  const DeviceSummary({
    required this.rowId,
    required this.deviceId,
    required this.name,
  });

  final String rowId;
  final String deviceId;
  final String name;

  DeviceSummary copyWith({String? rowId, String? deviceId, String? name}) {
    return DeviceSummary(
      rowId: rowId ?? this.rowId,
      deviceId: deviceId ?? this.deviceId,
      name: name ?? this.name,
    );
  }
}
