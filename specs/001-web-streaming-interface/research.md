# Research: Web 音訊串流轉譯介面

**Date**: 2026-03-09  
**Purpose**: 解決技術實作中的未知問題，確保設計決策基於可行性研究

## 研究任務

### R1: WebRTC 音訊串流到 Server 的最佳實踐

**問題**: 如何在瀏覽器中擷取麥克風音訊並即時串流到 Server？

**研究發現**:
- **技術選擇**: 使用 `MediaRecorder API` + WebSocket 是最簡單的方案
  - 不需要完整的 WebRTC peer connection（過於複雜）
  - `navigator.mediaDevices.getUserMedia()` 擷取麥克風
  - `MediaRecorder` 將音訊編碼為 WebM/Opus 格式
  - WebSocket 即時傳送音訊 chunks 到 Server
  
- **音訊格式**: 
  - 瀏覽器端：WebM 容器 + Opus 編碼（瀏覽器原生支援，效率高）
  - Server 端：使用 ffmpeg 轉換為 WAV 16kHz mono（faster-whisper 輸入格式）
  
- **串流參數**:
  - `timeslice: 1000ms`（每秒發送一個 chunk，平衡延遲和效率）
  - Sample rate: 48kHz（瀏覽器預設）
  - Channels: 1 (mono)

**決策**: 使用 MediaRecorder API + WebSocket，不使用完整的 WebRTC。

**參考資料**:
- MDN MediaRecorder: https://developer.mozilla.org/en-US/docs/Web/API/MediaRecorder
- WebSocket Protocol: RFC 6455

---

### R2: faster-whisper 在 Docker + GPU 環境配置

**問題**: 如何在 Docker 容器中讓 faster-whisper 使用 NVIDIA GPU (RTX 5060)？

**研究發現**:
- **基礎映像**: 使用 `nvidia/cuda:12.1.1-cudnn8-runtime-ubuntu22.04`
- **依賴安裝**:
  ```dockerfile
  # CUDA 相關
  nvidia/cuda base image 已包含 CUDA toolkit
  
  # CTranslate2 (faster-whisper 的核心)
  pip install faster-whisper>=0.10.0
  
  # 音訊處理
  apt-get install ffmpeg
  ```
  
- **Docker Compose 配置**:
  ```yaml
  services:
    backend:
      runtime: nvidia
      environment:
        - NVIDIA_VISIBLE_DEVICES=all
        - CUDA_VISIBLE_DEVICES=0
  ```
  
- **模型預先下載**: 
  - 在 Dockerfile 中下載模型到 `/models/` 目錄
  - 模型選擇：`large-v3-turbo`（最新，速度快且準確）
  
- **效能考量**:
  - RTX 5060 8GB VRAM 足夠運行 large-v3-turbo
  - 預期轉譯速度：即時音訊 30 秒內完成（約 3-5 秒實際處理時間）

**決策**: 使用 NVIDIA CUDA base image + faster-whisper + Docker runtime nvidia。

**參考資料**:
- faster-whisper GitHub: https://github.com/SYSTRAN/faster-whisper
- NVIDIA Container Toolkit: https://github.com/NVIDIA/nvidia-container-toolkit

---

### R3: Ollama LLM 翻譯服務整合

**問題**: 如何透過 API 呼叫 Ollama 進行翻譯？

**研究發現**:
- **Ollama API**: OpenAI 相容的 HTTP API
  - Endpoint: `POST http://localhost:11434/v1/chat/completions`
  - 或使用原生 API: `POST http://localhost:11434/api/generate`
  
- **API 呼叫範例**:
  ```python
  import httpx
  
  async def translate_text(text: str, source_lang: str, target_lang: str):
      async with httpx.AsyncClient() as client:
          response = await client.post(
              "http://ollama-server:11434/api/generate",
              json={
                  "model": "qwen2.5:7b",
                  "prompt": f"將以下{source_lang}翻譯為{target_lang}，只輸出翻譯結果：{text}",
                  "stream": False
              },
              timeout=10.0
          )
          return response.json()["response"]
  ```
  
- **模型選擇**: `qwen2.5:7b` 或 `phi4:14b`（平衡速度和品質）
- **降級方案**: Ollama 不可用時使用 Argos Translate（完全離線）

**決策**: 優先使用 Ollama API，降級使用 Argos Translate。

