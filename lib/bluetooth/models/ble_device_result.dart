class BleDeviceResult {
  final String deviceId;
  final String name;
  final int rssi;
  final bool isConnectable;
  final List<String> serviceUuids;
  final String? manufacturerInfo;
  final DateTime lastSeen;
  final bool isSimulated;

  const BleDeviceResult({
    required this.deviceId,
    required this.name,
    required this.rssi,
    required this.isConnectable,
    required this.serviceUuids,
    this.manufacturerInfo,
    required this.lastSeen,
    this.isSimulated = false,
  });

  bool get hasName => name.isNotEmpty;

  String get displayName => hasName ? name : 'Bilinmeyen Cihaz';

  bool get isTachographDevice {
    final n = name.toLowerCase();
    if (n.contains('tachograph') || n.contains('takograf')) return true;
    // BLE adaptörler için: SPP servis UUID'si K-LINE köprüsü işareti
    // (isim reklam paketinde olmasa bile UUID'den tespit yapılabilir)
    const sppUuid = '00001101-0000-1000-8000-00805F9B34FB';
    return serviceUuids.any((u) => u.toUpperCase() == sppUuid);
  }

  BleDeviceResult copyWith({int? rssi, DateTime? lastSeen}) {
    return BleDeviceResult(
      deviceId: deviceId,
      name: name,
      rssi: rssi ?? this.rssi,
      isConnectable: isConnectable,
      serviceUuids: serviceUuids,
      manufacturerInfo: manufacturerInfo,
      lastSeen: lastSeen ?? this.lastSeen,
      isSimulated: isSimulated,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is BleDeviceResult && other.deviceId == deviceId;

  @override
  int get hashCode => deviceId.hashCode;
}
