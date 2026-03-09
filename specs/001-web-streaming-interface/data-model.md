# Data Model: Web 音訊串流轉譯介面

**Date**: 2026-03-09  
**Purpose**: 定義系統的核心資料結構和關係

## 核心實體

### 1. Session（會話）

使用者的一次 WebSocket 連線會話。

**屬性**:
- `session_id`: string (UUID) - 唯一識別符
- `client_ip`: string - 客戶端 IP 位址
- `user_agent`: string - 瀏覽器 User-Agent
- `connect_time`: datetime - 連線時間
- `disconnect_time`: datetime | null - 斷線時間（進行中時為 null）
- `compute_mode`: enum - 運算模式（"server_gpu" | "local_openvino"）
- `source_lang`: string - 來源語言（"zh-TW" | "en"）
- `target_lang`: string - 目標語言（"zh-TW" | "en"）
- `enable_translation`: boolean - 是否啟用翻譯
- `status`: enum - 狀態（"active" | "completed" | "error"）

**儲存方式**: JSON 檔案 `data/sessions/{session_id}.json`

**生命週期**:
1. 客戶端連線 → 建立 Session（status: "active"）
2. 客戶端斷線/停止 → 更新 Session（status: "completed"）
3. 錯誤發生 → 更新 Session（status: "error"）

---

### 2. AudioStream（音訊串流）

即時音訊資料串流。

**屬性**:
- `stream_id`: string (UUID) - 唯一識別符
- `session_id`: string - 所屬會話 ID
- `start_time`: datetime - 串流開始時間
- `end_time`: datetime | null - 串流結束時間
- `audio_format`: object - 音訊格式資訊
  - `container`: string - 容器格式（"webm" | "wav"）
  - `codec`: string - 編碼格式（"opus" | "pcm"）
  - `sample_rate`: int - 取樣率（Hz）
  - `channels`: int - 聲道數（1=mono, 2=stereo）
  - `bit_depth`: int - 位元深度
- `total_chunks`: int - 總 chunk 數量
- `total_duration`: float - 總時長（秒）
- `file_path`: string - 儲存路徑（相對於 data/ 目錄）

**儲存方式**: 
- 元資料：JSON 檔案 `data/streams/{stream_id}.json`
- 音訊檔案：`data/audio/{session_id}/{stream_id}.wav`

**處理流程**:
1. 接收 WebM chunks → 暫存緩衝區
2. 每 N 秒或停止時 → 使用 ffmpeg 轉換為 WAV
3. 儲存 WAV 檔案 + 更新元資料

---

### 3. TranscriptionTask（轉譯任務）

一次完整的語音轉譯任務。

**屬性**:
- `task_id`: string (UUID) - 唯一識別符
- `session_id`: string - 所屬會話 ID
- `stream_id`: string - 音訊串流 ID
- `start_time`: datetime - 任務開始時間
- `end_time`: datetime | null - 任務結束時間
- `model_name`: string - 使用的模型（"large-v3-turbo"）
- `language`: string - 語言（"zh" | "en"）
- `compute_mode`: enum - 運算模式
- `status`: enum - 狀態（"pending" | "processing" | "completed" | "failed"）
- `segments`: array - 轉譯片段
  - `id`: int - 片段序號
  - `start`: float - 開始時間（秒）
  - `end`: float - 結束時間（秒）
  - `text`: string - 轉譯文字
  - `confidence`: float - 信心度（0-1）
- `full_text`: string - 完整轉譯文字
- `duration`: float - 音訊時長（秒）
- `processing_time`: float - 處理時間（秒）
- `error_message`: string | null - 錯誤訊息（失敗時）

**儲存方式**: JSON 檔案 `data/transcripts/{task_id}.json`

**處理流程**:
1. 建立任務（status: "pending"）
2. 調用 faster-whisper → 更新 status: "processing"
3. 接收轉譯結果 → 更新 segments 和 full_text
4. 完成 → 更新 status: "completed", end_time

---

### 4. TranslationResult（翻譯結果）

轉譯文字的翻譯結果。

**屬性**:
- `translation_id`: string (UUID) - 唯一識別符
- `task_id`: string - 所屬轉譯任務 ID
- `session_id`: string - 所屬會話 ID
- `source_text`: string - 來源文字
- `translated_text`: string - 翻譯文字
- `source_lang`: string - 來源語言
- `target_lang`: string - 目標語言
- `translation_service`: string - 翻譯服務（"ollama" | "argos"）
- `model_name`: string - 使用的模型（如 "qwen2.5:7b"）
- `timestamp`: datetime - 翻譯時間
- `processing_time`: float - 處理時間（秒）
- `error_message`: string | null - 錯誤訊息

**儲存方式**: JSON 檔案 `data/translations/{translation_id}.json`

