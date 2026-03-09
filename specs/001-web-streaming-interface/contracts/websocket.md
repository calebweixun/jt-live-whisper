# WebSocket 協定合約

**Date**: 2026-03-09  
**Purpose**: 定義客戶端和 Server 之間的 WebSocket 即時通訊協定

## 連線端點

```
ws://{server_ip}:8000/ws
```

## 連線流程

```
客戶端                          Server
  |                               |
  |--- WebSocket Connect -------->|
  |                               |
  |<-- "connected" message -------|
  |    (session_id)               |
  |                               |
  |--- "start" message ---------->|
  |    (config)                   |
  |                               |
  |<-- "started" message ---------|
  |                               |
  |--- "audio_chunk" ------------>|
  |--- "audio_chunk" ------------>|
  |--- "audio_chunk" ------------>|
  |                               |
  |<-- "transcription" -----------|
  |<-- "translation" -------------|
  |                               |
  |--- "stop" message ----------->|
  |                               |
  |<-- "stopped" message ---------|
  |<-- "final_result" ------------|
  |                               |
  |--- WebSocket Close ---------->|
  |<-- Close Ack -----------------|
```

---

## 訊息格式

所有訊息使用 JSON 格式，包含 `type` 欄位指定訊息類型。

### 基本結構

```json
{
  "type": "message_type",
  "data": { ... },
  "timestamp": 1234567890
}
```

---

## 客戶端 → Server 訊息

### 1. start - 開始轉譯

客戶端請求開始音訊串流和轉譯。

```json
{
  "type": "start",
  "data": {
    "compute_mode": "server_gpu",
    "source_lang": "en",
    "target_lang": "zh-TW",
    "enable_translation": true
  },
  "timestamp": 1234567890
}
```

**欄位說明**:
- `compute_mode`: string - 運算模式（"server_gpu" | "local_openvino"）
- `source_lang`: string - 來源語言（"zh-TW" | "en"）
- `target_lang`: string - 目標語言（"zh-TW" | "en"）
- `enable_translation`: boolean - 是否啟用翻譯

---

### 2. audio_chunk - 音訊資料塊

客戶端發送音訊資料。

```json
{
  "type": "audio_chunk",
  "data": {
    "audio": "<base64_encoded_audio_data>",
    "format": {
      "container": "webm",
      "codec": "opus",
      "sample_rate": 48000,
      "channels": 1
    },
    "chunk_index": 0,
    "is_last": false
  },
  "timestamp": 1234567890
}
```

**欄位說明**:
- `audio`: string (base64) - Base64 編碼的音訊資料
- `format`: object - 音訊格式資訊
- `chunk_index`: int - Chunk 序號（從 0 開始）
- `is_last`: boolean - 是否為最後一個 chunk

**資料大小限制**: 每個 chunk 不超過 1MB

---

### 3. pause - 暫停

客戶端請求暫停音訊串流（保留會話）。

```json
{
  "type": "pause",
  "timestamp": 1234567890
}
```

---

### 4. resume - 繼續

客戶端請求繼續音訊串流。

```json
{
  "type": "resume",
  "timestamp": 1234567890
}
```

---

### 5. stop - 停止

客戶端請求停止並結束會話。

```json
{
  "type": "stop",
  "timestamp": 1234567890
}
```

---

### 6. ping - 保持連線

客戶端發送 ping（Server 會自動回應 pong）。

```json
{
  "type": "ping",
  "timestamp": 1234567890
}
```

---

## Server → 客戶端訊息

### 1. connected - 連線成功

Server 確認 WebSocket 連線建立。

```json
{
  "type": "connected",
  "data": {
    "session_id": "550e8400-e29b-41d4-a716-446655440000",
    "server_version": "1.0.0",
    "capabilities": {
      "transcription": true,
      "translation": true,
      "local_compute": false
    }
  },
  "timestamp": 1234567890
}
```

---

### 2. started - 開始成功

Server 確認已開始處理音訊串流。

```json
{
  "type": "started",
  "data": {
    "session_id": "550e8400-e29b-41d4-a716-446655440000",
    "stream_id": "abc123",
    "config": {
      "compute_mode": "server_gpu",
      "source_lang": "en",
      "target_lang": "zh-TW",
      "enable_translation": true
    }
  },
  "timestamp": 1234567890
}
```

---

### 3. transcription - 轉譯結果

Server 發送即時轉譯結果。

