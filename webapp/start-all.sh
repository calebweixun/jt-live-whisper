#!/bin/bash

# Web 應用完整啟動腳本（前後端同時啟動）
# 用途：使用單一指令同時啟動前後端服務

set -e

# 顏色定義
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# 取得腳本所在目錄
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BACKEND_DIR="$SCRIPT_DIR/backend"
FRONTEND_DIR="$SCRIPT_DIR/frontend"
VENV_DIR="$PROJECT_ROOT/venv"
PID_FILE="$SCRIPT_DIR/.webapp.pid"

# 清理函數
cleanup() {
    echo ""
    echo -e "${YELLOW}正在停止服務...${NC}"
    
    # 讀取 PID 並終止進程
    if [ -f "$PID_FILE" ]; then
        while IFS= read -r pid; do
            if ps -p "$pid" > /dev/null 2>&1; then
                echo -e "  停止進程 $pid"
                kill "$pid" 2>/dev/null || true
            fi
        done < "$PID_FILE"
        rm "$PID_FILE"
    fi
    
    # 額外的清理：終止所有相關進程
    pkill -f "uvicorn src.main:app" 2>/dev/null || true
    pkill -f "python3 -m http.server" 2>/dev/null || true
    
    echo -e "${GREEN}✓ 服務已停止${NC}"
    exit 0
}

# 設定 trap 以捕捉中斷信號
trap cleanup INT TERM

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Web 音訊串流轉譯系統${NC}"
echo -e "${BLUE}  完整啟動（前端 + 後端）${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# 1. 檢查 Python
echo -e "${GREEN}[1/7] 檢查 Python 版本...${NC}"
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}錯誤: 找不到 Python3${NC}"
    exit 1
fi
echo -e "      ${YELLOW}✓${NC} Python $(python3 --version | cut -d' ' -f2)"
echo ""

# 2. 建立虛擬環境
echo -e "${GREEN}[2/7] 設定虛擬環境...${NC}"
if [ ! -d "$VENV_DIR" ]; then
    python3 -m venv "$VENV_DIR"
    echo -e "      ${YELLOW}✓${NC} 虛擬環境已建立"
else
    echo -e "      ${YELLOW}✓${NC} 虛擬環境已存在"
fi
source "$VENV_DIR/bin/activate"
echo ""

# 3. 安裝依賴
echo -e "${GREEN}[3/7] 安裝後端依賴...${NC}"
pip install -q -r "$BACKEND_DIR/requirements.txt"
echo -e "      ${YELLOW}✓${NC} 依賴已安裝"
echo ""

# 4. 設定環境變數
echo -e "${GREEN}[4/7] 設定環境變數...${NC}"
if [ ! -f "$BACKEND_DIR/.env" ]; then
    if [ -f "$BACKEND_DIR/.env.example" ]; then
        cp "$BACKEND_DIR/.env.example" "$BACKEND_DIR/.env"
        echo -e "      ${YELLOW}✓${NC} 已建立 .env 檔案"
    fi
else
    echo -e "      ${YELLOW}✓${NC} .env 檔案已存在"
fi
echo ""

# 5. 建立資料目錄
echo -e "${GREEN}[5/7] 建立資料目錄...${NC}"
mkdir -p "$PROJECT_ROOT/data"/{audio,sessions,transcripts,translations,logs}
echo -e "      ${YELLOW}✓${NC} 資料目錄已建立"
echo ""

# 6. 啟動後端
echo -e "${GREEN}[6/7] 啟動後端服務...${NC}"
cd "$BACKEND_DIR"
export PYTHONPATH="$BACKEND_DIR/src:$PYTHONPATH"

# 在背景啟動後端
nohup uvicorn src.main:app --host 0.0.0.0 --port 8000 > "$PROJECT_ROOT/data/logs/backend.log" 2>&1 &
BACKEND_PID=$!
echo "$BACKEND_PID" > "$PID_FILE"
echo -e "      ${YELLOW}✓${NC} 後端服務已啟動 (PID: $BACKEND_PID)"

# 等待後端啟動
echo -e "      等待後端啟動..."
for i in {1..30}; do
    if curl -s http://localhost:8000/api/v1/health > /dev/null 2>&1; then
        echo -e "      ${GREEN}✓${NC} 後端服務就緒"
        break
    fi
    if [ $i -eq 30 ]; then
        echo -e "${RED}錯誤: 後端啟動逾時${NC}"
        cleanup
        exit 1
    fi
    sleep 1
done
echo ""

# 7. 啟動前端
echo -e "${GREEN}[7/7] 啟動前端服務...${NC}"
cd "$FRONTEND_DIR"

# 在背景啟動前端
nohup python3 -m http.server 3000 > "$PROJECT_ROOT/data/logs/frontend.log" 2>&1 &
FRONTEND_PID=$!
echo "$FRONTEND_PID" >> "$PID_FILE"
echo -e "      ${YELLOW}✓${NC} 前端服務已啟動 (PID: $FRONTEND_PID)"
sleep 2
echo ""

# 啟動完成
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}✓✓✓ 所有服務已啟動！${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${YELLOW}服務位址:${NC}"
echo -e "  • 前端應用: ${BLUE}http://localhost:3000${NC}"
echo -e "  • 後端 API: ${BLUE}http://localhost:8000${NC}"
echo -e "  • API 文件: ${BLUE}http://localhost:8000/docs${NC}"
echo ""
echo -e "${YELLOW}日誌檔案:${NC}"
echo -e "  • 後端日誌: $PROJECT_ROOT/data/logs/backend.log"
echo -e "  • 前端日誌: $PROJECT_ROOT/data/logs/frontend.log"
echo ""
echo -e "${YELLOW}查看日誌:${NC}"
echo -e "  後端: ${BLUE}tail -f $PROJECT_ROOT/data/logs/backend.log${NC}"
echo -e "  前端: ${BLUE}tail -f $PROJECT_ROOT/data/logs/frontend.log${NC}"
echo ""
echo -e "${YELLOW}停止服務: 按 Ctrl+C 或執行以下指令${NC}"
echo -e "  ${BLUE}kill \$(cat $PID_FILE)${NC}"
echo ""
echo -e "${BLUE}========================================${NC}"
echo ""

# 保持腳本運行，等待使用者中斷
echo -e "${GREEN}服務正在運行中... (按 Ctrl+C 停止)${NC}"
echo ""

# 無限循環，直到收到中斷信號
while true; do
    # 檢查進程是否還在運行
    if ! ps -p "$BACKEND_PID" > /dev/null 2>&1; then
        echo -e "${RED}錯誤: 後端服務已停止${NC}"
        cleanup
        exit 1
    fi
    if ! ps -p "$FRONTEND_PID" > /dev/null 2>&1; then
        echo -e "${RED}錯誤: 前端服務已停止${NC}"
        cleanup
        exit 1
    fi
    sleep 5
done
