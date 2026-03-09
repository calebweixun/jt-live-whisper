# Quick Start: Web 音訊串流轉譯介面

**Date**: 2026-03-09  
**Purpose**: 快速部署和使用指南

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
- **硬體**: 
  - 任何支援瀏覽器的裝置（Windows、macOS、Linux、平板、手機）
  - 麥克風

---

## 快速部署（5 分鐘）

### Step 1: 複製專案

```bash
git clone https://github.com/calebweixun/jt-live-whisper.git
cd jt-live-whisper
git checkout 001-web-streaming-interface
```

### Step 2: 下載 AI 模型

```bash
# 下載 Whisper 模型
cd webapp/backend
python3 scripts/download_models.py

# 預期下載：
# - large-v3-turbo.bin (約 1.5GB)
# 模型會儲存到 models/ 目錄
```

### Step 3: 設定環境變數

```bash
cd webapp
cp .env.example .env
```

編輯 `.env` 檔案：

```bash
# Server 設定
SERVER_HOST=0.0.0.0
SERVER_PORT=8000

# GPU 設定
CUDA_VISIBLE_DEVICES=0
WHISPER_MODEL=large-v3-turbo
WHISPER_DEVICE=cuda
WHISPER_COMPUTE_TYPE=float16

# Ollama 設定（翻譯服務）
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

### Step 4: 啟動服務

```bash
docker-compose up -d
```

服務會在背景啟動，包含：
- **backend**: FastAPI 後端服務（port 8000）
- **frontend**: Nginx 前端服務（port 80）

### Step 5: 檢查服務狀態

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

---

## 使用指南

### 在客戶端存取

1. **開啟瀏覽器**
   - 連線到 `http://{server_ip}`（Server 的 IP 位址）
   - 例如：`http://192.168.1.100`

2. **授權麥克風權限**
   - 瀏覽器會請求麥克風權限
   - 點擊「允許」

3. **設定翻譯選項**
   - 選擇來源語言：中文 / 英文
   - 選擇目標語言：中文 / 英文
   - 勾選「啟用翻譯」（可選）

4. **開始轉譯**
   - 點擊「開始轉譯」按鈕
   - 對著麥克風說話
   - 轉譯文字和翻譯會即時顯示

5. **停止轉譯**
   - 點擊「停止」按鈕
   - 系統會保存完整記錄

### UI 介面說明

```
┌─────────────────────────────────────────────────┐
│  Web 音訊轉譯系統                               │
├─────────────────────────────────────────────────┤
│                                                 │
│  ┌─────────────────────────────────────────┐   │
│  │ 設定                                    │   │
│  │ 來源語言: [英文 ▼]                      │   │
│  │ 目標語言: [繁體中文 ▼]                  │   │
│  │ ☑ 啟用翻譯                              │   │
│  │                                         │   │
│  │ [開始轉譯]  [停止]                      │   │
│  └─────────────────────────────────────────┘   │
│                                                 │
│  ┌─────────────────────────────────────────┐   │
│  │ 即時轉譯                                │   │
│  │ ─────────────────────────────────────── │   │
│  │ Hello, how are you doing today?         │   │
│  │                                         │   │
│  │ I'm doing great, thank you for asking. │   │
│  └─────────────────────────────────────────┘   │
│                                                 │
│  ┌─────────────────────────────────────────┐   │
│  │ 翻譯結果                                │   │
│  │ ─────────────────────────────────────── │   │
│  │ 你好，你今天過得怎麼樣？                │   │
│  │                                         │   │
│  │ 我很好，謝謝你的關心。                  │   │
│  └─────────────────────────────────────────┘   │
│                                                 │
│  狀態: 轉譯中... | 已處理: 30 秒             │
└─────────────────────────────────────────────────┘
```

---

## 常見問題

### Q1: 瀏覽器無法存取 Server

**問題**: 在瀏覽器輸入 `http://{server_ip}` 無法連線

**解決方案**:
1. 檢查 Server 服務是否正在運行：
   ```bash
   docker-compose ps
   ```
2. 檢查防火牆設定：
   ```bash
   sudo ufw allow 80
   sudo ufw allow 8000
   ```
3. 確認客戶端和 Server 在同一區域網路

### Q2: 麥克風權限被拒絕

**問題**: 瀏覽器顯示「無法存取麥克風」

**解決方案**:
1. 檢查瀏覽器設定 → 隱私與安全性 → 網站設定 → 麥克風
2. 確保該網站允許使用麥克風
3. 在 Chrome：`chrome://settings/content/microphone`

### Q3: GPU 無法使用

**問題**: 日誌顯示「CUDA not available」或「GPU unavailable」

**解決方案**:
1. 檢查 NVIDIA Driver：
   ```bash
   nvidia-smi
   ```
