"""
SuperClaude Local Whisper API

Fast, local speech-to-text using faster-whisper (CTranslate2).
No external API calls, runs entirely on your VPS.

Endpoints:
  POST /transcribe     - Transcribe audio file
  POST /transcribe/url - Transcribe from URL
  GET  /health         - Health check
  GET  /models         - List available models

Models (auto-downloaded on first use):
  - tiny    (~75MB)  - Fastest, least accurate
  - base    (~150MB) - Good balance for short audio
  - small   (~500MB) - Better accuracy
  - medium  (~1.5GB) - High accuracy
  - large-v3 (~3GB)  - Best accuracy (recommended if you have RAM)
"""

import os
import io
import tempfile
import logging
from pathlib import Path
from typing import Optional
from contextlib import asynccontextmanager

import httpx
from fastapi import FastAPI, UploadFile, File, Form, HTTPException, BackgroundTasks
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from faster_whisper import WhisperModel

# ─────────────────────────────────────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────────────────────────────────────

WHISPER_MODEL = os.getenv("WHISPER_MODEL", "base")
WHISPER_DEVICE = os.getenv("WHISPER_DEVICE", "cpu")  # "cpu" or "cuda"
WHISPER_COMPUTE_TYPE = os.getenv("WHISPER_COMPUTE_TYPE", "int8")  # int8, float16, float32
MODEL_CACHE_DIR = os.getenv("MODEL_CACHE_DIR", "/app/models")

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# ─────────────────────────────────────────────────────────────────────────────
# Model Loading
# ─────────────────────────────────────────────────────────────────────────────

