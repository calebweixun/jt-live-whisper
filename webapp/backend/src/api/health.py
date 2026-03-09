"""
健康檢查 API
提供服務狀態檢查端點
"""
import logging
from fastapi import APIRouter
from datetime import datetime
from typing import Dict, Any

from ..config import get_settings

logger = logging.getLogger(__name__)
router = APIRouter()
settings = get_settings()


@router.get("/health")
async def health_check() -> Dict[str, Any]:
    """
    健康檢查端點
    
    檢查服務健康狀態和各項功能可用性
    """
    from ..services.transcription import get_transcription_service
    from ..services.session_manager import get_session_manager
    
    try:
        # 檢查轉譯服務
        transcription_service = get_transcription_service()
        transcription_available = transcription_service.is_available()
        transcription_error = None
        
        if not transcription_available:
            transcription_error = "Transcription service not initialized"
        
        # 檢查翻譯服務
        translation_available = True
        translation_service = "ollama"
        try:
            # TODO: 實際檢查 Ollama 是否可用
            pass
        except Exception as e:
            translation_available = False
            translation_service = "unavailable"
        
        # 檢查 GPU (如果使用)
        gpu_info = {}
        if settings.whisper_device == "cuda":
            gpu_info = transcription_service.check_gpu_availability()
        
        # 統計資訊
        session_manager = get_session_manager()
        active_connections = session_manager.get_active_session_count()
        
        statistics = {
            "active_connections": active_connections,
            "total_sessions": len(session_manager.list_sessions())
        }
        
        if gpu_info:
            statistics.update({
                "gpu_memory_used": gpu_info.get("memory_allocated", "N/A"),
                "gpu_memory_total": gpu_info.get("memory_total", "N/A")
            })
        
        return {
            "success": True,
            "data": {
                "status": "healthy" if transcription_available else "degraded",
                "version": "1.0.0",
                "services": {
                    "transcription": {
                        "available": transcription_available,
                        "model": settings.whisper_model,
                        "device": settings.whisper_device,
                        "error": transcription_error
                    },
                    "translation": {
                        "available": translation_available,
                        "service": translation_service,
                        "model": settings.ollama_model if translation_service == "ollama" else None
                    },
                    "gpu": gpu_info if gpu_info else {"available": False, "reason": "CPU mode"}
                },
                "statistics": statistics
            },
            "timestamp": datetime.utcnow().isoformat()
        }
    
    except Exception as e:
        logger.error(f"健康檢查失敗: {e}", exc_info=True)
        return {
            "success": False,
            "error": {
                "code": "HEALTH_CHECK_FAILED",
                "message": str(e)
            },
            "timestamp": datetime.utcnow().isoformat()
        }
