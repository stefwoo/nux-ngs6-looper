class MidiDevice {
  final int deviceId;
  final String deviceName;
  final int vendorId;
  final int productId;
  final bool hasPermission;

  MidiDevice({
    required this.deviceId,
    required this.deviceName,
    required this.vendorId,
    required this.productId,
    required this.hasPermission,
  });

  factory MidiDevice.fromMap(Map<String, dynamic> map) {
    return MidiDevice(
      deviceId: map['deviceId'] as int,
      deviceName: map['deviceName'] as String? ?? '未知设备',
      vendorId: map['vendorId'] as int,
      productId: map['productId'] as int,
      hasPermission: map['hasPermission'] as bool? ?? false,
    );
  }
}
