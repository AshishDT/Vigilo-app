import 'dart:math';

final Random _random = Random();

String generateId() {
  final now = DateTime.now().microsecondsSinceEpoch;
  final rand = _random.nextInt(1 << 32);
  return '${now.toRadixString(36)}-${rand.toRadixString(36)}';
}