**處理流程**:
1. 接收轉譯文字 → 建立翻譯任務
2. 優先嘗試 Ollama API
3. 失敗時降級使用 Argos Translate
4. 儲存結果

---

### 5. Config（配置）

系統和使用者的配置參數。

**屬性**:
- `server`:
  - `host`: string - Server 監聽位址（"0.0.0.0"）
  - `port`: int - Server 監聽埠（8000）
  - `allowed_origins`: array - CORS 允許的來源
- `transcription`:
  - `model_name`: string - Whisper 模型名稱
  - `model_path`: string - 模型檔案路徑
  - `device`: string - 運算裝置（"cuda" | "cpu"）
  - `compute_type`: string - 運算精度（"float16" | "int8"）
  - `language`: string | null - 固定語言（null 為自動偵測）
- `translation`:
  - `ollama_url`: string - Ollama Server URL
  - `ollama_model`: string - Ollama 模型名稱
  - `ollama_timeout`: int - Ollama 請求超時（秒）
  - `fallback_to_argos`: boolean - 是否降級使用 Argos
- `storage`:
  - `data_dir`: string - 資料目錄路徑
  - `max_audio_size_mb`: int - 單個音訊檔案最大大小（MB）
  - `retention_days`: int - 資料保留天數（0 為永久保留）
- `websocket`:
  - `max_connections`: int - 最大同時連線數
  - `ping_interval`: int - Ping 間隔（秒）
  - `ping_timeout`: int - Ping 超時（秒）

**儲存方式**: YAML 或 JSON 檔案 `webapp/backend/config.yaml`

---

## 資料關係圖

```
Session (1)
  ├─→ AudioStream (1..n)
  │     └─→ Audio File (.wav)
  │
  ├─→ TranscriptionTask (1..n)
  │     ├─→ Segments (0..n)
  │     └─→ Transcript File (.json)
  │
  └─→ TranslationResult (0..n)
        └─→ Translation File (.json)

Config (1) - 全局配置
```

**關鍵關係**:
- 一個 Session 可以有多個 AudioStream（如果使用者暫停後繼續）
- 一個 AudioStream 對應一個 TranscriptionTask
- 一個 TranscriptionTask 可以有多個 TranslationResult（如果切換翻譯設定）
- Session ID 作為主鍵關聯所有相關資料

---

## 檔案系統結構

```
data/
├── sessions/              # 會話元資料
│   └── {session_id}.json
│
├── audio/                 # 音訊檔案
│   └── {session_id}/
│       └── {stream_id}.wav
│
├── transcripts/           # 轉譯記錄
│   └── {task_id}.json
│
├── translations/          # 翻譯記錄
│   └── {translation_id}.json
│
└── logs/                  # 系統日誌
    ├── app.log
    └── error.log
```

**儲存策略**:
- 所有資料使用 JSON 格式儲存（易於查詢和偵錯）
- 使用 UUID 作為檔案名稱（避免衝突）
- 按 session_id 組織音訊檔案（便於清理）
- 定期清理過期資料（根據 retention_days 設定）

---

## 資料流程

### 1. 即時轉譯流程

```
客戶端連線
  ↓
建立 Session
  ↓
開始音訊串流
  ↓
建立 AudioStream
  ↓          ↓
儲存音訊    建立 TranscriptionTask
  ↓          ↓
           faster-whisper 處理
  ↓          ↓
           更新 segments
  ↓          ↓
           [如果啟用翻譯]
  ↓          ↓
           建立 TranslationResult
  ↓          ↓
           Ollama/Argos 翻譯
  ↓          ↓
           儲存翻譯結果
  ↓          ↓
WebSocket 即時推送結果
  ↓
客戶端斷線
  ↓
更新 Session 狀態
```

### 2. 資料查詢

管理員可透過 session_id 查詢：
- 會話資訊（連線時間、配置、狀態）
- 所有音訊檔案
- 完整轉譯記錄
- 翻譯結果

### 3. 資料清理

定期任務（cron）：
1. 掃描 `data/sessions/` 找出過期會話
2. 刪除對應的音訊檔案、轉譯記錄、翻譯記錄
3. 壓縮舊日誌檔案

---

## 實作注意事項

### 1. 並發控制
- 使用檔案鎖（filelock）避免同時寫入衝突
- WebSocket 連線使用 asyncio 處理，避免阻塞

### 2. 錯誤處理
- 所有 I/O 操作包裹 try-except
- 錯誤記錄到日誌和相應的實體（error_message 欄位）

### 3. 效能優化
- 音訊 chunks 緩衝批次處理（減少磁碟 I/O）
- 轉譯和翻譯並行處理（asyncio）
- 定期清理記憶體中的完成任務

### 4. 資料驗證
- 使用 Pydantic models 驗證所有資料結構
- 檔案大小限制（max_audio_size_mb）
- 連線數限制（max_connections）