```json
{
  "type": "transcription",
  "data": {
    "task_id": "task123",
    "text": "Hello, how are you?",
    "start_time": 0.0,
    "end_time": 2.5,
    "confidence": 0.95,
    "is_final": true,
    "language": "en"
  },
  "timestamp": 1234567890
}
```

**欄位說明**:
- `task_id`: string - 轉譯任務 ID
- `text`: string - 轉譯文字
- `start_time`: float - 開始時間（秒）
- `end_time`: float - 結束時間（秒）
- `confidence`: float - 信心度（0-1）
- `is_final`: boolean - 是否為最終結果（部分結果 is_final=false）
- `language`: string - 偵測到的語言

---

### 4. translation - 翻譯結果

Server 發送翻譯結果。

```json
{
  "type": "translation",
  "data": {
    "translation_id": "trans123",
    "task_id": "task123",
    "source_text": "Hello, how are you?",
    "translated_text": "你好，你好嗎？",
    "source_lang": "en",
    "target_lang": "zh-TW",
    "service": "ollama",
    "processing_time": 0.8
  },
  "timestamp": 1234567892
}
```

---

### 5. processing - 處理狀態

Server 發送處理進度資訊。

```json
{
  "type": "processing",
  "data": {
    "stage": "transcribing",
    "progress": 0.65,
    "message": "正在轉譯音訊..."
  },
  "timestamp": 1234567890
}
```

**stage 類型**:
- `"receiving"`: 接收音訊資料
- `"transcribing"`: 轉譯中
- `"translating"`: 翻譯中
- `"saving"`: 儲存資料

---

### 6. paused - 暫停成功

Server 確認已暫停。

```json
{
  "type": "paused",
  "data": {
    "total_chunks_received": 25,
    "total_duration": 25.0
  },
  "timestamp": 1234567890
}
```

---

### 7. resumed - 繼續成功

Server 確認已繼續。

```json
{
  "type": "resumed",
  "timestamp": 1234567890
}
```

---

### 8. stopped - 停止成功

Server 確認已停止會話。

```json
{
  "type": "stopped",
  "data": {
    "session_id": "550e8400-e29b-41d4-a716-446655440000",
    "total_duration": 125.5,
    "total_chunks": 125,
    "transcription_count": 42,
    "translation_count": 42
  },
  "timestamp": 1234567890
}
```

---

### 9. final_result - 最終結果

Server 發送完整的會話結果摘要。

```json
{
  "type": "final_result",
  "data": {
    "session_id": "550e8400-e29b-41d4-a716-446655440000",
    "full_transcript": "Hello, how are you? I'm doing great...",
    "full_translation": "你好，你好嗎？我很好...",
    "statistics": {
      "total_duration": 125.5,
      "processing_time": 8.2,
      "word_count": 342,
      "average_confidence": 0.94
    },
    "files": {
      "audio": "/api/v1/sessions/{session_id}/audio",
      "transcript": "/api/v1/sessions/{session_id}/transcript"
    }
  },
  "timestamp": 1234567890
}
```

---

### 10. error - 錯誤

Server 發送錯誤訊息。

```json
{
  "type": "error",
  "data": {
    "code": "GPU_UNAVAILABLE",
    "message": "Server GPU 無法使用",
    "details": {
      "reason": "CUDA out of memory",
      "suggestion": "請切換到本地運算模式或稍後再試"
    },
    "recoverable": true
  },
  "timestamp": 1234567890
}
```

**錯誤碼**:
- `GPU_UNAVAILABLE`: GPU 不可用
- `TRANSCRIPTION_FAILED`: 轉譯失敗
- `TRANSLATION_FAILED`: 翻譯失敗
- `AUDIO_FORMAT_ERROR`: 音訊格式錯誤
- `STORAGE_ERROR`: 儲存錯誤
- `MAX_DURATION_EXCEEDED`: 超過最大時長限制
- `INVALID_CONFIG`: 配置無效

**recoverable**:
- `true`: 可恢復錯誤（如 GPU 暫時不可用）
- `false`: 致命錯誤（需要重新連線）

---

### 11. pong - Ping 回應

Server 回應客戶端的 ping。

```json
{
  "type": "pong",
  "timestamp": 1234567890
}
```

---

## 連線管理

### Ping/Pong 機制

- 客戶端每 30 秒發送一次 `ping`
- Server 必須在 10 秒內回應 `pong`
- 如果 3 次 ping 無回應，客戶端應斷線重連

### 重新連線

客戶端斷線後可使用相同的 `session_id` 重新連線：

