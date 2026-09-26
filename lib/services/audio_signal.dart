import 'dart:math' as math;
import 'dart:typed_data';

/// Lightweight quality check for the locally captured PCM stream.
///
/// This only answers “did the microphone capture a non-silent signal?” It does
/// not detect a cry, identify a cause, or measure a medical vital sign.
class AudioSignalQuality {
  final int peakAmplitude;
  final double rmsAmplitude;
  final double activeRatio;

  const AudioSignalQuality({
    required this.peakAmplitude,
    required this.rmsAmplitude,
    required this.activeRatio,
  });

  bool get hasAudibleSignal =>
      peakAmplitude >= 384 && rmsAmplitude >= 96 && activeRatio >= 0.001;
}

AudioSignalQuality inspectPcm16(Uint8List pcm) {
  if (pcm.length < 2 || pcm.length.isOdd) {
    return const AudioSignalQuality(
      peakAmplitude: 0,
      rmsAmplitude: 0,
      activeRatio: 0,
    );
  }

  final data = ByteData.sublistView(pcm);
  var peak = 0;
  var activeSamples = 0;
  var sumSquares = 0.0;
  final sampleCount = pcm.length ~/ 2;
  for (var offset = 0; offset < pcm.length; offset += 2) {
    final sample = data.getInt16(offset, Endian.little);
    final absolute = sample.abs();
    if (absolute > peak) peak = absolute;
    if (absolute >= 256) activeSamples++;
    sumSquares += sample * sample;
  }

  return AudioSignalQuality(
    peakAmplitude: peak,
    rmsAmplitude: math.sqrt(sumSquares / sampleCount),
    activeRatio: activeSamples / sampleCount,
  );
}

bool hasAudiblePcm16Signal(Uint8List pcm) => inspectPcm16(pcm).hasAudibleSignal;

bool hasAudibleWavSignal(Uint8List wav) {
  if (wav.length <= 44 ||
      wav[0] != 0x52 ||
      wav[1] != 0x49 ||
      wav[2] != 0x46 ||
      wav[3] != 0x46 ||
      wav[8] != 0x57 ||
      wav[9] != 0x41 ||
      wav[10] != 0x56 ||
      wav[11] != 0x45) {
    return false;
  }
  return hasAudiblePcm16Signal(wav.sublist(44));
}
