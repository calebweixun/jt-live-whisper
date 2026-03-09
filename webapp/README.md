# Web 音訊串流轉譯介面

即時語音轉譯與翻譯系統，透過 Web 介面打破裝置相容性限制。

## 功能特色

- ✅ **即時語音轉譯**: 支援中文和英文，延遲 < 3 秒
- ✅ **即時翻譯**: 中英互譯，延遲 < 5 秒
- ✅ **跨平台支援**: 任何裝置的瀏覽器即可使用
- ✅ **地端運算**: 所有資料保存在 Server，保護隱私
- ✅ **GPU 加速**: 使用 NVIDIA GPU 加速轉譯
- ✅ **輕量化設計**: Web 介面載入 < 1 秒

## 系統需求

### Server 端
- **作業系統**: Ubuntu 20.04+ 或其他支援 Docker 的 Linux 發行版
- **硬體**: 
  - CPU: 4 核心以上
  - RAM: 16GB 以上
  - GPU: NVIDIA RTX 5060 (8GB VRAM) 或更高
  - 儲存空間: 50GB 以上（含模型）
- **軟體**:
  - Docker 20.10+
  - Docker Compose 2.0+
  - NVIDIA Driver 525+
  - NVIDIA Container Toolkit 1.13+

### 客戶端
- **瀏覽器**: Chrome 90+、Edge 90+、Firefox 88+、Safari 14+
- **網路**: 與 Server 在同一區域網路，延遲 < 50ms
- **硬體**: 任何支援瀏覽器的裝置（Windows、macOS、Linux、平板、手機）+ 麥克風

## 快速部署（5 分鐘）

### Step 1: 複製專案

```bash
git clone https://github.com/calebweixun/jt-live-whisper.git
cd jt-live-whisper
git checkout 001-web-streaming-interface
```

### Step 2: 設定環境變數

```bash
cd webapp
cp .env.example .env
```

編輯 `.env` 檔案（根據你的環境調整）：

```bash
# Server 設定
SERVER_HOST=0.0.0.0
SERVER_PORT=8000

# GPU 設定
CUDA_VISIBLE_DEVICES=0
WHISPER_MODEL=large-v3-turbo
WHISPER_DEVICE=cuda
WHISPER_COMPUTE_TYPE=float16

# Ollama 設定（翻譯服務，可選）
OLLAMA_URL=http://192.168.1.100:11434
OLLAMA_MODEL=qwen2.5:7b
OLLAMA_TIMEOUT=10

# Storage 設定
DATA_DIR=/app/data
MAX_AUDIO_SIZE_MB=100
RETENTION_DAYS=7

# WebSocket 設定
MAX_CONNECTIONS=10
PING_INTERVAL=30
PING_TIMEOUT=10
```

### Step 3: 啟動服務

```bash
docker-compose up -d
```

服務會在背景啟動：
- **backend**: FastAPI 後端服務（port 8000）
- **frontend**: Nginx 前端服務（port 80）

### Step 4: 檢查服務狀態

```bash
# 查看容器狀態
docker-compose ps

# 查看日誌
docker-compose logs -f backend

# 健康檢查
curl http://localhost:8000/api/v1/health
```

預期回應：
```json
{
  "success": true,
  "data": {
    "status": "healthy",
    "services": {
      "transcription": {
        "available": true,
        "model": "large-v3-turbo",
        "device": "cuda"
      }
    }
  }
}
```

## 使用指南

### 在客戶端存取

1. **開啟瀏覽器**
   - 連線到 `http://{server_ip}`（Server 的 IP 位址）
   - 例如：`http://192.168.1.100`

2. **授權麥克風權限**
   - 瀏覽器會請求麥克風權限
   - 點擊「允許」

3. **設定翻譯選項**（可選）
   - 選擇來源語言：中文 / 英文
   - 選擇目標語言：中文 / 英文
   - 勾選「啟用翻譯」

4. **開始轉譯**
   - 點擊「開始轉譯」按鈕
   - 對著麥克風說話
   - 轉譯文字和翻譯會即時顯示

5. **停止轉譯**
   - 點擊「停止」按鈕
   - 系統會保存完整記錄

## 開發指南

### 專案結構