2. 檢查 NVIDIA Container Toolkit：
   ```bash
   docker run --rm --gpus all nvidia/cuda:12.1.1-base nvidia-smi
   ```
3. 查看 docker-compose.yml 的 `runtime: nvidia` 設定

### Q4: 轉譯延遲過高

**問題**: 轉譯文字顯示延遲超過 5 秒

**解決方案**:
1. 檢查網路延遲：
   ```bash
   ping {server_ip}
   ```
2. 檢查 GPU 記憶體使用：
   ```bash
   nvidia-smi
   ```
3. 降低同時連線數（一個 GPU 建議最多 5 個使用者）

### Q5: 翻譯功能無法使用

**問題**: 轉譯正常但翻譯不顯示

**解決方案**:
1. 檢查 Ollama Server 是否運行：
   ```bash
   curl http://{ollama_url}/api/tags
   ```
2. 檢查 `.env` 中的 `OLLAMA_URL` 設定
3. 查看後端日誌：
   ```bash
   docker-compose logs backend | grep translation
   ```

---

## 進階配置

### 調整模型參數

編輯 `webapp/backend/config.yaml`：

```yaml
transcription:
  model_name: large-v3-turbo
  device: cuda
  compute_type: float16  # float16 (快) 或 int8 (更快但準確度稍低)
  language: null  # null 為自動偵測，或指定 "zh" / "en"
  vad_filter: true  # 啟用靜音過濾
  vad_threshold: 0.5  # 靜音閾值
```

### 調整連線限制

編輯 `.env`：

```bash
# 最大同時連線數（根據 GPU 記憶體調整）
MAX_CONNECTIONS=10

# 單個會話最大時長（秒）
MAX_SESSION_DURATION=3600

# 音訊檔案最大大小（MB）
MAX_AUDIO_SIZE_MB=100
```

### 啟用 HTTPS（生產環境）

1. 準備 SSL 憑證（Let's Encrypt 或自簽）
2. 編輯 `docker-compose.yml` 的 frontend 服務：
   ```yaml
   frontend:
     ports:
       - "443:443"
     volumes:
       - ./ssl:/etc/nginx/ssl
   ```
3. 編輯 `webapp/frontend/nginx.conf` 加入 SSL 設定

---

## 效能調校

### GPU 記憶體優化

根據 GPU 記憶體大小選擇模型：

| GPU VRAM | 推薦模型 | 同時連線數 | 轉譯延遲 |
|----------|---------|----------|----------|
| 8GB (RTX 5060) | large-v3-turbo | 3-5 | 2-3 秒 |
| 12GB | large-v3 | 5-8 | 2-3 秒 |
| 16GB+ | large-v3 | 8-12 | 1-2 秒 |

### 網路優化

1. 使用有線網路（避免 WiFi）
2. Server 和客戶端在同一子網路
3. 確保路由器 QoS 設定優先音訊流量

### 儲存優化

1. 定期清理舊資料：
   ```bash
   # 刪除 7 天前的資料
   docker-compose exec backend python scripts/cleanup.py --days 7
   ```

2. 使用 SSD 儲存 `data/` 目錄（提高 I/O 效能）

---

## 備份與恢復

### 備份資料

```bash
# 備份所有會話資料
tar -czf backup_$(date +%Y%m%d).tar.gz webapp/data/

# 僅備份音訊和轉譯記錄
tar -czf backup_audio_$(date +%Y%m%d).tar.gz webapp/data/audio/ webapp/data/transcripts/
```

### 恢復資料

```bash
# 停止服務
docker-compose down

# 解壓備份
tar -xzf backup_20260309.tar.gz -C webapp/

# 重新啟動服務
docker-compose up -d
```

---

## 監控與維護

### 查看系統狀態

```bash
# 即時監控 GPU 使用
watch -n 1 nvidia-smi

# 查看容器資源使用
docker stats

# 查看日誌
docker-compose logs -f --tail 100
```

### 定期維護任務

1. **每日**：檢查日誌是否有錯誤
   ```bash
   docker-compose logs backend | grep ERROR
   ```

2. **每週**：清理過期資料
   ```bash
   docker-compose exec backend python scripts/cleanup.py --days 7
   ```

3. **每月**：更新 Docker images
   ```bash
   docker-compose pull
   docker-compose up -d
   ```

---

## 除錯模式

啟用詳細日誌：

```bash
# 停止服務
docker-compose down

# 啟用除錯模式
export LOG_LEVEL=DEBUG

# 前景運行（可看到即時日誌）
docker-compose up
```

---

## 下一步

- ✅ 基本部署完成
- 📖 閱讀 [API 文件](contracts/api.md)
- 📖 閱讀 [WebSocket 協定](contracts/websocket.md)
- 🔧 根據需求調整配置
- 📊 監控系統效能和使用情況

如有問題，請查看 `webapp/backend/logs/` 目錄中的詳細日誌。
