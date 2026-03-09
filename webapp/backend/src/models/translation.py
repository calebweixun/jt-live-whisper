"""
TranslationResult 資料模型
定義翻譯結果的資料結構
"""
from datetime import datetime
from typing import Optional
from pydantic import BaseModel, Field
from uuid import UUID, uuid4


class TranslationResult(BaseModel):
    """翻譯結果資料模型"""
    translation_id: UUID = Field(default_factory=uuid4, description="唯一識別符")
    task_id: UUID = Field(..., description="所屬轉譯任務 ID")
    session_id: UUID = Field(..., description="所屬會話 ID")
    source_text: str = Field(..., description="來源文字")
    translated_text: str = Field(..., description="翻譯文字")
    source_lang: str = Field(..., description="來源語言")
    target_lang: str = Field(..., description="目標語言")
    translation_service: str = Field(..., description="翻譯服務")
    model_name: Optional[str] = Field(default=None, description="使用的模型")
    timestamp: datetime = Field(default_factory=datetime.utcnow, description="翻譯時間")
    processing_time: float = Field(default=0.0, description="處理時間（秒）")
    error_message: Optional[str] = Field(default=None, description="錯誤訊息")
    
    class Config:
        json_encoders = {
            datetime: lambda v: v.isoformat(),
            UUID: lambda v: str(v)
        }


class TranslationResponse(BaseModel):
    """翻譯回應（WebSocket 訊息）"""
    translation_id: str
    task_id: str
    source_text: str
    translated_text: str
    source_lang: str
    target_lang: str
    service: str
    processing_time: float