```
webapp/
├── backend/              # FastAPI 後端服務
│   ├── src/
│   │   ├── main.py      # 應用程式入口
│   │   ├── config.py    # 配置管理
│   │   ├── api/         # API 路由
│   │   ├── services/    # 業務邏輯
│   │   └── models/      # 資料模型
│   ├── requirements.txt
│   └── Dockerfile
│
├── frontend/            # 原生 JavaScript 前端
│   ├── index.html
│   ├── css/
│   └── js/
│
├── data/                # Server 端資料儲存
│   ├── sessions/        # 會話記錄
│   ├── audio/           # 音訊檔案
│   ├── transcripts/     # 轉譯記錄
│   ├── translations/    # 翻譯結果
│   └── logs/            # 系統日誌
│
└── docker-compose.yml
```

### 本地開發

#### 後端

```bash
cd webapp/backend

# 建立虛擬環境
python3 -m venv venv
source venv/bin/activate  # macOS/Linux
# 或 venv\Scripts\activate  # Windows

# 安裝依賴
pip install -r requirements.txt

# 啟動開發 Server
uvicorn src.main:app --reload --host 0.0.0.0 --port 8000
```

#### 前端

```bash
cd webapp/frontend

# 使用任何 HTTP Server
python3 -m http.server 3000
# 或使用 VS Code Live Server
```

前端會透過 WebSocket 連線到 `ws://localhost:8000/ws`

## API 文件

啟動服務後，可透過以下 URL 存取 API 文件：

- **Swagger UI**: http://localhost:8000/docs
- **ReDoc**: http://localhost:8000/redoc

## 常見問題

### Q1: 瀏覽器無法存取 Server

**解決方案**:
1. 檢查 Server 服務是否正在運行：`docker-compose ps`
2. 檢查防火牆設定：`sudo ufw allow 80 && sudo ufw allow 8000`
3. 確認客戶端和 Server 在同一區域網路

### Q2: 麥克風權限被拒絕

**解決方案**:
1. 檢查瀏覽器設定 → 隱私與安全性 → 網站設定 → 麥克風
2. 確保該網站允許使用麥克風
3. Chrome: `chrome://settings/content/microphone`

### Q3: GPU 無法使用

**解決方案**:
1. 檢查 NVIDIA Driver：`nvidia-smi`
2. 檢查 NVIDIA Container Toolkit：
   ```bash
   docker run --rm --gpus all nvidia/cuda:12.1.1-base nvidia-smi
   ```
3. 查看 docker-compose.yml 的 `runtime: nvidia` 設定

### Q4: 轉譯延遲過高

**解決方案**:
1. 檢查網路延遲：`ping {server_ip}`
2. 檢查 GPU 記憶體使用：`nvidia-smi`
3. 降低同時連線數（一個 GPU 建議最多 5 個使用者）

### Q5: 翻譯功能無法使用

**解決方案**:
1. 檢查 Ollama 服務是否運行：`curl http://{ollama_url}/api/version`
2. 如果 Ollama 不可用，系統會自動降級使用 Argos Translate
3. 查看後端日誌：`docker-compose logs backend | grep translation`

## 維護與監控

### 查看日誌

```bash
# 查看所有服務日誌
docker-compose logs

# 查看特定服務日誌
docker-compose logs backend
docker-compose logs frontend

# 即時追蹤日誌
docker-compose logs -f
```

### 資料清理

系統會根據 `RETENTION_DAYS` 設定自動清理過期資料。手動清理：

```bash
# 進入後端容器
docker-compose exec backend bash

# 執行清理腳本
python scripts/cleanup.py --days 7
```

### 效能監控

```bash
# GPU 使用率
nvidia-smi

# 容器資源使用
docker stats

# 磁碟空間
df -h /path/to/data
```

## 技術棧

- **後端**: Python 3.12+, FastAPI 0.104+, faster-whisper 0.10+
- **前端**: 原生 JavaScript (ES6+), WebSocket, MediaRecorder API
- **AI 模型**: Whisper large-v3-turbo, Ollama (Qwen 2.5), Argos Translate
- **部署**: Docker, Docker Compose, NVIDIA Container Toolkit
- **儲存**: 檔案系統 (JSON + WAV)

## 授權

請參考專案根目錄的 LICENSE 檔案。

## 貢獻

請參考專案的 CONTRIBUTING.md 指南。

## 支援

如有問題，請開 Issue 或聯繫專案維護者。
