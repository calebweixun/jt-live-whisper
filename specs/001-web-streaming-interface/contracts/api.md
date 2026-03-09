# HTTP API 合約

**Date**: 2026-03-09  
**Purpose**: 定義後端 HTTP REST API 介面規格

## Base URL

```
http://{server_ip}:8000/api/v1
```

## 通用回應格式

### 成功回應
```json
{
  "success": true,
  "data": { ... },
  "timestamp": "2026-03-09T10:30:00Z"
}
```

### 錯誤回應
```json
{
  "success": false,
  "error": {
    "code": "ERROR_CODE",
    "message": "錯誤訊息（繁體中文）",
    "details": { ... }
  },
  "timestamp": "2026-03-09T10:30:00Z"
}
```

## 錯誤碼

| 錯誤碼 | HTTP Status | 說明 |
|--------|-------------|------|
| `INVALID_REQUEST` | 400 | 請求參數無效 |
| `SESSION_NOT_FOUND` | 404 | 會話不存在 |
| `GPU_UNAVAILABLE` | 503 | GPU 資源不可用 |
| `TRANSCRIPTION_FAILED` | 500 | 轉譯失敗 |
| `TRANSLATION_FAILED` | 500 | 翻譯失敗 |
| `STORAGE_ERROR` | 500 | 儲存錯誤 |
| `MAX_CONNECTIONS` | 429 | 超過最大連線數限制 |

---

## 端點

### 1. 健康檢查

**GET** `/health`

檢查服務健康狀態。

**回應**:
```json
{
  "success": true,
  "data": {
    "status": "healthy",
    "version": "1.0.0",
    "services": {
      "transcription": {
        "available": true,
        "model": "large-v3-turbo",
        "device": "cuda"
      },
      "translation": {
        "available": true,
        "service": "ollama",
        "model": "qwen2.5:7b"
      }
    },
    "statistics": {
      "active_connections": 3,
      "total_sessions": 142,
      "gpu_memory_used": "2.4 GB",
      "gpu_memory_total": "8.0 GB"
    }
  },
  "timestamp": "2026-03-09T10:30:00Z"
}
```

---

### 2. 獲取系統配置

**GET** `/config`

獲取客戶端需要的系統配置資訊。

**回應**:
```json
{
  "success": true,
  "data": {
    "supported_languages": ["zh-TW", "en"],
    "compute_modes": [
      {
        "id": "server_gpu",
        "name": "Server GPU",
        "description": "使用 Server 的 RTX 5060 顯卡運算",
        "available": true
      },
      {
        "id": "local_openvino",
        "name": "本地運算（OpenVINO）",
        "description": "使用您的裝置算力",
        "available": false,
        "reason": "此功能尚未實作"
      }
    ],
    "max_audio_duration": 3600,
    "websocket_url": "ws://{server_ip}:8000/ws"
  },
  "timestamp": "2026-03-09T10:30:00Z"
}
```

---

### 3. 獲取會話資訊

**GET** `/sessions/{session_id}`

獲取指定會話的詳細資訊。

**路徑參數**:
- `session_id`: string (UUID) - 會話 ID

**回應**:
```json
{
  "success": true,
  "data": {
    "session_id": "550e8400-e29b-41d4-a716-446655440000",
    "connect_time": "2026-03-09T10:00:00Z",
    "disconnect_time": "2026-03-09T10:15:00Z",
    "status": "completed",
    "config": {
      "compute_mode": "server_gpu",
      "source_lang": "en",
      "target_lang": "zh-TW",
      "enable_translation": true
    },
    "statistics": {
      "total_audio_duration": 900,
      "transcription_count": 15,
      "translation_count": 15,
      "total_processing_time": 45.2
    },
    "transcripts": [
      {
        "task_id": "abc123",
        "full_text": "Hello, how are you?",
        "timestamp": "2026-03-09T10:05:00Z"
      }
    ],
    "translations": [
      {
        "translation_id": "def456",
        "translated_text": "你好，你好嗎？",
        "timestamp": "2026-03-09T10:05:02Z"
      }
    ]
  },
  "timestamp": "2026-03-09T10:30:00Z"
}
```

