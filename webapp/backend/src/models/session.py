"""
Session 資料模型
定義使用者會話的資料結構
"""
from datetime import datetime
from typing import Optional
from enum import Enum
from pydantic import BaseModel, Field
from uuid import UUID, uuid4


class SessionStatus(str, Enum):
    """會話狀態"""
    ACTIVE = "active"
    COMPLETED = "completed"
    ERROR = "error"


class ComputeMode(str, Enum):
    """運算模式"""
    SERVER_GPU = "server_gpu"
    LOCAL_OPENVINO = "local_openvino"


class Session(BaseModel):
    """會話資料模型"""
    session_id: UUID = Field(default_factory=uuid4, description="唯一識別符")
    client_ip: str = Field(..., description="客戶端 IP 位址")
    user_agent: str = Field(..., description="瀏覽器 User-Agent")
    connect_time: datetime = Field(default_factory=datetime.utcnow, description="連線時間")
    disconnect_time: Optional[datetime] = Field(default=None, description="斷線時間")
    compute_mode: ComputeMode = Field(default=ComputeMode.SERVER_GPU, description="運算模式")
    source_lang: str = Field(default="en", description="來源語言")
    target_lang: str = Field(default="zh-TW", description="目標語言")
    enable_translation: bool = Field(default=False, description="是否啟用翻譯")
    status: SessionStatus = Field(default=SessionStatus.ACTIVE, description="狀態")
    
    class Config:
        json_encoders = {
            datetime: lambda v: v.isoformat(),
            UUID: lambda v: str(v)
        }
        use_enum_values = True


class SessionCreate(BaseModel):
    """建立會話的請求模型"""
    compute_mode: ComputeMode = ComputeMode.SERVER_GPU
    source_lang: str = "en"
    target_lang: str = "zh-TW"
    enable_translation: bool = False


class SessionResponse(BaseModel):
    """會話回應模型"""
    session_id: str
    connect_time: str
    disconnect_time: Optional[str] = None
    status: str
    config: dict
    statistics: Optional[dict] = None
