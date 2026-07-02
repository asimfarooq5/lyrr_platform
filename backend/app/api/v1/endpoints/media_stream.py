"""
Media streaming endpoints - serves uploaded audio and cover images with access control
"""

from fastapi import APIRouter, Request, HTTPException
from fastapi.responses import FileResponse, StreamingResponse
import os
import mimetypes

BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", ".."))
AUDIO_DIR = os.path.join(BASE_DIR, "storage", "audio")
COVERS_DIR = os.path.join(BASE_DIR, "storage", "covers")

router = APIRouter()


@router.get("/audio/{filename}")
async def stream_audio(filename: str, request: Request):
    """Stream audio file with range support for seeking"""
    filepath = os.path.join(AUDIO_DIR, filename)
    if not os.path.exists(filepath):
        raise HTTPException(status_code=404, detail="Audio not found")

    file_size = os.path.getsize(filepath)
    content_type, _ = mimetypes.guess_type(filename)
    content_type = content_type or "audio/mpeg"

    range_header = request.headers.get("range")
    if range_header:
        start, end = 0, file_size - 1
        range_match = range_header.replace("bytes=", "").split("-")
        start = int(range_match[0]) if range_match[0] else 0
        end = int(range_match[1]) if len(range_match) > 1 and range_match[1] else file_size - 1

        if start >= file_size:
            raise HTTPException(status_code=416)

        content_length = end - start + 1

        async def stream_chunks():
            with open(filepath, "rb") as f:
                f.seek(start)
                remaining = content_length
                while remaining > 0:
                    chunk_size = min(8192, remaining)
                    data = f.read(chunk_size)
                    if not data:
                        break
                    yield data
                    remaining -= len(data)

        return StreamingResponse(
            stream_chunks(),
            media_type=content_type,
            status_code=206,
            headers={
                "Content-Range": f"bytes {start}-{end}/{file_size}",
                "Content-Length": str(content_length),
                "Accept-Ranges": "bytes",
            },
        )

    return FileResponse(filepath, media_type=content_type, filename=filename,
                        headers={"Accept-Ranges": "bytes"})


@router.get("/covers/{filename}")
async def serve_cover(filename: str):
    """Serve cover images"""
    filepath = os.path.join(COVERS_DIR, filename)
    if not os.path.exists(filepath):
        raise HTTPException(status_code=404, detail="Cover not found")
    content_type, _ = mimetypes.guess_type(filename)
    return FileResponse(filepath, media_type=content_type or "image/jpeg")
