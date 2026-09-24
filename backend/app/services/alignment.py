"""
Word-timing generation for narration uploaded through the admin.

An audiobook produced elsewhere arrives with no word timestamps, so the reader
has nothing to highlight against and the text/audio stay unsynchronised.
Authoring real timings needs forced alignment (an ASR pass over the audio);
until that exists, approximate the timings by spreading the clip's duration
across its words in proportion to word length.

The result tracks the narration closely at the start of a clip and drifts
somewhat over long ones — good enough to give the reader a moving highlight and
a sense of position, and clearly labelled as an estimate.
"""

from __future__ import annotations

import logging
import os
import struct
from typing import List, Optional, Sequence

logger = logging.getLogger(__name__)

# MPEG audio bitrate tables (kbps), indexed by [version][layer][bitrate_index].
_BITRATES = {
    # MPEG 1
    (1, 1): [0, 32, 64, 96, 128, 160, 192, 224, 256, 288, 320, 352, 384, 416, 448],
    (1, 2): [0, 32, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, 384],
    (1, 3): [0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320],
    # MPEG 2 / 2.5
    (2, 1): [0, 32, 48, 56, 64, 80, 96, 112, 128, 144, 160, 176, 192, 224, 256],
    (2, 2): [0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160],
    (2, 3): [0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160],
}

_SAMPLE_RATES = {
    1: [44100, 48000, 32000],     # MPEG 1
    2: [22050, 24000, 16000],     # MPEG 2
    25: [11025, 12000, 8000],     # MPEG 2.5
}


def mp3_duration_seconds(path: str) -> Optional[float]:
    """Duration of an MP3 by walking its frame headers.

    Deliberately dependency-free: the API image is slim and adding a media
    library for one number is not worth the image size. Returns None when the
    file is not a parseable MPEG stream.
    """
    try:
        size = os.path.getsize(path)
        with open(path, "rb") as fh:
            # Skip an ID3v2 tag if present.
            header = fh.read(10)
            if header[:3] == b"ID3" and len(header) == 10:
                tag_size = ((header[6] & 0x7F) << 21) | ((header[7] & 0x7F) << 14) \
                           | ((header[8] & 0x7F) << 7) | (header[9] & 0x7F)
                fh.seek(10 + tag_size)
            else:
                fh.seek(0)

            # Find the first frame sync.
            start = None
            window = fh.read(64 * 1024)
            for i in range(len(window) - 4):
                if window[i] == 0xFF and (window[i + 1] & 0xE0) == 0xE0:
                    start = fh.tell() - len(window) + i
                    break
            if start is None:
                return None

            fh.seek(start)
            header = fh.read(4)
            if len(header) < 4:
                return None
            h = struct.unpack(">I", header)[0]

            version_bits = (h >> 19) & 0x3      # 0=2.5, 2=2, 3=1
            layer_bits = (h >> 17) & 0x3        # 1=III, 2=II, 3=I
            bitrate_index = (h >> 12) & 0xF
            sample_index = (h >> 10) & 0x3

            version = {0: 25, 2: 2, 3: 1}.get(version_bits)
            layer = {1: 3, 2: 2, 3: 1}.get(layer_bits)
            if version is None or layer is None or bitrate_index in (0, 15):
                return None

            bitrate = _BITRATES.get((1 if version == 1 else 2, layer), [0] * 15)[bitrate_index]
            sample_rate = _SAMPLE_RATES[version][sample_index]
            if not bitrate or not sample_rate:
                return None

            # Bitrate is the frame's constant rate only for CBR; for VBR the
            # Xing header carries the true frame count, so prefer it.
            audio_bytes = size - start
            frames = None
            fh.seek(start)
            probe = fh.read(4096)
            for tag in (b"Xing", b"Info"):
                idx = probe.find(tag)
                if idx != -1 and idx + 12 <= len(probe):
                    flags = struct.unpack(">I", probe[idx + 4:idx + 8])[0]
                    if flags & 0x1:
                        frames = struct.unpack(">I", probe[idx + 8:idx + 12])[0]
                    break

            samples_per_frame = {1: 1152, 2: 1152, 3: 384}[layer]
            if version in (2, 25) and layer == 3:
                samples_per_frame = 576

            if frames:
                return frames * samples_per_frame / sample_rate

            # CBR estimate from the bytes that follow the first frame.
            return audio_bytes * 8 / (bitrate * 1000)
    except Exception:
        logger.debug("MP3 duration parse failed for %s", path, exc_info=True)
        return None


def build_sync_data(
    chapters: Sequence,
    duration_seconds: float,
    gap_seconds: float = 0.4,
) -> bool:
    """Fill in approximate per-word timings across a book's chapters.

    Each chapter gets a slice of the total duration proportional to its word
    count; inside a chapter the words are spread by character length (longer
    words occupy more time). Mutates the chapter objects in place.

    Returns False (writing nothing) when the clip is far too short for the
    text — that means the audio covers only part of the book, e.g. one chapter
    file of a multi-file audiobook, and timings derived from it would make the
    highlight race through the text.
    """
    word_rows = []
    for chapter in chapters:
        words = [w for para in (chapter.content or []) for w in (para.get("words") or [])]
        word_rows.append((chapter, words))

    total_words = sum(len(w) for _, w in word_rows)
    if total_words == 0:
        return False

    # Spoken English averages roughly 2.5-3 words a second. Anything under
    # MIN_SECONDS_PER_WORD cannot be narration of this text.
    MIN_SECONDS_PER_WORD = 0.15
    if duration_seconds / total_words < MIN_SECONDS_PER_WORD:
        logger.info(
            "Skipping timing generation: %.0fs of audio for %d words "
            "(too short for the text — audio likely covers only part of the book)",
            duration_seconds, total_words,
        )
        return False

    # Reserve the inter-chapter gaps, then split what is left by word count.
    usable = max(duration_seconds - gap_seconds * max(len(word_rows) - 1, 0), 1.0)
    clock = 0.0

    for chapter, words in word_rows:
        if not words:
            chapter.sync_data = []
            continue

        chapter_seconds = usable * (len(words) / total_words)
        weights = [max(len(w.get("text") or ""), 1) for w in words]
        total_weight = sum(weights)
        per_word = chapter_seconds / total_weight

        sync = []
        t = clock
        for w, weight in zip(words, weights):
            span = per_word * weight
            sync.append({"id": w["id"], "start": round(t, 3), "end": round(t + span, 3)})
            t += span
        chapter.sync_data = sync
        clock += chapter_seconds + gap_seconds

    return True
