"""
SuperClaude API Router

Unified API gateway for all SuperClaude services:
  - /api/transcribe/* - Speech-to-text (Whisper)
  - /api/notify/*     - Notifications (Telegram, etc.)
  - /api/sessions/*   - Claude Code session management
  - /api/health       - Overall health check

This router runs on port 3850 and proxies to internal services.
"""

import os
import asyncio
import logging
from typing import Optional, Dict, Any
from datetime import datetime

import httpx
from fastapi import FastAPI, Request, HTTPException, UploadFile, File, Form
from fastapi.responses import JSONResponse, StreamingResponse
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

# ─────────────────────────────────────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────────────────────────────────────

WHISPER_URL = os.getenv("WHISPER_URL", "http://whisper:8787")
TELEGRAM_BOT_URL = os.getenv("TELEGRAM_BOT_URL", "http://telegram-bot:3847")

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# ─────────────────────────────────────────────────────────────────────────────
# FastAPI App
# ─────────────────────────────────────────────────────────────────────────────

app = FastAPI(
    title="SuperClaude API",
    description="Unified API gateway for SuperClaude services",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# HTTP client for proxying
http_client: Optional[httpx.AsyncClient] = None

@app.on_event("startup")
async def startup():
    global http_client
    http_client = httpx.AsyncClient(timeout=120.0)

@app.on_event("shutdown")
async def shutdown():
    if http_client:
        await http_client.aclose()

# ─────────────────────────────────────────────────────────────────────────────
# Models
# ─────────────────────────────────────────────────────────────────────────────

class NotifyRequest(BaseModel):
    userId: int
    sessionId: str
    event: str
    message: str
    project: Optional[str] = None

class SessionInfo(BaseModel):
    id: str
    project: str
    worktree: Optional[str] = None
    status: str
    lastActivity: datetime

# ─────────────────────────────────────────────────────────────────────────────
# Health Check
# ─────────────────────────────────────────────────────────────────────────────

@app.get("/api/health")
async def health_check():
    """Check health of all services."""
    
    services = {}
    
    # Check Whisper
    try:
        resp = await http_client.get(f"{WHISPER_URL}/health", timeout=5.0)
        services["whisper"] = resp.json() if resp.status_code == 200 else {"status": "error"}
    except Exception as e:
        services["whisper"] = {"status": "unreachable", "error": str(e)}
    
    # Check Telegram Bot
    try:
        resp = await http_client.get(f"{TELEGRAM_BOT_URL}/health", timeout=5.0)
        services["telegram"] = {"status": "healthy"} if resp.status_code == 200 else {"status": "error"}
    except Exception as e:
        services["telegram"] = {"status": "unreachable", "error": str(e)}
    
    all_healthy = all(
        s.get("status") in ["healthy", "ok"] or "model_loaded" in s
        for s in services.values()
    )
    
    return {
        "status": "healthy" if all_healthy else "degraded",
        "timestamp": datetime.utcnow().isoformat(),
        "services": services,
    }

# ─────────────────────────────────────────────────────────────────────────────
# Transcription API
# ─────────────────────────────────────────────────────────────────────────────

@app.post("/api/transcribe")
async def transcribe_audio(
    file: UploadFile = File(...),
    language: Optional[str] = Form(None),
):
    """
    Transcribe audio file using local Whisper.
    
    Accepts: mp3, wav, ogg, flac, m4a, webm
    Returns: { "text": "transcribed text", "language": "en", "duration": 5.2 }
    """
    
    # Forward to Whisper service
    files = {"file": (file.filename, await file.read(), file.content_type)}
    data = {}
    if language:
        data["language"] = language
    
    try:
        resp = await http_client.post(
            f"{WHISPER_URL}/transcribe",
            files=files,
            data=data,
        )
        resp.raise_for_status()
        return resp.json()
    except httpx.HTTPStatusError as e:
        raise HTTPException(status_code=e.response.status_code, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=503, detail=f"Whisper service unavailable: {e}")

@app.post("/api/transcribe/url")
async def transcribe_url(url: str, language: Optional[str] = None):
    """
    Transcribe audio from URL.
    
    Useful for Telegram voice message URLs.
    """
    
    try:
        resp = await http_client.post(
            f"{WHISPER_URL}/transcribe/url",
            json={"url": url, "language": language},
        )
        resp.raise_for_status()
        return resp.json()
    except httpx.HTTPStatusError as e:
        raise HTTPException(status_code=e.response.status_code, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=503, detail=f"Whisper service unavailable: {e}")

# OpenAI-compatible endpoint
@app.post("/api/v1/audio/transcriptions")
async def openai_compatible_transcribe(
    file: UploadFile = File(...),
    model: str = Form("whisper-1"),
    language: Optional[str] = Form(None),
    response_format: str = Form("json"),
):
    """OpenAI-compatible transcription endpoint."""
    
    files = {"file": (file.filename, await file.read(), file.content_type)}
    data = {"model": model, "response_format": response_format}
    if language:
        data["language"] = language
    
    try:
        resp = await http_client.post(
            f"{WHISPER_URL}/v1/audio/transcriptions",
            files=files,
            data=data,
        )
        resp.raise_for_status()
        
        if response_format == "text":
            return resp.text
        return resp.json()
    except Exception as e:
        raise HTTPException(status_code=503, detail=str(e))

# ─────────────────────────────────────────────────────────────────────────────
# Notification API
# ─────────────────────────────────────────────────────────────────────────────

@app.post("/api/notify")
async def send_notification(request: NotifyRequest):
    """
    Send notification to user via Telegram.
    
    Called by Claude Code hooks.
    """
    
    try:
        resp = await http_client.post(
            f"{TELEGRAM_BOT_URL}/notify",
            json=request.model_dump(),
        )
        resp.raise_for_status()
        return resp.json()
    except httpx.HTTPStatusError as e:
        raise HTTPException(status_code=e.response.status_code, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=503, detail=f"Telegram bot unavailable: {e}")

@app.post("/api/notify/simple")
async def send_simple_notification(
    user_id: int,
    message: str,
    event: str = "notification",
):
    """
    Simple notification endpoint for shell scripts.
    
    Usage:
      curl -X POST "http://api:3850/api/notify/simple?user_id=123&message=Done&event=stop"
    """
    
    return await send_notification(NotifyRequest(
        userId=user_id,
        sessionId="shell",
        event=event,
        message=message,
    ))

# ─────────────────────────────────────────────────────────────────────────────
# Whisper Models Info
# ─────────────────────────────────────────────────────────────────────────────

@app.get("/api/transcribe/models")
async def list_whisper_models():
    """List available Whisper models."""
    
    try:
        resp = await http_client.get(f"{WHISPER_URL}/models")
        resp.raise_for_status()
        return resp.json()
    except Exception as e:
        raise HTTPException(status_code=503, detail=str(e))

# ─────────────────────────────────────────────────────────────────────────────
# Run
# ─────────────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=3850)
