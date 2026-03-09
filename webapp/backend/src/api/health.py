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
    try:
        # 檢查轉譯服務
        transcription_available = True
        transcription_error = None
        try:
            # TODO: 實際檢查 faster-whisper 是否可用
            pass
        except Exception as e:
            transcription_available = False
            transcription_error = str(e)
        
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
            try:
                import torch
                if torch.cuda.is_available():
                    gpu_info = {
                        "available": True,
                        "device_count": torch.cuda.device_count(),
                        "device_name": torch.cuda.get_device_name(0),
                        "memory_allocated": f"{torch.cuda.memory_allocated(0) / 1024**3:.2f} GB",
                        "memory_total": f"{torch.cuda.get_device_properties(0).total_memory / 1024**3:.2f} GB"
                    }
                else:
                    gpu_info = {"available": False, "reason": "CUDA not available"}
            except Exception as e:
                gpu_info = {"available": False, "error": str(e)}
        
        # 統計資訊
        # TODO: 實際統計活動連線數、總會話數等
        statistics = {
            "active_connections": 0,
            "total_sessions": 0
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
