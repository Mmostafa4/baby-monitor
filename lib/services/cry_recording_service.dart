import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';

import 'audio_activity.dart';

class CryRecordingService {
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _audioSubscription;
  bool _hasPendingCleanup = false;
  AudioActivity _activity = AudioActivity();

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
      _activity = AudioActivity();
      final audioStream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          numChannels: 1,
          sampleRate: 16000,
        ),
      );

      // Consume each chunk immediately and keep no audio bytes in memory.
      _audioSubscription = audioStream.listen(
        _activity.add,
        onError: (Object error) {
          _activity.failed = true;
        },
      );
      _hasPendingCleanup = true;
    } catch (_) {
      try {
        await _audioSubscription?.cancel();
        _audioSubscription = null;
        await _recorder.cancel();
        _hasPendingCleanup = false;
      } catch (_) {
        _hasPendingCleanup = true;
      }
      rethrow;
    }
  }

  /// Stop capture and discard it. This MVP has no analysis backend, so audio
  /// is never retained or uploaded.
  Future<bool> stopAndDelete() async {
    if (!_hasPendingCleanup && _audioSubscription == null) return false;
    await _cleanup();
    if (_activity.failed) {
      throw const CryRecordingException('انقطع استقبال الصوت. أعد التسجيل.');
    }
    return _activity.detected;
  }

  Future<void> _cleanup() async {
    try {
      await _recorder.stop();
      await _audioSubscription?.cancel();
      _audioSubscription = null;
      await _recorder.cancel();
      _hasPendingCleanup = false;
    } catch (_) {
      _hasPendingCleanup = true;
      throw const CryRecordingException(
        'تعذر إنهاء التسجيل بأمان. حاول مرة أخرى.',
      );
    }
  }

  Future<void> cancel() async {
    if (_hasPendingCleanup || _audioSubscription != null) await _cleanup();
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
