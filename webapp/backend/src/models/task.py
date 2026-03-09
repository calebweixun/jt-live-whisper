"""
TranscriptionTask 資料模型
定義轉譯任務的資料結構
"""
from datetime import datetime
from typing import List, Optional
from enum import Enum
from pydantic import BaseModel, Field
from uuid import UUID, uuid4


class TaskStatus(str, Enum):
    """任務狀態"""
    PENDING = "pending"
    PROCESSING = "processing"
    COMPLETED = "completed"
    FAILED = "failed"


class TranscriptionSegment(BaseModel):
    """轉譯片段"""
    id: int = Field(..., description="片段序號")
    start: float = Field(..., description="開始時間（秒）")
    end: float = Field(..., description="結束時間（秒）")
    text: str = Field(..., description="轉譯文字")
    confidence: float = Field(default=0.0, description="信心度（0-1）")


class TranscriptionTask(BaseModel):
    """轉譯任務資料模型"""
    task_id: UUID = Field(default_factory=uuid4, description="唯一識別符")
    session_id: UUID = Field(..., description="所屬會話 ID")
    stream_id: UUID = Field(..., description="音訊串流 ID")
    start_time: datetime = Field(default_factory=datetime.utcnow, description="任務開始時間")
    end_time: Optional[datetime] = Field(default=None, description="任務結束時間")
    model_name: str = Field(default="large-v3-turbo", description="使用的模型")
    language: str = Field(default="en", description="語言")
    compute_mode: str = Field(default="server_gpu", description="運算模式")
    status: TaskStatus = Field(default=TaskStatus.PENDING, description="狀態")
    segments: List[TranscriptionSegment] = Field(default_factory=list, description="轉譯片段")
    full_text: str = Field(default="", description="完整轉譯文字")
    duration: float = Field(default=0.0, description="音訊時長（秒）")
    processing_time: float = Field(default=0.0, description="處理時間（秒）")
    error_message: Optional[str] = Field(default=None, description="錯誤訊息")
    
    class Config:
        json_encoders = {
            datetime: lambda v: v.isoformat(),
            UUID: lambda v: str(v)
        }
        use_enum_values = True


class TranscriptionResult(BaseModel):
    """轉譯結果（WebSocket 訊息）"""
    task_id: str
    text: str
    start_time: float
    end_time: float
    confidence: float
    is_final: bool
    language: str
