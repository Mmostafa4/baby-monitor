import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';

/// Captures microphone audio locally and exposes an in-memory WAV preview.
class CryRecordingService {
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<dynamic>? _subscription;
  BytesBuilder _audioData = BytesBuilder(copy: false);
  bool _hasPendingCleanup = false;
  Object? _streamError;
  int _capturedBytes = 0;

  bool get hasPendingCleanup => _hasPendingCleanup;
  int get capturedBytes => _capturedBytes;
  Object? get streamError => _streamError;

  Future<void> start() async {
    if (_hasPendingCleanup) await cancel();

    if (!await _recorder.hasPermission()) {
      throw const CryRecordingException(
        'لم يُمنح إذن الميكروفون. اسمحي به من إعدادات Safari ثم أعيدي المحاولة.',
      );
    }

    if (await _recorder.isRecording()) {
      throw const CryRecordingException('يوجد تسجيل جارٍ بالفعل.');
    }

    _audioData = BytesBuilder(copy: false);
    _capturedBytes = 0;
    _streamError = null;

    try {
      final stream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          numChannels: 1,
          sampleRate: 16000,
        ),
      );
      _hasPendingCleanup = true;
      _subscription = stream.listen(
        (chunk) {
          _capturedBytes += chunk.length;
          _audioData.add(chunk);
        },
        onError: (Object error) {
          _streamError = error;
        },
      );
    } catch (_) {
      try {
        await _recorder.cancel();
        _hasPendingCleanup = false;
      } catch (_) {
        _hasPendingCleanup = true;
      }
      rethrow;
    }
  }

  /// Stops the microphone and returns captured PCM as a WAV held in memory.
  Future<Uint8List?> stopAndGetWav() async {
    final isRecording = await _recorder.isRecording();
    if (!isRecording && !_hasPendingCleanup) return null;

    try {
      await _recorder.stop();
      await _subscription?.cancel();
      _subscription = null;
      _hasPendingCleanup = false;
      final pcm = _audioData.takeBytes();
      _audioData = BytesBuilder(copy: false);
      if (pcm.isEmpty) return null;
      return _wavFromPcm16(pcm);
    } catch (_) {
      _hasPendingCleanup = true;
      throw const CryRecordingException(
        'تعذر إنهاء التسجيل. تحققي من الميكروفون وحاولي مرة أخرى.',
      );
    }
  }

  Uint8List _wavFromPcm16(Uint8List pcm) {
    const sampleRate = 16000;
    const channels = 1;
    const bitsPerSample = 16;
    const blockAlign = channels * bitsPerSample ~/ 8;
    const byteRate = sampleRate * blockAlign;

    final wav = Uint8List(44 + pcm.length);
    final header = ByteData.sublistView(wav);
    void writeText(int offset, String value) {
      for (var index = 0; index < value.length; index++) {
        wav[offset + index] = value.codeUnitAt(index);
      }
    }

    writeText(0, 'RIFF');
    header.setUint32(4, 36 + pcm.length, Endian.little);
    writeText(8, 'WAVE');
    writeText(12, 'fmt ');
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little);
    header.setUint16(22, channels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, blockAlign, Endian.little);
    header.setUint16(34, bitsPerSample, Endian.little);
    writeText(36, 'data');
    header.setUint32(40, pcm.length, Endian.little);
    wav.setRange(44, wav.length, pcm);
    return wav;
  }

  Future<void> cancel() async {
    final isRecording = await _recorder.isRecording();
    if (!isRecording && !_hasPendingCleanup) return;

    try {
      await _recorder.cancel();
      await _subscription?.cancel();
      _subscription = null;
      _audioData.takeBytes();
      _hasPendingCleanup = false;
    } catch (_) {
      _hasPendingCleanup = true;
      throw const CryRecordingException(
        'تعذر إيقاف التسجيل. أغلقي الصفحة ثم أعيدي المحاولة.',
      );
    }
  }

  Future<void> dispose() async {
    try {
      await cancel();
    } finally {
      await _recorder.dispose();
    }
  }
}

class CryRecordingException implements Exception {
  final String message;
  const CryRecordingException(this.message);

  @override
  String toString() => message;
}
