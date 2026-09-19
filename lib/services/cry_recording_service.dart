import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class CryRecordingService {
  final AudioRecorder _recorder = AudioRecorder();

  Future<bool> hasMicrophonePermission() => _recorder.hasPermission();

  Future<String?> recordTenSeconds() async {
    if (!await _recorder.hasPermission()) return null;
    final directory = await getTemporaryDirectory();
    final path = '${directory.path}/cry_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, numChannels: 1, sampleRate: 16000),
      path: path,
    );
    await Future<void>.delayed(const Duration(seconds: 10));
    final output = await _recorder.stop();
    if (output == null || !File(output).existsSync()) return null;
    return output;
  }

  Future<void> cancel() async {
    if (await _recorder.isRecording()) await _recorder.stop();
  }

  Future<void> dispose() => _recorder.dispose();
}
