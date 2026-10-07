import 'dart:typed_data';

/// Detects audible PCM activity only. This does not identify a cry or its cause.
class AudioActivity {
  int samples = 0;
  int activeSamples = 0;
  int? _lowByte;
  bool failed = false;

  void add(Uint8List bytes) {
    for (final byte in bytes) {
      if (_lowByte == null) {
        _lowByte = byte;
      } else {
        var sample = _lowByte! | (byte << 8);
        if (sample >= 32768) sample -= 65536;
        samples++;
        if (sample.abs() >= 600) activeSamples++;
        _lowByte = null;
      }
    }
  }

  // Require at least one second captured and 100 ms above the noise threshold.
  bool get detected => !failed && samples >= 16000 && activeSamples >= 1600;
}
