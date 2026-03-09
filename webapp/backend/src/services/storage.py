"""
儲存服務模組
負責 JSON 檔案的讀寫操作
"""
import os
import json
import logging
from typing import Any, Dict, Optional
from pathlib import Path
from datetime import datetime
from filelock import FileLock
from uuid import UUID

logger = logging.getLogger(__name__)


class StorageService:
    """檔案儲存服務"""
    
    def __init__(self, data_dir: str):
        """
        初始化儲存服務
        
        Args:
            data_dir: 資料目錄路徑
        """
        self.data_dir = Path(data_dir)
        self._ensure_directories()
    
    def _ensure_directories(self):
        """確保所有必要的目錄存在"""
        directories = [
            self.data_dir / "sessions",
            self.data_dir / "audio",
            self.data_dir / "transcripts",
            self.data_dir / "translations",
            self.data_dir / "logs"
        ]
        for directory in directories:
            directory.mkdir(parents=True, exist_ok=True)
            logger.debug(f"確保目錄存在: {directory}")
    
    def _get_file_path(self, category: str, filename: str) -> Path:
        """
        獲取檔案路徑
        
        Args:
            category: 類別（sessions, audio, transcripts, translations）
            filename: 檔案名稱
        
        Returns:
            完整檔案路徑
        """
        return self.data_dir / category / filename
    
    def save_json(self, category: str, filename: str, data: Dict[str, Any]) -> bool:
        """
        儲存 JSON 資料
        
        Args:
            category: 類別（sessions, audio, transcripts, translations）
            filename: 檔案名稱（不含副檔名）
            data: 要儲存的資料
        
        Returns:
            是否成功
        """
        try:
            file_path = self._get_file_path(category, f"{filename}.json")
            lock_path = file_path.with_suffix(".json.lock")
            
            # 使用檔案鎖避免並發寫入衝突
            with FileLock(str(lock_path), timeout=5):
                # 轉換特殊類型為可序列化格式
                json_data = self._serialize(data)
                
                with open(file_path, "w", encoding="utf-8") as f:
                    json.dump(json_data, f, ensure_ascii=False, indent=2)
                
                logger.info(f"儲存 JSON: {file_path}")
                return True
        
        except Exception as e:
            logger.error(f"儲存 JSON 失敗: {file_path}, error: {e}")
            return False
    
    def load_json(self, category: str, filename: str) -> Optional[Dict[str, Any]]:
        """
        載入 JSON 資料
        
        Args:
            category: 類別
            filename: 檔案名稱（不含副檔名）
        
        Returns:
            載入的資料，失敗時返回 None
        """
        try:
            file_path = self._get_file_path(category, f"{filename}.json")
            
            if not file_path.exists():
                logger.warning(f"檔案不存在: {file_path}")
                return None
            
            with open(file_path, "r", encoding="utf-8") as f:
                data = json.load(f)
            
            logger.debug(f"載入 JSON: {file_path}")
            return data
        
        except Exception as e:
            logger.error(f"載入 JSON 失敗: {file_path}, error: {e}")
            return None
    
    def delete_json(self, category: str, filename: str) -> bool:
        """
        刪除 JSON 檔案
        
        Args:
            category: 類別
            filename: 檔案名稱（不含副檔名）
        
        Returns:
            是否成功
        """
        try:
            file_path = self._get_file_path(category, f"{filename}.json")
            
            if file_path.exists():
                file_path.unlink()
                logger.info(f"刪除檔案: {file_path}")
                
                # 同時刪除鎖檔案
                lock_path = file_path.with_suffix(".json.lock")
                if lock_path.exists():
                    lock_path.unlink()
                
                return True
            else:
                logger.warning(f"檔案不存在，無法刪除: {file_path}")
                return False
        
        except Exception as e:
            logger.error(f"刪除檔案失敗: {file_path}, error: {e}")
            return False
    
    def list_files(self, category: str, pattern: str = "*.json") -> list:
        """
        列出目錄中的檔案
        
        Args:
            category: 類別
            pattern: 檔案模式（預設: *.json）
        
        Returns:
            檔案名稱列表（不含副檔名）
        """
        try:
            directory = self.data_dir / category
            files = [f.stem for f in directory.glob(pattern)]
            logger.debug(f"列出檔案: {directory}, 找到 {len(files)} 個")
            return files
        
        except Exception as e:
            logger.error(f"列出檔案失敗: {directory}, error: {e}")
            return []
    
    def _serialize(self, data: Any) -> Any:
        """
        序列化資料，轉換特殊類型為可序列化格式
        
        Args:
            data: 要序列化的資料
        
        Returns:
            可序列化的資料
        """
        if isinstance(data, dict):
            return {k: self._serialize(v) for k, v in data.items()}
        elif isinstance(data, list):
            return [self._serialize(v) for v in data]
        elif isinstance(data, (datetime,)):
            return data.isoformat()
        elif isinstance(data, UUID):
            return str(data)
        elif hasattr(data, "dict"):  # Pydantic models
            return self._serialize(data.dict())
        else:
            return data
    
    def get_directory_size(self, category: str) -> int:
        """
        獲取目錄大小（bytes）
        
        Args:
            category: 類別
        
        Returns:
            目錄大小（bytes）
        """
        try:
            directory = self.data_dir / category
            total_size = sum(f.stat().st_size for f in directory.rglob('*') if f.is_file())
            return total_size
        except Exception as e:
            logger.error(f"計算目錄大小失敗: {directory}, error: {e}")
            return 0
    
    def cleanup_old_files(self, category: str, days: int):
        """
        清理舊檔案
        
        Args:
            category: 類別
            days: 保留天數
        """
        try:
            directory = self.data_dir / category
            now = datetime.now()
            deleted_count = 0
            
            for file_path in directory.glob("*.json"):
                file_age = now - datetime.fromtimestamp(file_path.stat().st_mtime)
                if file_age.days > days:
                    file_path.unlink()
                    deleted_count += 1
                    logger.info(f"刪除過期檔案: {file_path}, 年齡: {file_age.days} 天")
            
            logger.info(f"清理完成: {directory}, 刪除 {deleted_count} 個檔案")
        
        except Exception as e:
            logger.error(f"清理檔案失敗: {directory}, error: {e}")


# 全局儲存服務實例（在 main.py 中初始化）
storage_service: Optional[StorageService] = None


def get_storage_service() -> StorageService:
    """獲取儲存服務實例"""
    if storage_service is None:
        raise RuntimeError("StorageService 尚未初始化")
    return storage_service


def init_storage_service(data_dir: str):
    """初始化儲存服務"""
    global storage_service
    storage_service = StorageService(data_dir)
    logger.info(f"儲存服務已初始化: {data_dir}")