**參考資料**:
- Ollama API Doc: https://github.com/ollama/ollama/blob/main/docs/api.md

---

### R4: OpenVINO 在瀏覽器中的實作（本地運算模式）

**問題**: 如何在瀏覽器中使用 OpenVINO 進行本地轉譯？

**研究發現**:
- **技術挑戰**: OpenVINO 原生不支援瀏覽器環境
  - OpenVINO 是 C++ 框架，需要編譯為 WebAssembly
  - Whisper 模型轉換為 OpenVINO IR 格式，然後編譯為 WASM
  
- **替代方案 1**: 使用 whisper.cpp 的 WASM build
  - whisper.cpp 已有官方 WASM 版本
  - 模型轉換：Whisper → GGML 格式
  - 在瀏覽器中載入 WASM + GGML 模型
  - 預期模型大小：base 模型約 150MB，small 約 500MB
  
- **替代方案 2**: 使用 Transformers.js
  - Hugging Face 的官方瀏覽器 AI 庫
  - 支援 Whisper 模型，自動使用 WASM backend
  - 更簡單的 API，但可能效能較低
  
- **效能比較**:
  - whisper.cpp WASM: 更快（5-10x）但整合複雜
  - Transformers.js: 更簡單但較慢

**決策**: P3 功能（本地運算）使用 whisper.cpp WASM 版本。如果時間不足，可先實作 Server GPU 模式（P1、P2），P3 延後。

**參考資料**:
- whisper.cpp WASM: https://github.com/ggerganov/whisper.cpp/tree/master/examples/whisper.wasm
- Transformers.js: https://huggingface.co/docs/transformers.js

---

### R5: WebSocket 即時通訊協定設計

**問題**: 前端和後端的 WebSocket 訊息格式如何設計？

**研究發現**:
- **連線流程**:
  1. 客戶端發送 `connect` 訊息（包含運算模式、語言設定）
  2. Server 回應 `connected`（包含 session_id）
  3. 客戶端開始發送音訊 chunks
  4. Server 即時回傳轉譯結果和翻譯結果
  5. 客戶端發送 `stop`，Server 回應最終結果

- **訊息格式** (JSON):
  ```json
  // 客戶端 → Server
  {
    "type": "start",
    "config": {
      "compute_mode": "server_gpu",
      "source_lang": "en",
      "target_lang": "zh-TW",
      "enable_translation": true
    }
  }
  
  // 客戶端 → Server (音訊資料)
  {
    "type": "audio_chunk",
    "data": "<base64_encoded_audio>",
    "timestamp": 1234567890
  }
  
  // Server → 客戶端 (轉譯結果)
  {
    "type": "transcription",
    "text": "Hello world",
    "timestamp": 1234567890,
    "is_final": false
  }
  
  // Server → 客戶端 (翻譯結果)
  {
    "type": "translation",
    "text": "你好世界",
    "timestamp": 1234567890
  }
  ```

- **錯誤處理**:
  ```json
  {
    "type": "error",
    "code": "GPU_UNAVAILABLE",
    "message": "Server GPU 無法使用，請切換到本地運算模式"
  }
  ```

**決策**: 使用 JSON 格式的 WebSocket 訊息，音訊資料 base64 編碼傳輸。

**參考資料**:
- FastAPI WebSocket: https://fastapi.tiangolo.com/advanced/websockets/

---

## 研究總結

### 已解決的問題
1. ✅ 音訊串流技術：MediaRecorder + WebSocket
2. ✅ GPU 環境配置：NVIDIA CUDA Docker + faster-whisper
3. ✅ 翻譯服務整合：Ollama API + Argos 降級
4. ✅ WebSocket 協定：JSON 訊息格式

### 待決策的問題
1. ⚠️ 本地運算模式（P3）：whisper.cpp WASM vs Transformers.js
   - **建議**: 優先實作 P1、P2（Server GPU 模式），P3 可在後續迭代中實作

### 技術風險評估
- **低風險**: 音訊串流、GPU 配置、翻譯服務（成熟技術）
- **中風險**: 瀏覽器相容性、多使用者同時連線效能
- **高風險**: 本地運算模式（WASM 整合複雜度高）

### 建議實作順序
1. Phase 1: 實作 Server GPU 模式（P1、P2）
2. Phase 2: 完善錯誤處理和 UI
3. Phase 3: Docker 容器化（P4）
4. Phase 4 (選用): 本地運算模式（P3）
