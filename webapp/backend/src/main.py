"""
FastAPI 應用程式主入口
"""
import logging
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from datetime import datetime

from .config import get_settings, setup_logging
from .services.storage import init_storage_service

# 設定日誌
setup_logging()
logger = logging.getLogger(__name__)

# 獲取配置
settings = get_settings()

# 初始化儲存服務
init_storage_service(settings.data_dir)

# 建立 FastAPI 應用程式
app = FastAPI(
    title="Web 音訊串流轉譯 API",
    description="即時語音轉譯與翻譯服務",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc"
)

# 設定 CORS 中介軟體
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 區域網路內允許所有來源
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# 全局異常處理器
@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    """全局異常處理"""
    logger.error(f"未處理的異常: {exc}", exc_info=True)
    return JSONResponse(
        status_code=500,
        content={
            "success": False,
            "error": {
                "code": "INTERNAL_ERROR",
                "message": f"內部錯誤: {str(exc)}"
            },
            "timestamp": datetime.utcnow().isoformat()
        }
    )


# 應用程式啟動事件
@app.on_event("startup")
async def startup_event():
    """應用程式啟動時執行"""
    logger.info("=" * 50)
    logger.info("Web 音訊串流轉譯服務啟動")
    logger.info(f"Server: {settings.server_host}:{settings.server_port}")
    logger.info(f"Whisper Model: {settings.whisper_model}")
    logger.info(f"Whisper Device: {settings.whisper_device}")
    logger.info(f"Data Directory: {settings.data_dir}")
    logger.info("=" * 50)


# 應用程式關閉事件
@app.on_event("shutdown")
async def shutdown_event():
    """應用程式關閉時執行"""
    logger.info("Web 音訊串流轉譯服務關閉")


# 引入 API 路由
from .api import health, config as config_api

app.include_router(health.router, prefix="/api/v1", tags=["health"])
app.include_router(config_api.router, prefix="/api/v1", tags=["config"])


# 根路徑
@app.get("/")
async def root():
    """根路徑"""
    return {
        "message": "Web 音訊串流轉譯 API",
        "version": "1.0.0",
        "docs": "/docs",
        "health": "/api/v1/health"
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "main:app",
        host=settings.server_host,
        port=settings.server_port,
        reload=True,
        log_level=settings.log_level.lower()
    )
