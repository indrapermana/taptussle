import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

void main() {
  const effects = {
    'click': (600.0, .045, 26.0),
    'paddle_hit': (330.0, .06, 18.0),
    'score': (880.0, .12, 14.0),
    'result': (1040.0, .22, 8.0),
  };
  final directory = Directory('assets/sounds')..createSync(recursive: true);
  for (final entry in effects.entries) {
    final (frequency, duration, decay) = entry.value;
    File('${directory.path}/${entry.key}.wav').writeAsBytesSync(
      _wave(frequency: frequency, duration: duration, decay: decay),
    );
  }
}

Uint8List _wave({
  required double frequency,
  required double duration,
  required double decay,
}) {
  const sampleRate = 44100;
  final frames = (sampleRate * duration).round();
  final bytes = ByteData(44 + frames * 2);
  bytes
    ..setUint32(0, 0x46464952, Endian.little)
    ..setUint32(4, 36 + frames * 2, Endian.little)
    ..setUint32(8, 0x45564157, Endian.little)
    ..setUint32(12, 0x20746d66, Endian.little)
    ..setUint32(16, 16, Endian.little)
    ..setUint16(20, 1, Endian.little)
    ..setUint16(22, 1, Endian.little)
    ..setUint32(24, sampleRate, Endian.little)
    ..setUint32(28, sampleRate * 2, Endian.little)
    ..setUint16(32, 2, Endian.little)
    ..setUint16(34, 16, Endian.little)
    ..setUint32(36, 0x61746164, Endian.little)
    ..setUint32(40, frames * 2, Endian.little);
  for (var frame = 0; frame < frames; frame++) {
    final time = frame / sampleRate;
    final envelope = math.exp(-decay * time / duration);
    final sample =
        (math.sin(2 * math.pi * frequency * time) * envelope * 0.28 * 32767)
            .round();
    bytes.setInt16(44 + frame * 2, sample, Endian.little);
  }
  return bytes.buffer.asUint8List();
}