```json
{
  "type": "reconnect",
  "data": {
    "session_id": "550e8400-e29b-41d4-a716-446655440000"
  },
  "timestamp": 1234567890
}
```

Server 會恢復之前的會話狀態。

### 超時設定

- **連線超時**: 30 秒無活動自動斷線
- **處理超時**: 單個 chunk 處理超過 10 秒回報 error
- **最大會話時長**: 1 小時（可配置）

---

## 實作範例

### 客戶端 JavaScript

```javascript
class TranscriptionWebSocket {
  constructor(serverUrl) {
    this.ws = new WebSocket(`ws://${serverUrl}/ws`);
    this.sessionId = null;
    
    this.ws.onopen = () => {
      console.log('WebSocket connected');
    };
    
    this.ws.onmessage = (event) => {
      const message = JSON.parse(event.data);
      this.handleMessage(message);
    };
    
    this.ws.onerror = (error) => {
      console.error('WebSocket error:', error);
    };
    
    this.ws.onclose = () => {
      console.log('WebSocket closed');
    };
  }
  
  handleMessage(message) {
    switch (message.type) {
      case 'connected':
        this.sessionId = message.data.session_id;
        break;
      case 'transcription':
        this.displayTranscription(message.data.text);
        break;
      case 'translation':
        this.displayTranslation(message.data.translated_text);
        break;
      case 'error':
        this.handleError(message.data);
        break;
    }
  }
  
  start(config) {
    this.send({
      type: 'start',
      data: config,
      timestamp: Date.now()
    });
  }
  
  sendAudioChunk(audioData, chunkIndex, isLast) {
    this.send({
      type: 'audio_chunk',
      data: {
        audio: this.arrayBufferToBase64(audioData),
        format: {
          container: 'webm',
          codec: 'opus',
          sample_rate: 48000,
          channels: 1
        },
        chunk_index: chunkIndex,
        is_last: isLast
      },
      timestamp: Date.now()
    });
  }
  
  stop() {
    this.send({
      type: 'stop',
      timestamp: Date.now()
    });
  }
  
  send(message) {
    this.ws.send(JSON.stringify(message));
  }
  
  arrayBufferToBase64(buffer) {
    const bytes = new Uint8Array(buffer);
    let binary = '';
    for (let i = 0; i < bytes.byteLength; i++) {
      binary += String.fromCharCode(bytes[i]);
    }
    return btoa(binary);
  }
}
```

### Server FastAPI

```python
from fastapi import WebSocket, WebSocketDisconnect
import json
import base64
from datetime import datetime

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await websocket.accept()
    session_id = str(uuid.uuid4())
    
    # 發送 connected 訊息
    await websocket.send_json({
        "type": "connected",
        "data": {
            "session_id": session_id,
            "server_version": "1.0.0",
            "capabilities": {
                "transcription": True,
                "translation": True,
                "local_compute": False
            }
        },
        "timestamp": int(datetime.now().timestamp())
    })
    
    try:
        while True:
            message = await websocket.receive_json()
            await handle_message(websocket, session_id, message)
    except WebSocketDisconnect:
        await cleanup_session(session_id)

async def handle_message(websocket: WebSocket, session_id: str, message: dict):
    msg_type = message.get("type")
    
    if msg_type == "start":
        # 處理開始請求
        config = message["data"]
        await start_transcription(websocket, session_id, config)
    
    elif msg_type == "audio_chunk":
        # 處理音訊 chunk
        audio_data = base64.b64decode(message["data"]["audio"])
        await process_audio_chunk(websocket, session_id, audio_data)
    
    elif msg_type == "stop":
        # 處理停止請求
        await stop_transcription(websocket, session_id)
    
    elif msg_type == "ping":
        # 回應 pong
        await websocket.send_json({
            "type": "pong",
            "timestamp": int(datetime.now().timestamp())
        })
```

---

## 安全性考量

### 1. 資料驗證
- 所有訊息必須驗證 `type` 欄位
- 音訊資料大小限制（單個 chunk < 1MB）
- Base64 解碼錯誤處理

### 2. 連線限制
- 每個 IP 最多 5 個同時連線
- 單個連線最長 1 小時（可配置）

### 3. 錯誤處理
- 所有異常捕獲並回報 error 訊息
- 致命錯誤主動斷開連線

### 4. 資源清理
- 斷線時自動清理記憶體中的暫存資料
- 定期檢查zombi 會話並清理
