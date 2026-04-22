String buildRequestId(String prefix) {
  final micros = DateTime.now().microsecondsSinceEpoch;
  final rand = DateTime.now().millisecondsSinceEpoch.remainder(100000);
  return '${prefix.toUpperCase()}_${micros}_$rand';
}
