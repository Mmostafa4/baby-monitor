from __future__ import annotations

from io import BytesIO
import wave


SAMPLE_RATE = 16_000
MIN_DURATION_SECONDS = 9.5
MAX_DURATION_SECONDS = 10.5
MAX_UPLOAD_BYTES = 400_000


class InvalidAudio(ValueError):
    """The submitted file does not match the preview audio format."""


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
            return frames
    except (wave.Error, EOFError, OSError) as error:
        raise InvalidAudio("File is not a valid PCM WAV recording.") from error
