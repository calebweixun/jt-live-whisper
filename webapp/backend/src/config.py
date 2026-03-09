"""
配置管理模組
負責載入和管理系統配置
"""
import os
import logging
from typing import Optional
from pydantic_settings import BaseSettings
from pydantic import Field


class Settings(BaseSettings):
    """系統配置"""
    
    # Server 設定
    server_host: str = Field(default="0.0.0.0", alias="SERVER_HOST")
    server_port: int = Field(default=8000, alias="SERVER_PORT")
    
    # GPU 設定
    cuda_visible_devices: str = Field(default="0", alias="CUDA_VISIBLE_DEVICES")
    whisper_model: str = Field(default="large-v3-turbo", alias="WHISPER_MODEL")
    whisper_device: str = Field(default="cuda", alias="WHISPER_DEVICE")
    whisper_compute_type: str = Field(default="float16", alias="WHISPER_COMPUTE_TYPE")
    whisper_model_path: Optional[str] = Field(default=None, alias="WHISPER_MODEL_PATH")
    
    # Ollama 設定（翻譯服務）
    ollama_url: str = Field(default="http://localhost:11434", alias="OLLAMA_URL")
    ollama_model: str = Field(default="qwen2.5:7b", alias="OLLAMA_MODEL")
    ollama_timeout: int = Field(default=10, alias="OLLAMA_TIMEOUT")
    fallback_to_argos: bool = Field(default=True, alias="FALLBACK_TO_ARGOS")
    
    # Storage 設定
    data_dir: str = Field(default="../data", alias="DATA_DIR")
    max_audio_size_mb: int = Field(default=100, alias="MAX_AUDIO_SIZE_MB")
    retention_days: int = Field(default=7, alias="RETENTION_DAYS")
    
    # WebSocket 設定
    max_connections: int = Field(default=10, alias="MAX_CONNECTIONS")
    ping_interval: int = Field(default=30, alias="PING_INTERVAL")
    ping_timeout: int = Field(default=10, alias="PING_TIMEOUT")
    
    # Logging 設定
    log_level: str = Field(default="INFO", alias="LOG_LEVEL")
    log_file: str = Field(default="../data/logs/app.log", alias="LOG_FILE")
    error_log_file: str = Field(default="../data/logs/error.log", alias="ERROR_LOG_FILE")
    
    class Config:
        env_file = ".env"
        case_sensitive = False


# 全局配置實例
settings = Settings()


def setup_logging():
    """設定日誌系統"""
    # 確保 logs 目錄存在
    log_dir = os.path.dirname(settings.log_file)
    os.makedirs(log_dir, exist_ok=True)
    
    # 設定日誌格式
    log_format = "%(asctime)s - %(name)s - %(levelname)s - %(message)s"
    
    # 設定 root logger
    logging.basicConfig(
        level=getattr(logging, settings.log_level.upper()),
        format=log_format,
        handlers=[
            # 控制台輸出
            logging.StreamHandler(),
            # 一般日誌檔案
            logging.FileHandler(settings.log_file, encoding="utf-8"),
        ]
    )
    
    # 設定錯誤日誌檔案
    error_handler = logging.FileHandler(settings.error_log_file, encoding="utf-8")
    error_handler.setLevel(logging.ERROR)
    error_handler.setFormatter(logging.Formatter(log_format))
    logging.getLogger().addHandler(error_handler)
    
    # 設定第三方函式庫的日誌級別
    logging.getLogger("uvicorn").setLevel(logging.INFO)
    logging.getLogger("fastapi").setLevel(logging.INFO)
    logging.getLogger("httpx").setLevel(logging.WARNING)
    
    logging.info(f"日誌系統已啟動，level={settings.log_level}")
    logging.info(f"日誌檔案: {settings.log_file}")
    logging.info(f"錯誤日誌檔案: {settings.error_log_file}")


def get_settings() -> Settings:
    """獲取配置實例"""
    return settings
