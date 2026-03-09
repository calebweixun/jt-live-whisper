"""
系統配置 API
提供客戶端需要的系統配置資訊
"""
import logging
from fastapi import APIRouter
from datetime import datetime
from typing import Dict, Any

from ..config import get_settings

logger = logging.getLogger(__name__)
router = APIRouter()
settings = get_settings()


@router.get("/config")
async def get_config() -> Dict[str, Any]:
    """
    獲取系統配置端點
    
    返回客戶端需要的配置資訊
    """
    try:
        # 檢查本地運算模式是否可用（目前階段尚未實作）
        local_compute_available = False
        local_compute_reason = "此功能尚未實作（P3 優先級）"
        
        return {
            "success": True,
            "data": {
                "supported_languages": ["zh-TW", "en"],
                "compute_modes": [
                    {
                        "id": "server_gpu",
                        "name": "Server GPU",
                        "description": "使用 Server 的 GPU 運算",
                        "available": settings.whisper_device == "cuda"
                    },
                    {
                        "id": "local_openvino",
                        "name": "本地運算（OpenVINO）",
                        "description": "使用您的裝置算力",
                        "available": local_compute_available,
                        "reason": local_compute_reason
                    }
                ],
                "max_audio_duration": 3600,  # 最大音訊時長（秒）
                "websocket_url": f"ws://{settings.server_host}:{settings.server_port}/ws",
                "features": {
                    "transcription": True,
                    "translation": True,
                    "session_management": True
                },
                "limits": {
                    "max_connections": settings.max_connections,
                    "max_audio_size_mb": settings.max_audio_size_mb
                }
            },
            "timestamp": datetime.utcnow().isoformat()
        }
    
    except Exception as e:
        logger.error(f"獲取配置失敗: {e}", exc_info=True)
        return {
            "success": False,
            "error": {
                "code": "CONFIG_FETCH_FAILED",
                "message": str(e)
            },
            "timestamp": datetime.utcnow().isoformat()
        }
