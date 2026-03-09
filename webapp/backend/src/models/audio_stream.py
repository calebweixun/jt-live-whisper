"""
AudioStream 資料模型
定義音訊串流的資料結構
"""
from datetime import datetime
from typing import Optional
from pydantic import BaseModel, Field
from uuid import UUID, uuid4


class AudioFormat(BaseModel):
    """音訊格式資訊"""
    container: str = Field(default="webm", description="容器格式")
    codec: str = Field(default="opus", description="編碼格式")
    sample_rate: int = Field(default=48000, description="取樣率（Hz）")
    channels: int = Field(default=1, description="聲道數")
    bit_depth: int = Field(default=16, description="位元深度")


class AudioStream(BaseModel):
    """音訊串流資料模型"""
    stream_id: UUID = Field(default_factory=uuid4, description="唯一識別符")
    session_id: UUID = Field(..., description="所屬會話 ID")
    start_time: datetime = Field(default_factory=datetime.utcnow, description="串流開始時間")
    end_time: Optional[datetime] = Field(default=None, description="串流結束時間")
    audio_format: AudioFormat = Field(default_factory=AudioFormat, description="音訊格式資訊")
    total_chunks: int = Field(default=0, description="總 chunk 數量")
    total_duration: float = Field(default=0.0, description="總時長（秒）")
    file_path: Optional[str] = Field(default=None, description="儲存路徑")
    
    class Config:
        json_encoders = {
            datetime: lambda v: v.isoformat(),
            UUID: lambda v: str(v)
        }


class AudioChunk(BaseModel):
    """音訊資料塊"""
    audio: str = Field(..., description="Base64 編碼的音訊資料")
    chunk_index: int = Field(..., description="Chunk 序號")
    is_last: bool = Field(default=False, description="是否為最後一個 chunk")
    timestamp: int = Field(..., description="時間戳記")
