#!/bin/bash

# 停止 Web 應用服務

# 顏色定義
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PID_FILE="$SCRIPT_DIR/.webapp.pid"

echo -e "${YELLOW}正在停止 Web 應用服務...${NC}"
echo ""

# 從 PID 檔案終止進程
if [ -f "$PID_FILE" ]; then
    echo "從 PID 檔案終止進程..."
    while IFS= read -r pid; do
        if ps -p "$pid" > /dev/null 2>&1; then
            echo "  停止進程 $pid"
            kill "$pid" 2>/dev/null || true
            sleep 1
            # 如果還在運行，強制終止
            if ps -p "$pid" > /dev/null 2>&1; then
                kill -9 "$pid" 2>/dev/null || true
            fi
        fi
    done < "$PID_FILE"
    rm "$PID_FILE"
    echo -e "${GREEN}✓ PID 檔案中的進程已停止${NC}"
else
    echo -e "${YELLOW}未找到 PID 檔案${NC}"
fi

# 額外清理：終止所有相關進程
echo ""
echo "清理殘留進程..."

# 終止 uvicorn 進程
UVICORN_PIDS=$(pgrep -f "uvicorn src.main:app" 2>/dev/null || true)
if [ -n "$UVICORN_PIDS" ]; then
    echo "  停止 uvicorn 進程: $UVICORN_PIDS"
    echo "$UVICORN_PIDS" | xargs kill 2>/dev/null || true
fi

# 終止前端服務進程
HTTP_SERVER_PIDS=$(pgrep -f "python3 -m http.server" 2>/dev/null || true)
if [ -n "$HTTP_SERVER_PIDS" ]; then
    echo "  停止 http.server 進程: $HTTP_SERVER_PIDS"
    echo "$HTTP_SERVER_PIDS" | xargs kill 2>/dev/null || true
fi

echo ""
echo -e "${GREEN}✓ 所有服務已停止${NC}"
