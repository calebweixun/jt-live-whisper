#!/bin/bash

# Web 應用快速啟動腳本
# 用途：自動建立虛擬環境、安裝依賴、啟動前後端服務

set -e  # 遇到錯誤立即退出

# 顏色定義
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 取得腳本所在目錄
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BACKEND_DIR="$SCRIPT_DIR/backend"
FRONTEND_DIR="$SCRIPT_DIR/frontend"
VENV_DIR="$PROJECT_ROOT/venv"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Web 音訊串流轉譯系統 - 快速啟動${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# 1. 檢查 Python 版本
echo -e "${GREEN}[1/7] 檢查 Python 版本...${NC}"
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}錯誤: 找不到 Python3，請先安裝 Python 3.8 或更高版本${NC}"
    exit 1
fi

PYTHON_VERSION=$(python3 --version | cut -d' ' -f2)
echo -e "      找到 Python ${PYTHON_VERSION}"
echo ""

# 2. 建立/激活虛擬環境
echo -e "${GREEN}[2/7] 設定虛擬環境...${NC}"
if [ ! -d "$VENV_DIR" ]; then
    echo -e "      建立新的虛擬環境: $VENV_DIR"
    python3 -m venv "$VENV_DIR"
    echo -e "      ${YELLOW}✓${NC} 虛擬環境建立完成"
else
    echo -e "      ${YELLOW}✓${NC} 虛擬環境已存在"
fi
echo ""

# 激活虛擬環境
echo -e "${GREEN}[3/7] 激活虛擬環境...${NC}"
source "$VENV_DIR/bin/activate"
echo -e "      ${YELLOW}✓${NC} 虛擬環境已激活"
echo ""

# 3. 安裝/更新後端依賴
echo -e "${GREEN}[4/7] 安裝後端依賴...${NC}"
if [ -f "$BACKEND_DIR/requirements.txt" ]; then
    echo -e "      安裝套件..."
    pip install -q -r "$BACKEND_DIR/requirements.txt"
    echo -e "      ${YELLOW}✓${NC} 依賴已安裝"
else
    echo -e "${RED}警告: 找不到 requirements.txt${NC}"
fi
echo ""

# 4. 設定環境變數
echo -e "${GREEN}[5/7] 設定環境變數...${NC}"
if [ ! -f "$BACKEND_DIR/.env" ]; then
    if [ -f "$BACKEND_DIR/.env.example" ]; then
        cp "$BACKEND_DIR/.env.example" "$BACKEND_DIR/.env"
        echo -e "      ${YELLOW}✓${NC} 已複製 .env.example 為 .env"
        echo -e "      ${YELLOW}⚠${NC}  請根據需要編輯 $BACKEND_DIR/.env"
    else
        echo -e "${RED}警告: 找不到 .env.example${NC}"
    fi
else
    echo -e "      ${YELLOW}✓${NC} .env 檔案已存在"
fi
echo ""

# 5. 建立必要的資料目錄
echo -e "${GREEN}[6/7] 建立資料目錄...${NC}"
mkdir -p "$PROJECT_ROOT/data/audio"
mkdir -p "$PROJECT_ROOT/data/sessions"
mkdir -p "$PROJECT_ROOT/data/transcripts"
mkdir -p "$PROJECT_ROOT/data/translations"
mkdir -p "$PROJECT_ROOT/data/logs"
echo -e "      ${YELLOW}✓${NC} 資料目錄已建立"
echo ""

# 6. 啟動服務
echo -e "${GREEN}[7/7] 啟動服務...${NC}"
echo ""

# 進入後端目錄
cd "$BACKEND_DIR"

# 設定環境變數
export PYTHONPATH="$BACKEND_DIR/src:$PYTHONPATH"

echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}✓ 啟動準備完成！${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${YELLOW}後端服務啟動中...${NC}"
echo -e "  • API 文件: ${BLUE}http://localhost:8000/docs${NC}"
echo -e "  • 健康檢查: ${BLUE}http://localhost:8000/api/v1/health${NC}"
echo ""
echo -e "${YELLOW}前端服務啟動說明:${NC}"
echo -e "  請在新終端機中執行以下指令啟動前端："
echo -e "  ${BLUE}cd $FRONTEND_DIR && python3 -m http.server 3000${NC}"
echo -e "  然後開啟瀏覽器訪問: ${BLUE}http://localhost:3000${NC}"
echo ""
echo -e "${YELLOW}按 Ctrl+C 可停止後端服務${NC}"
echo ""
echo -e "${BLUE}========================================${NC}"
echo ""

# 啟動後端服務
uvicorn src.main:app --host 0.0.0.0 --port 8000 --reload
