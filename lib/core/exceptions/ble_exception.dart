abstract class BleException implements Exception {
  final String layer;
  final String message;
  final Object? cause;

  const BleException({
    required this.layer,
    required this.message,
    this.cause,
  });

  @override
  String toString() {
    final causeStr = cause != null ? ' | cause: $cause' : '';
    return '[BLE:$layer] $message$causeStr';
  }
}