---

### 4. 列出所有會話

**GET** `/sessions`

列出所有會話（分頁）。

**查詢參數**:
- `page`: int (預設: 1) - 頁碼
- `per_page`: int (預設: 20, 最大: 100) - 每頁數量
- `status`: string (可選) - 過濾狀態（active | completed | error）

**回應**:
```json
{
  "success": true,
  "data": {
    "sessions": [
      {
        "session_id": "xxx",
        "connect_time": "2026-03-09T10:00:00Z",
        "status": "completed",
        "config": { ... },
        "statistics": { ... }
      }
    ],
    "pagination": {
      "page": 1,
      "per_page": 20,
      "total": 142,
      "total_pages": 8
    }
  },
  "timestamp": "2026-03-09T10:30:00Z"
}
```

---

### 5. 刪除會話資料

**DELETE** `/sessions/{session_id}`

刪除指定會話的所有資料（包含音訊檔案、轉譯記錄、翻譯記錄）。

**路徑參數**:
- `session_id`: string (UUID) - 會話 ID

**回應**:
```json
{
  "success": true,
  "data": {
    "session_id": "550e8400-e29b-41d4-a716-446655440000",
    "deleted_files": {
      "audio": 3,
      "transcripts": 15,
      "translations": 15
    },
    "freed_space_mb": 124.5
  },
  "timestamp": "2026-03-09T10:30:00Z"
}
```

---

### 6. 下載轉譯記錄

**GET** `/sessions/{session_id}/transcript`

下載完整的轉譯記錄（文字檔案）。

**路徑參數**:
- `session_id`: string (UUID) - 會話 ID

**查詢參數**:
- `format`: string (預設: "txt") - 格式（txt | json | srt）

**回應** (format=txt):
```
Content-Type: text/plain
Content-Disposition: attachment; filename="transcript_{session_id}.txt"

[2026-03-09 10:05:00]
原文: Hello, how are you?
翻譯: 你好，你好嗎？

[2026-03-09 10:05:30]
原文: I'm doing great, thank you.
翻譯: 我很好，謝謝。
```

**回應** (format=json):
```json
Content-Type: application/json
Content-Disposition: attachment; filename="transcript_{session_id}.json"

{
  "session_id": "xxx",
  "created_at": "2026-03-09T10:00:00Z",
  "config": { ... },
  "transcript": [
    {
      "timestamp": "2026-03-09T10:05:00Z",
      "original": "Hello, how are you?",
      "translation": "你好，你好嗎？"
    }
  ]
}
```

---

### 7. 下載音訊檔案

**GET** `/sessions/{session_id}/audio`

下載會話的音訊檔案（合併所有 audio streams）。

**路徑參數**:
- `session_id`: string (UUID) - 會話 ID

**查詢參數**:
- `format`: string (預設: "wav") - 格式（wav | mp3）

**回應**:
```
Content-Type: audio/wav
Content-Disposition: attachment; filename="audio_{session_id}.wav"

[Binary audio data]
```

---

## 實作注意事項

### 1. CORS 設定
```python
from fastapi.middleware.cors import CORSMiddleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 區域網路內允許所有來源
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
```

### 2. 檔案大小限制
- 使用 FastAPI 的 `File` 和 `UploadFile`
- 設定 `max_size` 限制上傳大小

### 3. 錯誤處理
```python
from fastapi import HTTPException

@app.exception_handler(Exception)
async def global_exception_handler(request, exc):
    return JSONResponse(
        status_code=500,
        content={
            "success": False,
            "error": {
                "code": "INTERNAL_ERROR",
                "message": str(exc)
            },
            "timestamp": datetime.utcnow().isoformat()
        }
    )
```

### 4. 速率限制
- 使用 `slowapi` 中介軟體
- 限制每個 IP 的請求頻率

### 5. 日誌記錄
- 所有 API 請求記錄到 `data/logs/api.log`
- 包含請求時間、IP、端點、回應碼、處理時間
