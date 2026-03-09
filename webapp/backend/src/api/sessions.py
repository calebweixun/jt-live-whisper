"""
會話管理 API
提供會話查詢和管理功能
"""
import logging
from fastapi import APIRouter, HTTPException, Query
from typing import Dict, Any, List, Optional
from datetime import datetime

from ..models.session import SessionResponse
from ..services.session_manager import get_session_manager

logger = logging.getLogger(__name__)
router = APIRouter()


@router.get("/sessions/{session_id}", response_model=Dict[str, Any])
async def get_session(session_id: str) -> Dict[str, Any]:
    """
    獲取會話詳情
    
    Args:
        session_id: 會話 ID
    
    Returns:
        會話詳細資訊
    """
    try:
        session_manager = get_session_manager()
        session = session_manager.get_session(session_id)
        
        if not session:
            raise HTTPException(status_code=404, detail=f"會話不存在: {session_id}")
        
        # 獲取會話統計資訊
        statistics = session_manager.get_session_statistics(session_id)
        
        return {
            "success": True,
            "data": {
                "session": {
                    "session_id": str(session.session_id),
                    "client_ip": session.client_ip,
                    "user_agent": session.user_agent,
                    "status": session.status.value,
                    "compute_mode": session.compute_mode.value,
                    "source_lang": session.source_lang,
                    "target_lang": session.target_lang,
                    "enable_translation": session.enable_translation,
                    "connect_time": session.connect_time.isoformat(),
                    "disconnect_time": session.disconnect_time.isoformat() if session.disconnect_time else None,
                    "last_activity": session.last_activity.isoformat() if session.last_activity else None
                },
                "statistics": statistics or {
                    "total_audio_duration": 0,
                    "transcription_count": 0,
                    "translation_count": 0,
                    "error_count": 0
                }
            },
            "timestamp": datetime.utcnow().isoformat()
        }
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"獲取會話失敗: {e}", exc_info=True)
        return {
            "success": False,
            "error": {
                "code": "GET_SESSION_ERROR",
                "message": str(e)
            },
            "timestamp": datetime.utcnow().isoformat()
        }


@router.get("/sessions", response_model=Dict[str, Any])
async def list_sessions(
    limit: int = Query(default=20, ge=1, le=100, description="每頁數量"),
    offset: int = Query(default=0, ge=0, description="偏移量"),
    status: Optional[str] = Query(default=None, description="篩選狀態 (ACTIVE, COMPLETED, ERROR)"),
    sort_by: str = Query(default="connect_time", description="排序欄位"),
    sort_order: str = Query(default="desc", description="排序順序 (asc, desc)")
) -> Dict[str, Any]:
    """
    列出會話
    
    Args:
        limit: 每頁數量 (1-100)
        offset: 偏移量
        status: 篩選狀態
        sort_by: 排序欄位
        sort_order: 排序順序
    
    Returns:
        會話列表
    """
    try:
        session_manager = get_session_manager()
        
        # 獲取所有會話
        all_sessions = session_manager.list_sessions()
        
        # 篩選狀態
        if status:
            all_sessions = [s for s in all_sessions if s.status.value == status.upper()]
        
        # 排序
        reverse = (sort_order.lower() == "desc")
        if sort_by == "connect_time":
            all_sessions.sort(key=lambda s: s.connect_time, reverse=reverse)
        elif sort_by == "disconnect_time":
            all_sessions.sort(
                key=lambda s: s.disconnect_time or datetime.min,
                reverse=reverse
            )
        elif sort_by == "status":
            all_sessions.sort(key=lambda s: s.status.value, reverse=reverse)
        
        # 分頁
        total = len(all_sessions)
        sessions = all_sessions[offset:offset + limit]
        
        # 格式化輸出
        session_list = []
        for session in sessions:
            session_list.append({
                "session_id": str(session.session_id),
                "client_ip": session.client_ip,
                "status": session.status.value,
                "compute_mode": session.compute_mode.value,
                "source_lang": session.source_lang,
                "target_lang": session.target_lang,
                "connect_time": session.connect_time.isoformat(),
                "disconnect_time": session.disconnect_time.isoformat() if session.disconnect_time else None
            })
        
        return {
            "success": True,
            "data": {
                "sessions": session_list,
                "pagination": {
                    "total": total,
                    "limit": limit,
                    "offset": offset,
                    "has_more": (offset + limit) < total
                }
            },
            "timestamp": datetime.utcnow().isoformat()
        }
    
    except Exception as e:
        logger.error(f"列出會話失敗: {e}", exc_info=True)
        return {
            "success": False,
            "error": {
                "code": "LIST_SESSIONS_ERROR",
                "message": str(e)
            },
            "timestamp": datetime.utcnow().isoformat()
        }


@router.delete("/sessions/{session_id}", response_model=Dict[str, Any])
async def delete_session(session_id: str) -> Dict[str, Any]:
    """
    刪除會話及相關資料
    
    Args:
        session_id: 會話 ID
    
    Returns:
        刪除結果
    """
    try:
        session_manager = get_session_manager()
        
        # 檢查會話是否存在
        session = session_manager.get_session(session_id)
        if not session:
            raise HTTPException(status_code=404, detail=f"會話不存在: {session_id}")
        
        # 刪除會話
        success = session_manager.delete_session(session_id)
        
        if not success:
            return {
                "success": False,
                "error": {
                    "code": "DELETE_FAILED",
                    "message": "刪除會話失敗"
                },
                "timestamp": datetime.utcnow().isoformat()
            }
        
        return {
            "success": True,
            "data": {
                "session_id": session_id,
                "message": "會話已成功刪除"
            },
            "timestamp": datetime.utcnow().isoformat()
        }
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"刪除會話失敗: {e}", exc_info=True)
        return {
            "success": False,
            "error": {
                "code": "DELETE_SESSION_ERROR",
                "message": str(e)
            },
            "timestamp": datetime.utcnow().isoformat()
        }
