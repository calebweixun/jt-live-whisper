# Implementation Plan: Web 音訊串流轉譯介面

**Branch**: `001-web-streaming-interface` | **Date**: 2026-03-09 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/001-web-streaming-interface/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/plan-template.md` for the execution workflow.

## Summary

建立 Web 介面，透過 Docker 部署在 LAN Server 上，提供即時音訊串流轉譯和翻譯功能。使用者可在任何裝置的瀏覽器中存取服務，無需安裝軟體。系統支援兩種運算模式：Server GPU (RTX 5060) 和本地 OpenVINO。

核心技術：FastAPI + 原生 JavaScript、WebRTC 音訊串流、faster-whisper GPU 轉譯、Ollama LLM 翻譯、Docker + NVIDIA Container Toolkit 部署。UI 以輕量化設計顯示即時轉譯文字和翻譯文字，所有音訊檔案和參數保存在 Server 端。

## Technical Context

**Language/Version**: Python 3.12+  
**Primary Dependencies**: FastAPI 0.104+, uvicorn 0.24+, faster-whisper 0.10+, websockets 12.0+  
**Storage**: 檔案系統（音訊檔案和轉譯記錄存於 Server 本地 `data/` 目錄）  
**Testing**: pytest（選用，非必須）  
**Target Platform**: Linux Server (Ubuntu 20.04+) + Docker + NVIDIA GPU，客戶端為主流瀏覽器  
**Project Type**: web-service（FastAPI 後端 + 原生 JavaScript 前端）  
**Performance Goals**: 
- Web 介面載入 < 1 秒
- 轉譯延遲 < 3 秒（Server GPU 模式）
- 翻譯延遲 < 5 秒
- 支援至少 5 個同時連線使用者  
**Constraints**: 
- 所有資料必須保存在 Server 本地，不能外洩
- 前端必須使用輕量化技術（無 React/Vue/Angular）
- 所有 AI 模型須預先包含在 Docker Image 中
- 網路延遲 < 50ms（LAN 環境）  
**Scale/Scope**: 小型區域網路部署（5-10 個同時使用者）、單一 Server、約 2000-3000 行程式碼（前後端總計）

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### ✅ I. Web 化優先
- ✅ 提供 Web 介面，所有裝置透過瀏覽器存取
- ✅ 前端使用輕量化技術（原生 JavaScript，不使用 React/Vue/Angular）
- ✅ 打破 macOS/Windows/Linux 相容性限制

### ✅ II. 地端運行與隱私保護
- ✅ 所有 AI 運算在 Server 或本地裝置（區域網路內）
- ✅ 音訊資料、轉譯記錄保存在 Server 本地檔案系統
- ✅ AI 模型預先包含在 Docker Image，不連網下載
- ✅ 不依賴任何第三方雲端 API

### ✅ III. 效能與輕量化
- ✅ Web 介面載入時間目標 < 1 秒
- ✅ 轉譯延遲 < 3 秒
- ✅ 使用輕量級框架和原生技術
- ✅ 資源使用最佳化（支援至少 5 個同時使用者）

### ✅ IV. 最小化開發
- ✅ 明確定義範圍：即時串流轉譯，不包含檔案上傳、講者辨識、摘要等
- ✅ UI 簡潔：僅顯示轉譯文字和翻譯文字
- ✅ 無帳號系統、無進階配置選項

### ✅ V. 版本控制與可追溯性
- ✅ 所有開發在 `001-web-streaming-interface` 分支進行
- ✅ 每個階段提交 git commit

### ✅ VI. 繁體中文優先
- ✅ 所有文件、UI、commit 訊息使用繁體中文
- ✅ 程式碼註解使用繁體中文

**GATE RESULT**: ✅ **PASS** - 所有憲章要求均符合，可進入 Phase 0 研究階段。

## Project Structure

### Documentation (this feature)

```text
specs/001-web-streaming-interface/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
│   ├── api.md          # HTTP API endpoints
│   └── websocket.md    # WebSocket protocol
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
webapp/                      # 新的 Web 應用程式目錄
├── backend/                 # FastAPI 後端服務
│   ├── src/
│   │   ├── main.py         # FastAPI 應用程式入口
│   │   ├── api/            # API 路由
│   │   │   ├── transcribe.py   # 轉譯 API
│   │   │   ├── translate.py    # 翻譯 API
│   │   │   └── websocket.py    # WebSocket 連線
│   │   ├── services/       # 業務邏輯
│   │   │   ├── audio_processor.py    # 音訊處理
│   │   │   ├── transcription.py      # 轉譯服務（faster-whisper）
│   │   │   ├── translation.py        # 翻譯服務（Ollama/Argos）
│   │   │   └── storage.py            # 檔案儲存
│   │   ├── models/         # 資料模型
│   │   │   ├── session.py        # 會話模型
│   │   │   ├── task.py           # 任務模型
│   │   │   └── audio_stream.py   # 音訊串流模型
│   │   └── config.py       # 配置管理
│   ├── requirements.txt    # Python 依賴
│   └── Dockerfile          # 後端容器定義
│
├── frontend/               # 原生 JavaScript 前端
│   ├── index.html         # 主頁面
│   ├── css/
│   │   └── style.css      # 樣式表（輕量化）
│   ├── js/
│   │   ├── app.js         # 主應用程式邏輯
│   │   ├── audio.js       # 音訊擷取和串流
│   │   ├── transcription.js   # 轉譯顯示
│   │   ├── translation.js     # 翻譯顯示
│   │   └── websocket.js   # WebSocket 客戶端
│   └── Dockerfile         # 前端容器定義（Nginx）
│
├── data/                   # Server 端資料儲存（不納入版本控制）
│   ├── audio/             # 音訊檔案
│   ├── transcripts/       # 轉譯記錄
│   └── logs/              # 系統日誌
│
├── docker-compose.yml     # Docker Compose 配置
└── README.md              # 部署和使用說明
```

**Structure Decision**: 採用 Web 應用架構（Option 2），分為 backend（FastAPI）和 frontend（原生 JavaScript）。建立新的 `webapp/` 目錄以與現有的 CLI 工具分離。後端負責音訊處理和 AI 運算，前端提供輕量化 UI 顯示轉譯和翻譯結果。所有音訊檔案和轉譯記錄保存在 `data/` 目錄（Server 端）。

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

無違反憲章的情況。專案架構簡單清晰，符合最小化開發原則。
