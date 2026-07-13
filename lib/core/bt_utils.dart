String bytesToHex(List<int> bytes) {
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
  final ascii = String.fromCharCodes(bytes.where((b) => b >= 32 && b < 127));
  return '$hex${ascii.isNotEmpty ? ' ("$ascii")' : ''}';
}
