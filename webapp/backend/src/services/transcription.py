"""
轉譯服務
負責使用 faster-whisper 進行語音轉譯
"""
import logging
import asyncio
from typing import Optional, List, Dict, Any
from pathlib import Path
import time

logger = logging.getLogger(__name__)


class TranscriptionService:
    """轉譯服務"""
    
    def __init__(
        self,
        model_name: str = "large-v3-turbo",
        device: str = "cuda",
        compute_type: str = "float16",
        model_path: Optional[str] = None
    ):
        """
        初始化轉譯服務
        
        Args:
            model_name: 模型名稱
            device: 運算裝置（cuda 或 cpu）
            compute_type: 運算精度（float16, int8, int8_float16）
            model_path: 自訂模型路徑（可選）
        """
        self.model_name = model_name
        self.device = device
        self.compute_type = compute_type
        self.model_path = model_path
        self.model = None
        self._is_available = False
        
        # 初始化模型
        self._initialize_model()
    
    def _initialize_model(self):
        """初始化 faster-whisper 模型"""
        try:
            from faster_whisper import WhisperModel
            
            logger.info(f"載入 Whisper 模型: {self.model_name}, device: {self.device}")
            
            # 載入模型
            if self.model_path:
                self.model = WhisperModel(
                    self.model_path,
                    device=self.device,
                    compute_type=self.compute_type
                )
            else:
                self.model = WhisperModel(
                    self.model_name,
                    device=self.device,
                    compute_type=self.compute_type
                )
            
            self._is_available = True
            logger.info("Whisper 模型載入成功")
        
        except ImportError:
            logger.error("faster-whisper 未安裝，請執行: pip install faster-whisper")
            self._is_available = False
        
        except Exception as e:
            logger.error(f"載入 Whisper 模型失敗: {e}", exc_info=True)
            self._is_available = False
    
    def is_available(self) -> bool:
        """檢查轉譯服務是否可用"""
        return self._is_available and self.model is not None
    
    def check_gpu_availability(self) -> Dict[str, Any]:
        """
        檢查 GPU 可用性
        
        Returns:
            GPU 狀態資訊
        """
        try:
            if self.device == "cuda":
                import torch
                if torch.cuda.is_available():
                    return {
                        "available": True,
                        "device_count": torch.cuda.device_count(),
                        "device_name": torch.cuda.get_device_name(0),
                        "memory_allocated": f"{torch.cuda.memory_allocated(0) / 1024**3:.2f} GB",
                        "memory_total": f"{torch.cuda.get_device_properties(0).total_memory / 1024**3:.2f} GB"
                    }
                else:
                    return {"available": False, "reason": "CUDA not available"}
            else:
                return {"available": False, "reason": "CPU mode"}
        
        except Exception as e:
            return {"available": False, "error": str(e)}
    
    async def transcribe_audio(
        self,
        audio_path: Path,
        language: Optional[str] = None,
        task: str = "transcribe"
    ) -> Dict[str, Any]:
        """
        轉譯音訊檔案
        
        Args:
            audio_path: 音訊檔案路徑
            language: 語言（None 為自動偵測）
            task: 任務類型（transcribe 或 translate）
        
        Returns:
            轉譯結果
        """
        if not self.is_available():
            return {
                "success": False,
                "error": "轉譯服務不可用"
            }
        
        try:
            start_time = time.time()
            
            # 在執行緒池中執行轉譯（避免阻塞事件循環）
            loop = asyncio.get_event_loop()
            segments, info = await loop.run_in_executor(
                None,
                lambda: self.model.transcribe(
                    str(audio_path),
                    language=language,
                    task=task,
                    beam_size=5,
                    vad_filter=True,  # 啟用 VAD 過濾
                    vad_parameters={
                        "threshold": 0.5,
                        "min_speech_duration_ms": 250
                    }
                )
            )
            
            # 收集所有片段
            segments_list = []
            full_text = ""
            
            for segment in segments:
                segment_dict = {
                    "id": segment.id,
                    "start": segment.start,
                    "end": segment.end,
                    "text": segment.text.strip(),
                    "confidence": segment.avg_logprob  # faster-whisper 使用 avg_logprob
                }
                segments_list.append(segment_dict)
                full_text += segment.text.strip() + " "
            
            processing_time = time.time() - start_time
            
            return {
                "success": True,
                "segments": segments_list,
                "full_text": full_text.strip(),
                "language": info.language,
                "language_probability": info.language_probability,
                "duration": info.duration,
                "processing_time": processing_time
            }
        
        except Exception as e:
            logger.error(f"轉譯失敗: {e}", exc_info=True)
            return {
                "success": False,
                "error": str(e)
            }
    
    async def transcribe_audio_stream(
        self,
        audio_path: Path,
        language: Optional[str] = None
    ) -> Optional[Dict[str, Any]]:
        """
        轉譯音訊串流（單個片段）
        
        Args:
            audio_path: 音訊檔案路徑
            language: 語言
        
        Returns:
            轉譯結果（單個片段）
        """
        result = await self.transcribe_audio(audio_path, language=language)
        
        if not result.get("success"):
            return None
        
        # 返回最新的片段（用於即時顯示）
        if result.get("segments"):
            latest_segment = result["segments"][-1]
            return {
                "text": latest_segment["text"],
                "start_time": latest_segment["start"],
                "end_time": latest_segment["end"],
                "confidence": latest_segment["confidence"],
                "is_final": True,
                "language": result["language"],
                "full_text": result["full_text"]
            }
        
        return None


# 全局轉譯服務實例（在 main.py 中初始化）
transcription_service: Optional[TranscriptionService] = None


def get_transcription_service() -> TranscriptionService:
    """獲取轉譯服務實例"""
    if transcription_service is None:
        raise RuntimeError("TranscriptionService 尚未初始化")
    return transcription_service


def init_transcription_service(
    model_name: str,
    device: str,
    compute_type: str,
    model_path: Optional[str] = None
):
    """初始化轉譯服務"""
    global transcription_service
    transcription_service = TranscriptionService(
        model_name=model_name,
        device=device,
        compute_type=compute_type,
        model_path=model_path
    )
    logger.info(f"轉譯服務已初始化: model={model_name}, device={device}")
