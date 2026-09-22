from __future__ import annotations

from io import BytesIO
import math
import struct
import wave


SAMPLE_RATE = 16_000
MIN_DURATION_SECONDS = 9.5
MAX_DURATION_SECONDS = 10.5
MAX_UPLOAD_BYTES = 400_000
MIN_PEAK_AMPLITUDE = 384
MIN_RMS_AMPLITUDE = 96
MIN_ACTIVE_RATIO = 0.001
ACTIVE_SAMPLE_THRESHOLD = 256


class InvalidAudio(ValueError):
    """The submitted file does not match the preview audio format."""


def _ensure_audible_signal(frames: bytes) -> None:
    if not frames or len(frames) % 2:
        raise InvalidAudio("Audio does not contain a usable signal.")

    peak = 0
    active_samples = 0
    sum_squares = 0.0
    sample_count = len(frames) // 2
    for (sample,) in struct.iter_unpack("<h", frames):
        absolute = abs(sample)
        peak = max(peak, absolute)
        if absolute >= ACTIVE_SAMPLE_THRESHOLD:
            active_samples += 1
        sum_squares += sample * sample

    rms = math.sqrt(sum_squares / sample_count)
    active_ratio = active_samples / sample_count
    if (
        peak < MIN_PEAK_AMPLITUDE
        or rms < MIN_RMS_AMPLITUDE
        or active_ratio < MIN_ACTIVE_RATIO
    ):
        raise InvalidAudio(
            "No clear audio signal was detected. Please record again."
        )


def parse_mono_pcm16_wav(data: bytes) -> bytes:
    if not data or len(data) > MAX_UPLOAD_BYTES:
        raise InvalidAudio("Audio file is empty or too large.")

    try:
        with wave.open(BytesIO(data), "rb") as audio:
            if audio.getcomptype() != "NONE":
                raise InvalidAudio("Compressed WAV audio is not supported.")
            if audio.getnchannels() != 1:
                raise InvalidAudio("Audio must be mono.")
            if audio.getsampwidth() != 2:
                raise InvalidAudio("Audio must use 16-bit PCM.")
            if audio.getframerate() != SAMPLE_RATE:
                raise InvalidAudio("Audio must use a 16 kHz sample rate.")

            frames_count = audio.getnframes()
            duration = frames_count / SAMPLE_RATE
            if not MIN_DURATION_SECONDS <= duration <= MAX_DURATION_SECONDS:
                raise InvalidAudio("Audio must be about 10 seconds long.")

            frames = audio.readframes(frames_count)
            if len(frames) != frames_count * 2:
                raise InvalidAudio("WAV audio data is incomplete.")
            _ensure_audible_signal(frames)
            return frames
    except (wave.Error, EOFError, OSError) as error:
        raise InvalidAudio("File is not a valid PCM WAV recording.") from error
