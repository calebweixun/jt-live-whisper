"""
WebSocket API
處理即時音訊串流和轉譯
"""
import logging
import json
import asyncio
from typing import Dict, Any, Optional
from datetime import datetime
from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from pathlib import Path

from ..config import get_settings
from ..models.session import SessionCreate, ComputeMode, SessionStatus
from ..models.audio_stream import AudioChunk
from ..services.session_manager import get_session_manager
from ..services.audio_processor import get_audio_processor
from ..services.transcription import get_transcription_service
from ..services.storage import get_storage_service

logger = logging.getLogger(__name__)
router = APIRouter()
settings = get_settings()


class WebSocketConnectionManager:
    """WebSocket 連線管理器"""
    
    def __init__(self):
        self.active_connections: Dict[str, WebSocket] = {}
        self.session_manager = get_session_manager()
        self.audio_processor = get_audio_processor()
        self.transcription_service = get_transcription_service()
        self.storage = get_storage_service()
    
    async def connect(self, websocket: WebSocket, client_ip: str, user_agent: str) -> str:
        """
        建立 WebSocket 連線
        
        Returns:
            session_id
        """
        await websocket.accept()
        
        # 檢查連線數限制
        if len(self.active_connections) >= settings.max_connections:
            await self._send_error(
                websocket,
                "MAX_CONNECTIONS",
                f"已達最大連線數限制（{settings.max_connections}）"
            )
            await websocket.close()
            raise Exception("連線數已滿")
        
        # 建立會話
        session_config = SessionCreate(
            compute_mode=ComputeMode.SERVER_GPU,
            source_lang="en",
            target_lang="zh-TW",
            enable_translation=False
        )
        
        session = self.session_manager.create_session(
            client_ip=client_ip,
            user_agent=user_agent,
            config=session_config
        )
        
        session_id = str(session.session_id)
        self.active_connections[session_id] = websocket
        
        # 發送連線成功訊息
        await self._send_message(websocket, {
            "type": "connected",
            "data": {
                "session_id": session_id,
                "server_version": "1.0.0",
                "capabilities": {
                    "transcription": self.transcription_service.is_available(),
                    "translation": True,  # TODO: 檢查翻譯服務
                    "local_compute": False
                }
            },
            "timestamp": int(datetime.utcnow().timestamp())
        })
        
        logger.info(f"WebSocket 連線建立: {session_id}")
        return session_id
    
    def disconnect(self, session_id: str):
        """斷開連線"""
        if session_id in self.active_connections:
            self.active_connections.pop(session_id)
            logger.info(f"WebSocket 連線斷開: {session_id}")
    
    async def handle_message(self, session_id: str, message: Dict[str, Any]):
        """
        處理客戶端訊息
        
        Args:
            session_id: 會話 ID
            message: 訊息內容
        """
        message_type = message.get("type")
        websocket = self.active_connections.get(session_id)
        
        if not websocket:
            logger.warning(f"會話不存在: {session_id}")
            return
        
        try:
            if message_type == "start":
                await self._handle_start(session_id, websocket, message)
            elif message_type == "audio_chunk":
                await self._handle_audio_chunk(session_id, websocket, message)
            elif message_type == "stop":
                await self._handle_stop(session_id, websocket, message)
            elif message_type == "ping":
                await self._handle_ping(websocket)
            else:
                logger.warning(f"未知訊息類型: {message_type}")
        
        except Exception as e:
            logger.error(f"處理訊息失敗: {e}", exc_info=True)
            await self._send_error(websocket, "PROCESSING_ERROR", str(e))
    
    async def _handle_start(self, session_id: str, websocket: WebSocket, message: Dict[str, Any]):
        """處理開始轉譯訊息"""
        data = message.get("data", {})
        
        # 更新會話配置
        session = self.session_manager.get_session(session_id)
        if session:
            session.compute_mode = ComputeMode(data.get("compute_mode", "server_gpu"))
            session.source_lang = data.get("source_lang", "en")
            session.target_lang = data.get("target_lang", "zh-TW")
            session.enable_translation = data.get("enable_translation", False)
            self.session_manager._save_session(session)
        
        # 檢查 GPU 可用性
        if session.compute_mode == ComputeMode.SERVER_GPU:
            if not self.transcription_service.is_available():
                await self._send_error(
                    websocket,
                    "GPU_UNAVAILABLE",
                    "Server GPU 無法使用，請切換到本地運算模式或稍後再試",
                    recoverable=True
                )
                return
        
        # 發送開始成功訊息
        await self._send_message(websocket, {
            "type": "started",
            "data": {
                "session_id": session_id,
                "config": {
                    "compute_mode": session.compute_mode.value,
                    "source_lang": session.source_lang,
                    "target_lang": session.target_lang,
                    "enable_translation": session.enable_translation
                }
            },
            "timestamp": int(datetime.utcnow().timestamp())
        })
        
        logger.info(f"開始轉譯: {session_id}")
    
    async def _handle_audio_chunk(self, session_id: str, websocket: WebSocket, message: Dict[str, Any]):
        """處理音訊資料塊"""
        try:
            data = message.get("data", {})
            audio_chunk = AudioChunk(**data)
            
            # 發送處理中狀態
            await self._send_message(websocket, {
                "type": "processing",
                "data": {
                    "stage": "receiving",
                    "progress": 0.3,
                    "message": "正在接收音訊..."
                },
                "timestamp": int(datetime.utcnow().timestamp())
            })
            
            # 解碼並轉換音訊
            wav_path = await self.audio_processor.decode_and_convert_audio_chunk(
                audio_chunk.audio,
                session_id,
                audio_chunk.chunk_index
            )
            
            if not wav_path:
                await self._send_error(
                    websocket,
                    "AUDIO_FORMAT_ERROR",
                    "音訊格式轉換失敗"
                )
                return
            
            # 發送轉譯中狀態
            await self._send_message(websocket, {
                "type": "processing",
                "data": {
                    "stage": "transcribing",
                    "progress": 0.6,
                    "message": "正在轉譯音訊..."
                },
                "timestamp": int(datetime.utcnow().timestamp())
            })
            
            # 執行轉譯
            session = self.session_manager.get_session(session_id)
            language = None if session.source_lang == "auto" else session.source_lang
            
            transcription_result = await self.transcription_service.transcribe_audio_stream(
                wav_path,
                language=language
            )
            
            if transcription_result:
                # 發送轉譯結果
                await self._send_message(websocket, {
                    "type": "transcription",
                    "data": {
                        "task_id": f"task_{audio_chunk.chunk_index}",
                        "text": transcription_result["text"],
                        "start_time": transcription_result["start_time"],
                        "end_time": transcription_result["end_time"],
                        "confidence": transcription_result["confidence"],
                        "is_final": transcription_result["is_final"],
                        "language": transcription_result["language"]
                    },
                    "timestamp": int(datetime.utcnow().timestamp())
                })
                
                # 儲存轉譯記錄
                await self._save_transcription(session_id, transcription_result, audio_chunk.chunk_index)
                
                # 如果啟用翻譯，執行翻譯
                if session.enable_translation:
                    await self._handle_translation(
                        session_id,
                        websocket,
                        transcription_result["text"],
                        session.source_lang,
                        session.target_lang
                    )
            
        except Exception as e:
            logger.error(f"處理音訊塊失敗: {e}", exc_info=True)
            await self._send_error(websocket, "TRANSCRIPTION_FAILED", str(e))
    
    async def _handle_translation(
        self,
        session_id: str,
        websocket: WebSocket,
        text: str,
        source_lang: str,
        target_lang: str
    ):
        """處理翻譯請求"""
        try:
            # TODO: 實作翻譯服務
            # 暫時返回模擬翻譯
            await self._send_message(websocket, {
                "type": "translation",
                "data": {
                    "translation_id": f"trans_{int(datetime.utcnow().timestamp())}",
                    "task_id": "task_0",
                    "source_text": text,
                    "translated_text": f"[翻譯] {text}",
                    "source_lang": source_lang,
                    "target_lang": target_lang,
                    "service": "ollama",
                    "processing_time": 0.5
                },
                "timestamp": int(datetime.utcnow().timestamp())
            })
        
        except Exception as e:
            logger.error(f"翻譯失敗: {e}")
            await self._send_error(websocket, "TRANSLATION_FAILED", str(e))
    
    async def _handle_stop(self, session_id: str, websocket: WebSocket, message: Dict[str, Any]):
        """處理停止訊息"""
        # 更新會話狀態
        self.session_manager.update_session_status(
            session_id,
            SessionStatus.COMPLETED,
            datetime.utcnow()
        )
        
        # 獲取統計資訊
        statistics = self.session_manager.get_session_statistics(session_id)
        
        # 發送停止成功訊息
        await self._send_message(websocket, {
            "type": "stopped",
            "data": {
                "session_id": session_id,
                "total_duration": statistics.get("total_audio_duration", 0),
                "total_chunks": 0,  # TODO: 實際計算
                "transcription_count": statistics.get("transcription_count", 0),
                "translation_count": statistics.get("translation_count", 0)
            },
            "timestamp": int(datetime.utcnow().timestamp())
        })
        
        logger.info(f"停止轉譯: {session_id}")
    
    async def _handle_ping(self, websocket: WebSocket):
        """處理 ping 訊息"""
        await self._send_message(websocket, {
            "type": "pong",
            "timestamp": int(datetime.utcnow().timestamp())
        })
    
    async def _save_transcription(self, session_id: str, result: Dict[str, Any], chunk_index: int):
        """儲存轉譯記錄"""
        try:
            transcript_data = {
                "session_id": session_id,
                "chunk_index": chunk_index,
                "text": result["text"],
                "start_time": result["start_time"],
                "end_time": result["end_time"],
                "confidence": result["confidence"],
                "language": result["language"],
                "timestamp": datetime.utcnow().isoformat()
            }
            
            self.storage.save_json(
                "transcripts",
                f"{session_id}_{chunk_index}",
                transcript_data
            )
        except Exception as e:
            logger.error(f"儲存轉譯記錄失敗: {e}")
    
    async def _send_message(self, websocket: WebSocket, message: Dict[str, Any]):
        """發送訊息到客戶端"""
        try:
            await websocket.send_json(message)
        except Exception as e:
            logger.error(f"發送訊息失敗: {e}")
    
    async def _send_error(
        self,
        websocket: WebSocket,
        code: str,
        message: str,
        details: Optional[Dict[str, Any]] = None,
        recoverable: bool = False
    ):
        """發送錯誤訊息"""
        await self._send_message(websocket, {
            "type": "error",
            "data": {
                "code": code,
                "message": message,
                "details": details or {},
                "recoverable": recoverable
            },
            "timestamp": int(datetime.utcnow().timestamp())
        })


# 全局連線管理器
manager = WebSocketConnectionManager()


@router.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    """WebSocket 端點"""
    session_id = None
    
    try:
        # 獲取客戶端資訊
        client_ip = websocket.client.host if websocket.client else "unknown"
        user_agent = websocket.headers.get("user-agent", "unknown")
        
        # 建立連線
        session_id = await manager.connect(websocket, client_ip, user_agent)
        
        # 訊息循環
        while True:
            # 接收訊息
            message = await websocket.receive_json()
            
            # 處理訊息
            await manager.handle_message(session_id, message)
    
    except WebSocketDisconnect:
        logger.info(f"客戶端斷開連線: {session_id}")
    
    except Exception as e:
        logger.error(f"WebSocket 異常: {e}", exc_info=True)
    
    finally:
        # 清理連線
        if session_id:
            manager.disconnect(session_id)
            manager.session_manager.update_session_status(
                session_id,
                SessionStatus.COMPLETED,
                datetime.utcnow()
            )
