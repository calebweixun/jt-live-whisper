"""
音訊處理服務
負責音訊格式轉換和處理
"""
import os
import logging
import base64
import tempfile
import subprocess
from pathlib import Path
from typing import Optional
import asyncio

logger = logging.getLogger(__name__)


class AudioProcessorService:
    """音訊處理服務"""
    
    def __init__(self, data_dir: str):
        """
        初始化音訊處理服務
        
        Args:
            data_dir: 資料目錄路徑
        """
        self.data_dir = Path(data_dir)
        self.audio_dir = self.data_dir / "audio"
        self.audio_dir.mkdir(parents=True, exist_ok=True)
        self._check_ffmpeg()
    
    def _check_ffmpeg(self):
        """檢查 ffmpeg 是否可用"""
        try:
            result = subprocess.run(
                ["ffmpeg", "-version"],
                capture_output=True,
                text=True,
                timeout=5
            )
            if result.returncode == 0:
                logger.info("ffmpeg 可用")
            else:
                logger.warning("ffmpeg 不可用，音訊轉換功能將受限")
        except Exception as e:
            logger.warning(f"無法檢查 ffmpeg: {e}")
    
    async def convert_webm_to_wav(
        self,
        webm_data: bytes,
        output_path: Optional[Path] = None,
        sample_rate: int = 16000,
        channels: int = 1
    ) -> Optional[Path]:
        """
        轉換 WebM 音訊為 WAV 格式
        
        Args:
            webm_data: WebM 音訊資料（bytes）
            output_path: 輸出檔案路徑（可選，預設自動生成）
            sample_rate: 取樣率（Hz）
            channels: 聲道數（1=mono, 2=stereo）
        
        Returns:
            WAV 檔案路徑，失敗時返回 None
        """
        temp_webm = None
        try:
            # 建立臨時 WebM 檔案
            with tempfile.NamedTemporaryFile(suffix=".webm", delete=False) as f:
                f.write(webm_data)
                temp_webm = Path(f.name)
            
            # 生成輸出路徑
            if output_path is None:
                output_path = self.audio_dir / f"audio_{os.urandom(8).hex()}.wav"
            else:
                output_path.parent.mkdir(parents=True, exist_ok=True)
            
            # 使用 ffmpeg 轉換
            cmd = [
                "ffmpeg",
                "-i", str(temp_webm),
                "-ar", str(sample_rate),
                "-ac", str(channels),
                "-acodec", "pcm_s16le",
                "-y",  # 覆蓋已存在的檔案
                str(output_path)
            ]
            
            # 在背景執行 ffmpeg
            process = await asyncio.create_subprocess_exec(
                *cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            
            stdout, stderr = await process.communicate()
            
            if process.returncode == 0:
                logger.info(f"音訊轉換成功: {output_path}")
                return output_path
            else:
                logger.error(f"音訊轉換失敗: {stderr.decode()}")
                return None
        
        except Exception as e:
            logger.error(f"音訊轉換異常: {e}", exc_info=True)
            return None
        
        finally:
            # 清理臨時檔案
            if temp_webm and temp_webm.exists():
                try:
                    temp_webm.unlink()
                except Exception as e:
                    logger.warning(f"清理臨時檔案失敗: {e}")
    
    async def decode_and_convert_audio_chunk(
        self,
        base64_audio: str,
        session_id: str,
        chunk_index: int
    ) -> Optional[Path]:
        """
        解碼 Base64 音訊並轉換為 WAV
        
        Args:
            base64_audio: Base64 編碼的音訊資料
            session_id: 會話 ID
            chunk_index: Chunk 序號
        
        Returns:
            WAV 檔案路徑，失敗時返回 None
        """
        try:
            # 解碼 Base64
            audio_data = base64.b64decode(base64_audio)
            
            # 建立會話專屬目錄
            session_dir = self.audio_dir / session_id
            session_dir.mkdir(parents=True, exist_ok=True)
            
            # 生成輸出路徑
            output_path = session_dir / f"chunk_{chunk_index:04d}.wav"
            
            # 轉換音訊
            wav_path = await self.convert_webm_to_wav(
                audio_data,
                output_path=output_path
            )
            
            return wav_path
        
        except Exception as e:
            logger.error(f"解碼和轉換音訊失敗: {e}", exc_info=True)
            return None
    
    async def merge_audio_files(
        self,
        audio_files: list,
        output_path: Path
    ) -> Optional[Path]:
        """
        合併多個音訊檔案
        
        Args:
            audio_files: 音訊檔案路徑列表
            output_path: 輸出檔案路徑
        
        Returns:
            合併後的檔案路徑，失敗時返回 None
        """
        if not audio_files:
            logger.warning("沒有音訊檔案可合併")
            return None
        
        if len(audio_files) == 1:
            # 只有一個檔案，直接複製
            import shutil
            shutil.copy(audio_files[0], output_path)
            return output_path
        
        try:
            # 建立檔案列表文件
            with tempfile.NamedTemporaryFile(mode='w', suffix='.txt', delete=False) as f:
                for audio_file in audio_files:
                    f.write(f"file '{audio_file}'\n")
                file_list = Path(f.name)
            
            # 使用 ffmpeg concat 合併
            cmd = [
                "ffmpeg",
                "-f", "concat",
                "-safe", "0",
                "-i", str(file_list),
                "-c", "copy",
                "-y",
                str(output_path)
            ]
            
            process = await asyncio.create_subprocess_exec(
                *cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            
            stdout, stderr = await process.communicate()
            
            # 清理臨時檔案列表
            file_list.unlink()
            
            if process.returncode == 0:
                logger.info(f"音訊合併成功: {output_path}")
                return output_path
            else:
                logger.error(f"音訊合併失敗: {stderr.decode()}")
                return None
        
        except Exception as e:
            logger.error(f"音訊合併異常: {e}", exc_info=True)
            return None
    
    def get_audio_duration(self, audio_path: Path) -> Optional[float]:
        """
        獲取音訊時長
        
        Args:
            audio_path: 音訊檔案路徑
        
        Returns:
            音訊時長（秒），失敗時返回 None
        """
        try:
            cmd = [
                "ffprobe",
                "-v", "error",
                "-show_entries", "format=duration",
                "-of", "default=noprint_wrappers=1:nokey=1",
                str(audio_path)
            ]
            
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=5
            )
            
            if result.returncode == 0:
                duration = float(result.stdout.strip())
                return duration
            else:
                logger.error(f"獲取音訊時長失敗: {result.stderr}")
                return None
        
        except Exception as e:
            logger.error(f"獲取音訊時長異常: {e}")
            return None
    
    def delete_session_audio(self, session_id: str) -> bool:
        """
        刪除會話的所有音訊檔案
        
        Args:
            session_id: 會話 ID
        
        Returns:
            是否成功
        """
        try:
            session_dir = self.audio_dir / session_id
            if session_dir.exists():
                import shutil
                shutil.rmtree(session_dir)
                logger.info(f"刪除會話音訊: {session_id}")
                return True
            return False
        
        except Exception as e:
            logger.error(f"刪除會話音訊失敗: {e}")
            return False


# 全局音訊處理器實例（在 main.py 中初始化）
audio_processor: Optional[AudioProcessorService] = None


def get_audio_processor() -> AudioProcessorService:
    """獲取音訊處理器實例"""
    if audio_processor is None:
        raise RuntimeError("AudioProcessorService 尚未初始化")
    return audio_processor


def init_audio_processor(data_dir: str):
    """初始化音訊處理器"""
    global audio_processor
    audio_processor = AudioProcessorService(data_dir)
    logger.info(f"音訊處理器已初始化: {data_dir}")
