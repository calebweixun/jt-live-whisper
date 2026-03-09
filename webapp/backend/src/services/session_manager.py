"""
會話管理服務
負責管理使用者會話的生命週期
"""
import logging
from typing import Optional, Dict, Any, List
from datetime import datetime
from uuid import UUID, uuid4

from ..models.session import Session, SessionStatus, ComputeMode, SessionCreate
from ..services.storage import get_storage_service

logger = logging.getLogger(__name__)


class SessionManager:
    """會話管理器"""
    
    def __init__(self):
        """初始化會話管理器"""
        self.active_sessions: Dict[str, Session] = {}
        self.storage = get_storage_service()
    
    def create_session(
        self,
        client_ip: str,
        user_agent: str,
        config: SessionCreate
    ) -> Session:
        """
        建立新會話
        
        Args:
            client_ip: 客戶端 IP
            user_agent: 瀏覽器 User-Agent
            config: 會話配置
        
        Returns:
            新建立的會話
        """
        try:
            session = Session(
                client_ip=client_ip,
                user_agent=user_agent,
                compute_mode=config.compute_mode,
                source_lang=config.source_lang,
                target_lang=config.target_lang,
                enable_translation=config.enable_translation,
                status=SessionStatus.ACTIVE
            )
            
            # 儲存到記憶體
            self.active_sessions[str(session.session_id)] = session
            
            # 持久化
            self._save_session(session)
            
            logger.info(f"建立會話: {session.session_id}")
            return session
        
        except Exception as e:
            logger.error(f"建立會話失敗: {e}", exc_info=True)
            raise
    
    def get_session(self, session_id: str) -> Optional[Session]:
        """
        獲取會話
        
        Args:
            session_id: 會話 ID
        
        Returns:
            會話物件，不存在時返回 None
        """
        # 先從記憶體查找
        if session_id in self.active_sessions:
            return self.active_sessions[session_id]
        
        # 從儲存載入
        session_data = self.storage.load_json("sessions", session_id)
        if session_data:
            try:
                session = Session(**session_data)
                # 載入後放入記憶體
                self.active_sessions[session_id] = session
                return session
            except Exception as e:
                logger.error(f"解析會話資料失敗: {e}")
                return None
        
        return None
    
    def update_session_status(
        self,
        session_id: str,
        status: SessionStatus,
        disconnect_time: Optional[datetime] = None
    ) -> bool:
        """
        更新會話狀態
        
        Args:
            session_id: 會話 ID
            status: 新狀態
            disconnect_time: 斷線時間（可選）
        
        Returns:
            是否成功
        """
        try:
            session = self.get_session(session_id)
            if not session:
                logger.warning(f"會話不存在: {session_id}")
                return False
            
            session.status = status
            if disconnect_time:
                session.disconnect_time = disconnect_time
            
            # 持久化
            self._save_session(session)
            
            # 如果會話結束，從活動會話中移除
            if status in [SessionStatus.COMPLETED, SessionStatus.ERROR]:
                self.active_sessions.pop(session_id, None)
                logger.info(f"會話結束: {session_id}, status={status}")
            
            return True
        
        except Exception as e:
            logger.error(f"更新會話狀態失敗: {e}", exc_info=True)
            return False
    
    def _save_session(self, session: Session) -> bool:
        """
        儲存會話到檔案
        
        Args:
            session: 會話物件
        
        Returns:
            是否成功
        """
        try:
            session_dict = session.dict()
            return self.storage.save_json(
                "sessions",
                str(session.session_id),
                session_dict
            )
        except Exception as e:
            logger.error(f"儲存會話失敗: {e}")
            return False
    
    def list_sessions(
        self,
        status: Optional[SessionStatus] = None,
        limit: int = 100
    ) -> List[Session]:
        """
        列出會話
        
        Args:
            status: 過濾狀態（可選）
            limit: 最大數量
        
        Returns:
            會話列表
        """
        try:
            session_files = self.storage.list_files("sessions")
            sessions = []
            
            for session_id in session_files[:limit]:
                session = self.get_session(session_id)
                if session:
                    if status is None or session.status == status:
                        sessions.append(session)
            
            # 按連線時間排序（最新的在前）
            sessions.sort(key=lambda s: s.connect_time, reverse=True)
            return sessions
        
        except Exception as e:
            logger.error(f"列出會話失敗: {e}")
            return []
    
    def delete_session(self, session_id: str) -> bool:
        """
        刪除會話及其所有資料
        
        Args:
            session_id: 會話 ID
        
        Returns:
            是否成功
        """
        try:
            # 從記憶體移除
            self.active_sessions.pop(session_id, None)
            
            # 刪除會話檔案
            self.storage.delete_json("sessions", session_id)
            
            # TODO: 刪除關聯的音訊、轉譯、翻譯檔案
            
            logger.info(f"刪除會話: {session_id}")
            return True
        
        except Exception as e:
            logger.error(f"刪除會話失敗: {e}")
            return False
    
    def get_active_session_count(self) -> int:
        """獲取活動會話數量"""
        return len(self.active_sessions)
    
    def get_session_statistics(self, session_id: str) -> Optional[Dict[str, Any]]:
        """
        獲取會話統計資訊
        
        Args:
            session_id: 會話 ID
        
        Returns:
            統計資訊
        """
        # TODO: 實作完整的統計功能
        return {
            "total_audio_duration": 0.0,
            "transcription_count": 0,
            "translation_count": 0,
            "total_processing_time": 0.0
        }


# 全局會話管理器實例（在 main.py 中初始化）
session_manager: Optional[SessionManager] = None


def get_session_manager() -> SessionManager:
    """獲取會話管理器實例"""
    if session_manager is None:
        raise RuntimeError("SessionManager 尚未初始化")
    return session_manager


def init_session_manager():
    """初始化會話管理器"""
    global session_manager
    session_manager = SessionManager()
    logger.info("會話管理器已初始化")
