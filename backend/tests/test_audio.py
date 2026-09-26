from io import BytesIO
import struct
import wave
import unittest

from app.audio import InvalidAudio, parse_mono_pcm16_wav


def make_wav(
    *,
    sample_rate: int = 16_000,
    frames_count: int = 160_000,
    channels: int = 1,
    sample_width: int = 2,
    sample_value: int = 0,
) -> bytes:
    if sample_width == 2:
        frame_data = struct.pack(
            "<h", sample_value
        ) * (frames_count * channels)
    else:
        frame_data = bytes(frames_count * channels * sample_width)
    output = BytesIO()
    with wave.open(output, "wb") as audio:
        audio.setnchannels(channels)
        audio.setsampwidth(sample_width)
        audio.setframerate(sample_rate)
        audio.writeframes(frame_data)
    return output.getvalue()


class ParseMonoPcm16WavTests(unittest.TestCase):
    def test_accepts_ten_seconds_of_mono_pcm16_at_sixteen_khz(self) -> None:
        data = make_wav(sample_value=2_000)
        frames = parse_mono_pcm16_wav(data)
        self.assertEqual(len(frames), 160_000 * 2)

    def test_rejects_silent_audio_before_model_inference(self) -> None:
        with self.assertRaisesRegex(InvalidAudio, "No clear audio signal"):
            parse_mono_pcm16_wav(make_wav())

    def test_rejects_unsupported_sample_rate(self) -> None:
        with self.assertRaisesRegex(InvalidAudio, "16 kHz"):
            parse_mono_pcm16_wav(make_wav(sample_rate=8_000, frames_count=80_000))

    def test_rejects_stereo_audio(self) -> None:
        with self.assertRaisesRegex(InvalidAudio, "mono"):
            parse_mono_pcm16_wav(make_wav(frames_count=1, channels=2))

    def test_rejects_audio_outside_duration_tolerance(self) -> None:
        with self.assertRaisesRegex(InvalidAudio, "10 seconds"):
            parse_mono_pcm16_wav(make_wav(frames_count=8_000))

    def test_rejects_oversized_and_malformed_uploads(self) -> None:
        with self.assertRaises(InvalidAudio):
            parse_mono_pcm16_wav(b"x" * 400_001)
        with self.assertRaises(InvalidAudio):
            parse_mono_pcm16_wav(b"not a wav")


if __name__ == "__main__":
    unittest.main()
