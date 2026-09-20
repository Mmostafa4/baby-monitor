import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:record/record.dart';

class CryRecordingService {
  final AudioRecorder _recorder = AudioRecorder();
  bool _hasPendingCleanup = false;

  bool get hasPendingCleanup => _hasPendingCleanup;

  Future<void> start() async {
    if (_hasPendingCleanup) await cancel();

    if (!await _recorder.hasPermission()) {
      throw const CryRecordingException('نحتاج إذن الميكروفون لبدء التسجيل.');
    }

    if (await _recorder.isRecording()) {
      throw const CryRecordingException('يوجد تسجيل جارٍ بالفعل.');
    }

    try {
      await _recorder.start(
        RecordConfig(
          encoder: kIsWeb ? AudioEncoder.wav : AudioEncoder.aacLc,
          numChannels: 1,
          sampleRate: 16000,
        ),
      );
      _hasPendingCleanup = true;
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

  /// Stop capture and discard the temporary audio. The MVP has no analysis
  /// backend, so recordings are never retained or uploaded.
  Future<void> stopAndDelete() async {
    final isRecording = await _recorder.isRecording();
    if (!isRecording && !_hasPendingCleanup) return;

    try {
      // cancel() stops capture and discards the temporary output on native and
      // web platforms. This MVP intentionally never keeps or uploads audio.
      await _recorder.cancel();
      _hasPendingCleanup = false;
    } catch (_) {
      _hasPendingCleanup = true;
      throw const CryRecordingException('تعذر إنهاء التسجيل بأمان. حاول مرة أخرى.');
    }
  }

  Future<void> cancel() => stopAndDelete();

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
