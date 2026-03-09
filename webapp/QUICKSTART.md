# 快速啟動腳本使用指南

本目錄提供三個腳本，用於快速啟動和管理 Web 應用服務。

## 📋 腳本清單

### 1. `start-all.sh` - 完整啟動（推薦）

**功能：** 一鍵啟動前後端服務，包含虛擬環境設置和依賴安裝。

**使用方式：**
```bash
cd webapp
./start-all.sh
```

**執行內容：**
- ✓ 檢查 Python 環境
- ✓ 建立/激活虛擬環境（`../venv`）
- ✓ 安裝後端依賴
- ✓ 複製環境變數檔案（`.env`）
- ✓ 建立資料目錄結構
- ✓ 啟動後端服務（port 8000）
- ✓ 啟動前端服務（port 3000）

**服務位址：**
- 前端應用：http://localhost:3000
- 後端 API：http://localhost:8000
- API 文件：http://localhost:8000/docs

**停止服務：**
- 按 `Ctrl+C` 或執行 `./stop.sh`

---

### 2. `quickstart.sh` - 僅啟動後端

**功能：** 啟動後端服務，前端需手動啟動。適合前端開發時使用。

**使用方式：**
```bash
cd webapp
./quickstart.sh
```

**執行內容：**
- ✓ 檢查 Python 環境
- ✓ 建立/激活虛擬環境
- ✓ 安裝後端依賴
- ✓ 設定環境變數
- ✓ 建立資料目錄
- ✓ 啟動後端服務（port 8000）

**手動啟動前端：**
```bash
# 在另一個終端執行
cd webapp/frontend
python3 -m http.server 3000
```

**停止服務：**
- 按 `Ctrl+C`

---

### 3. `stop.sh` - 停止所有服務

**功能：** 停止所有正在運行的前後端服務。

**使用方式：**
```bash
cd webapp
./stop.sh
```

**執行內容：**
- ✓ 從 PID 檔案終止進程
- ✓ 清理殘留的 uvicorn 進程
- ✓ 清理殘留的 http.server 進程

---

## 🚀 快速上手

### 首次使用

```bash
# 1. 進入 webapp 目錄
cd webapp

# 2. 執行啟動腳本
./start-all.sh

# 3. 等待服務啟動完成（約 30 秒）
# 看到 "✓✓✓ 所有服務已啟動！" 訊息後即可使用

# 4. 開啟瀏覽器訪問
# http://localhost:3000
```

### 停止服務

```bash
# 方法 1: 按 Ctrl+C（如果在前台運行）
# 方法 2: 執行停止腳本
./stop.sh
```

---

## 📁 目錄結構

啟動後會自動建立以下目錄：

```
jt-live-whisper/
├── venv/                    # Python 虛擬環境
├── data/                    # 應用資料
│   ├── audio/              # 音訊檔案
│   ├── sessions/           # 會話記錄
│   ├── transcripts/        # 轉譯記錄
│   ├── translations/       # 翻譯結果
│   └── logs/               # 系統日誌
│       ├── backend.log     # 後端日誌
│       └── frontend.log    # 前端日誌
└── webapp/
    ├── .webapp.pid         # 進程 ID 檔案
    ├── backend/
    │   └── .env           # 環境變數配置
    └── frontend/
```

---

## 🔧 環境變數配置

首次啟動會自動複製 `.env.example` 為 `.env`，你可以根據需要修改配置：

```bash
cd webapp/backend
vim .env  # 或使用其他編輯器
```

**主要配置項：**

```bash
# Server 設定
SERVER_HOST=0.0.0.0
SERVER_PORT=8000

# GPU 設定
WHISPER_MODEL=large-v3-turbo
WHISPER_DEVICE=cuda  # 或 cpu
WHISPER_COMPUTE_TYPE=float16

# Ollama 翻譯服務
OLLAMA_URL=http://localhost:11434
OLLAMA_MODEL=qwen2.5:7b

# 資料儲存
DATA_DIR=../data
MAX_AUDIO_SIZE_MB=100
RETENTION_DAYS=7
```

修改後需重新啟動服務才會生效。

---

## 📊 查看日誌

### 即時查看後端日誌
```bash
tail -f data/logs/backend.log
```

### 即時查看前端日誌
```bash
tail -f data/logs/frontend.log
```

### 查看最近的錯誤
```bash
grep ERROR data/logs/backend.log | tail -20
```

---

## ❓ 常見問題

### Q1: 執行腳本時提示 "Permission denied"

**解決方法：**
```bash
chmod +x webapp/start-all.sh webapp/quickstart.sh webapp/stop.sh
```

### Q2: 後端啟動失敗，提示找不到模組

**解決方法：**
```bash
# 刪除虛擬環境並重新建立
rm -rf venv
./start-all.sh
```

### Q3: 服務停不下來

**解決方法：**
```bash
# 強制終止所有相關進程
pkill -f "uvicorn src.main:app"
pkill -f "python3 -m http.server"
```

### Q4: 後端健康檢查逾時

**可能原因：**
- Python 依賴未正確安裝
- 環境變數配置錯誤
- 資料目錄權限問題

**解決方法：**
```bash
# 查看後端日誌
cat data/logs/backend.log

# 手動測試後端
source ../venv/bin/activate
cd backend
python -c "from src.main import app; print('OK')"
```

### Q5: 前端無法連線到後端

**檢查項目：**
- 後端是否正常運行：`curl http://localhost:8000/api/v1/health`
- 防火牆是否阻擋連線
- CORS 設定是否正確

---

## 🔄 更新依賴

當 `requirements.txt` 更新後：

```bash
# 方法 1: 重新執行啟動腳本（推薦）
./start-all.sh

# 方法 2: 手動更新
source ../venv/bin/activate
pip install -r backend/requirements.txt
```

---

## 🐛 除錯模式

如需詳細的除錯資訊：

```bash
# 修改 .env
LOG_LEVEL=DEBUG

# 重新啟動服務
./stop.sh
./start-all.sh
```

---

## 📝 開發建議

### 前端開發
使用 `quickstart.sh` 只啟動後端，然後手動啟動前端的開發伺服器：

```bash
# 終端 1: 啟動後端
./quickstart.sh

# 終端 2: 啟動前端（使用自動重載）
cd frontend
# 使用支援 live reload 的開發伺服器
```

### 後端開發
腳本已啟用 `--reload` 模式，修改程式碼後會自動重載。

---

## 📮 聯絡與支援

如有問題或建議，請透過以下方式聯絡：
- GitHub Issues: https://github.com/calebweixun/jt-live-whisper/issues
- 電子郵件: [待補充]

---

**最後更新：** 2026-03-09