model: Optional[WhisperModel] = None

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Load model on startup."""
    global model
    
    logger.info(f"Loading Whisper model: {WHISPER_MODEL}")
    logger.info(f"Device: {WHISPER_DEVICE}, Compute type: {WHISPER_COMPUTE_TYPE}")
    
    # Create cache directory
    Path(MODEL_CACHE_DIR).mkdir(parents=True, exist_ok=True)
    
    # Load model (downloads automatically if not cached)
    model = WhisperModel(
        WHISPER_MODEL,
        device=WHISPER_DEVICE,
        compute_type=WHISPER_COMPUTE_TYPE,
        download_root=MODEL_CACHE_DIR,
    )
    
    logger.info(f"Model loaded successfully!")
    
    yield
    
    # Cleanup
    model = None

# ─────────────────────────────────────────────────────────────────────────────
# FastAPI App
# ─────────────────────────────────────────────────────────────────────────────

app = FastAPI(
    title="SuperClaude Whisper API",
    description="Local speech-to-text transcription",
    version="1.0.0",
    lifespan=lifespan,
)

# ─────────────────────────────────────────────────────────────────────────────
# Models
# ─────────────────────────────────────────────────────────────────────────────

class TranscriptionResponse(BaseModel):
    text: str
    language: str
    duration: float
    segments: Optional[list] = None

class TranscriptionRequest(BaseModel):
    url: str
    language: Optional[str] = None
    include_segments: bool = False

# ─────────────────────────────────────────────────────────────────────────────
# Transcription Logic
# ─────────────────────────────────────────────────────────────────────────────

def transcribe_audio(
    audio_path: str,
    language: Optional[str] = None,
    include_segments: bool = False,
) -> TranscriptionResponse:
    """Transcribe audio file using faster-whisper."""
    
    if model is None:
        raise HTTPException(status_code=503, detail="Model not loaded")
    
    # Transcribe
    segments, info = model.transcribe(
        audio_path,
        language=language,
        beam_size=5,
        vad_filter=True,  # Filter out silence
        vad_parameters=dict(
            min_silence_duration_ms=500,
        ),
    )
    
    # Collect segments
    segment_list = []
    full_text = []
    
    for segment in segments:
        full_text.append(segment.text.strip())
        if include_segments:
            segment_list.append({
                "start": segment.start,
                "end": segment.end,
                "text": segment.text.strip(),
            })
    
    return TranscriptionResponse(
        text=" ".join(full_text),
        language=info.language,
        duration=info.duration,
        segments=segment_list if include_segments else None,
    )

# ─────────────────────────────────────────────────────────────────────────────
# Endpoints
# ─────────────────────────────────────────────────────────────────────────────

@app.get("/health")
async def health_check():
    """Health check endpoint."""
    return {
        "status": "healthy",
        "model": WHISPER_MODEL,
        "device": WHISPER_DEVICE,
        "model_loaded": model is not None,
    }

@app.get("/models")
async def list_models():
    """List available Whisper models."""
    return {
        "current_model": WHISPER_MODEL,
        "available_models": [
            {"name": "tiny", "size": "~75MB", "speed": "fastest", "accuracy": "lowest"},
            {"name": "base", "size": "~150MB", "speed": "fast", "accuracy": "good"},
            {"name": "small", "size": "~500MB", "speed": "medium", "accuracy": "better"},
            {"name": "medium", "size": "~1.5GB", "speed": "slow", "accuracy": "high"},
            {"name": "large-v3", "size": "~3GB", "speed": "slowest", "accuracy": "best"},
        ],
    }

@app.post("/transcribe", response_model=TranscriptionResponse)
async def transcribe_file(
    file: UploadFile = File(...),
    language: Optional[str] = Form(None),
    include_segments: bool = Form(False),
):
    """
    Transcribe an uploaded audio file.
    
    Supported formats: mp3, wav, ogg, flac, m4a, webm
    """
    
    # Validate file type
    allowed_types = [
        "audio/mpeg", "audio/mp3", "audio/wav", "audio/ogg",
        "audio/flac", "audio/m4a", "audio/webm", "audio/x-m4a",
        "video/webm",  # Telegram voice messages
    ]
    
    content_type = file.content_type or ""
    if not any(t in content_type for t in ["audio", "video"]):
        # Try to infer from extension
        ext = Path(file.filename or "").suffix.lower()
        if ext not in [".mp3", ".wav", ".ogg", ".flac", ".m4a", ".webm"]:
            raise HTTPException(
                status_code=400,
                detail=f"Unsupported file type: {content_type}. Use mp3, wav, ogg, flac, m4a, or webm.",
            )
    
    # Save to temp file
    with tempfile.NamedTemporaryFile(delete=False, suffix=Path(file.filename or ".ogg").suffix) as tmp:
        content = await file.read()
        tmp.write(content)
        tmp_path = tmp.name
    
    try:
        result = transcribe_audio(tmp_path, language, include_segments)
        return result
    finally:
        # Cleanup
        Path(tmp_path).unlink(missing_ok=True)

@app.post("/transcribe/url", response_model=TranscriptionResponse)
async def transcribe_url(request: TranscriptionRequest):
    """
    Transcribe audio from a URL.
    
    Useful for Telegram file URLs.
    """
    
    # Download file
    async with httpx.AsyncClient() as client:
        try:
            response = await client.get(request.url, follow_redirects=True, timeout=30.0)
            response.raise_for_status()
        except httpx.HTTPError as e:
            raise HTTPException(status_code=400, detail=f"Failed to download: {str(e)}")
    
    # Determine extension from URL or content-type
    content_type = response.headers.get("content-type", "")
    ext = ".ogg"  # Default for Telegram voice
    if "mp3" in content_type or request.url.endswith(".mp3"):
        ext = ".mp3"
    elif "wav" in content_type or request.url.endswith(".wav"):
        ext = ".wav"
    elif "webm" in content_type or request.url.endswith(".webm"):
        ext = ".webm"
    
    # Save to temp file
    with tempfile.NamedTemporaryFile(delete=False, suffix=ext) as tmp:
        tmp.write(response.content)
        tmp_path = tmp.name
    
    try:
        result = transcribe_audio(tmp_path, request.language, request.include_segments)
        return result
    finally:
        Path(tmp_path).unlink(missing_ok=True)

# ─────────────────────────────────────────────────────────────────────────────
# OpenAI-Compatible Endpoint (drop-in replacement)
# ─────────────────────────────────────────────────────────────────────────────

@app.post("/v1/audio/transcriptions")
async def openai_compatible_transcribe(
    file: UploadFile = File(...),
    model: str = Form("whisper-1"),  # Ignored, uses configured model
    language: Optional[str] = Form(None),
    response_format: str = Form("json"),
):
    """
    OpenAI-compatible transcription endpoint.
    
    Drop-in replacement for OpenAI's /v1/audio/transcriptions
    """
    
    result = await transcribe_file(file, language, include_segments=False)
    
    if response_format == "text":
        return result.text
    elif response_format == "verbose_json":
        return {
            "text": result.text,
            "language": result.language,
            "duration": result.duration,
        }
    else:  # json
        return {"text": result.text}

# ─────────────────────────────────────────────────────────────────────────────
# Run with: uvicorn whisper_api:app --host 0.0.0.0 --port 8787
# ─────────────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8787)
