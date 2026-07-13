class BleGattCharacteristic {
  final String uuid;
  final bool canRead;
  final bool canWrite;
  final bool canNotify;

  const BleGattCharacteristic({
    required this.uuid,
    required this.canRead,
    required this.canWrite,
    required this.canNotify,
  });

  String get propertiesLabel {
    final props = <String>[];
    if (canRead) props.add('Read');
    if (canWrite) props.add('Write');
    if (canNotify) props.add('Notify');
    return props.join(', ');
  }
}

class BleGattService {
  final String uuid;
  final List<BleGattCharacteristic> characteristics;

  const BleGattService({required this.uuid, required this.characteristics});
}
