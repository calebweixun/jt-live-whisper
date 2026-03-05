#!/bin/bash
# 即時英翻中字幕系統 - 安裝腳本
# 檢查並安裝所有必要的依賴項目
# 支援一鍵安裝：curl -fsSL https://raw.githubusercontent.com/jasoncheng7115/jt-live-whisper/main/install.sh | bash
# Author: Jason Cheng (Jason Tools)

set -e

GITHUB_REPO="https://github.com/jasoncheng7115/jt-live-whisper.git"
GITHUB_RAW="https://raw.githubusercontent.com/jasoncheng7115/jt-live-whisper/main"

# ─── Bootstrap：透過 curl | bash 執行時，自動 clone 並安裝 ───
SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
if [ ! -f "$SCRIPT_DIR/translate_meeting.py" ]; then
    echo ""
    echo -e "\033[38;2;100;180;255m============================================================\033[0m"
    echo -e "\033[38;2;100;180;255m\033[1m  jt-live-whisper - 一鍵安裝\033[0m"
    echo -e "\033[38;2;100;180;255m============================================================\033[0m"
    echo ""

    # 檢查 git
    if ! command -v git &>/dev/null; then
        echo -e "\033[38;2;255;220;80m[提醒] 需要 git，正在觸發 Xcode Command Line Tools 安裝...\033[0m"
        xcode-select --install 2>/dev/null || true
        echo -e "\033[38;2;255;255;255m安裝完成後請重新執行此指令。\033[0m"
        exit 1
    fi

    INSTALL_DIR="./jt-live-whisper"
    if [ -d "$INSTALL_DIR" ]; then
        echo -e "\033[38;2;255;255;255m目錄已存在: $INSTALL_DIR\033[0m"
        echo -e "\033[38;2;255;255;255m進入目錄執行安裝...\033[0m"
        cd "$INSTALL_DIR"
    else
        echo -e "\033[38;2;255;255;255m正在從 GitHub 下載 jt-live-whisper...\033[0m"
        git clone "$GITHUB_REPO" "$INSTALL_DIR"
        cd "$INSTALL_DIR"
    fi

    chmod +x install.sh start.sh
    exec ./install.sh "$@"
fi
# ─── Bootstrap 結束 ──────────────────────────────────────

VENV_DIR="$SCRIPT_DIR/venv"
WHISPER_DIR="$SCRIPT_DIR/whisper.cpp"
MODELS_DIR="$WHISPER_DIR/models"
ARGOS_PKG_DIR="$HOME/.local/share/argos-translate/packages/translate-en_zh-1_9"

# 偵測 ARM Homebrew Python（Moonshine 需要 ARM64 原生 Python）
if [ -x "/opt/homebrew/bin/python3.12" ]; then
    PYTHON_CMD="/opt/homebrew/bin/python3.12"
elif command -v python3.12 &>/dev/null; then
    PYTHON_CMD="python3.12"
else
    PYTHON_CMD="python3"
fi

# 24-bit 真彩色
C_TITLE='\033[38;2;100;180;255m'
C_OK='\033[38;2;80;255;120m'
C_WARN='\033[38;2;255;220;80m'
C_ERR='\033[38;2;255;100;100m'
C_DIM='\033[38;2;100;100;100m'
C_WHITE='\033[38;2;255;255;255m'
BOLD='\033[1m'
NC='\033[0m'

passed=0
failed=0
installed=0

# Spinner 動畫：在背景執行指令，前景顯示動畫
# 用法: run_spinner "顯示文字" command arg1 arg2 ...
# 指令的 stdout/stderr 會存到 $SPINNER_OUTPUT
SPINNER_OUTPUT="/tmp/jt-install-spinner-$$.log"
run_spinner() {
    local msg="$1"
    shift
    local frames=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
    printf "  ${C_DIM}%s ${NC}" "$msg"
    "$@" > "$SPINNER_OUTPUT" 2>&1 &
    local pid=$!
    local i=0
    while kill -0 "$pid" 2>/dev/null; do
        printf "${C_DIM}%s${NC}" "${frames[$((i % 10))]}"
        sleep 0.12
        printf "\b"
        ((i++)) || true
    done
    wait "$pid"
    local rc=$?
    printf " \b"
    return $rc
}

# 背景 Spinner：檢查階段用，不吞輸出
# 用法: spinner_start "訊息" → （執行檢查，輸出存到暫存檔）→ spinner_stop → cat 暫存檔
_SPINNER_PID=""
_CHECK_BUF="/tmp/jt-install-check-$$.log"
spinner_start() {
    local msg="$1"
    (
        trap 'exit 0' TERM
        local frames=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
        local i=0
        while true; do
            printf "\r  ${C_DIM}%s %s${NC} " "$msg" "${frames[$((i % 10))]}"
            sleep 0.12
            ((i++)) || true
        done
    ) &
    _SPINNER_PID=$!
}
spinner_stop() {
    if [ -n "$_SPINNER_PID" ]; then
        kill "$_SPINNER_PID" 2>/dev/null
        wait "$_SPINNER_PID" 2>/dev/null
        _SPINNER_PID=""
        printf "\r\033[K"
    fi
}

print_title() {
    echo ""
    echo -e "${C_TITLE}============================================================${NC}"
    echo -e "${C_TITLE}${BOLD}  jt-live-whisper v1.9.4 - 即時英翻中字幕系統 - 安裝程式${NC}"
    echo -e "${C_TITLE}  by Jason Cheng (Jason Tools)${NC}"
    echo -e "${C_TITLE}============================================================${NC}"
    echo ""
}

check_ok() {
    echo -e "  ${C_OK}[完成]${NC} $1"
    ((passed++)) || true
}

check_install() {
    echo -e "  ${C_WARN}[安裝]${NC} $1"
    ((installed++)) || true
}

check_fail() {
    echo -e "  ${C_ERR}[失敗]${NC} $1"
    ((failed++)) || true
}

section() {
    echo ""
    echo -e "${C_TITLE}${BOLD}▎ $1${NC}"
    echo -e "${C_DIM}$( printf '─%.0s' {1..50} )${NC}"
}

# ─── Homebrew ────────────────────────────────────
check_homebrew() {
    section "Homebrew"
    if command -v brew &>/dev/null; then
        check_ok "Homebrew 已安裝"
        return 0
    else
        echo -e "  ${C_ERR}[缺少]${NC} Homebrew 未安裝"
        echo -e "  ${C_WHITE}請先手動安裝：${NC}"
        echo -e "  ${C_DIM}/bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"${NC}"
        ((failed++))
        return 1
    fi
}

# ─── Brew packages ───────────────────────────────
install_brew_formula() {
    local pkg="$1"
    local desc="$2"
    if brew list --formula 2>/dev/null | grep -q "^${pkg}$"; then
        check_ok "$desc ($pkg)"
    else
        check_install "正在安裝 $desc ($pkg)..."
        run_spinner "安裝中..." brew install "$pkg"
        if brew list --formula 2>/dev/null | grep -q "^${pkg}$"; then
            echo ""
            check_ok "$desc ($pkg) 安裝完成"
        else
            echo ""
            check_fail "$desc ($pkg) 安裝失敗"
        fi
    fi
}

install_brew_cask() {
    local pkg="$1"
    local desc="$2"
    if brew list --cask 2>/dev/null | grep -q "^${pkg}$"; then
        check_ok "$desc ($pkg)"
    else
        check_install "正在安裝 $desc ($pkg)..."
        run_spinner "安裝中..." brew install --cask "$pkg"
        if brew list --cask 2>/dev/null | grep -q "^${pkg}$"; then
            check_ok "$desc ($pkg) 安裝完成"
            if [ "$pkg" = "blackhole-2ch" ]; then
                echo ""
                echo -e "  ${C_WARN}[注意] BlackHole 安裝後需要重新啟動電腦才能使用${NC}"
                echo -e "  ${C_WHITE}並需要設定 macOS 多重輸出裝置：${NC}"
                echo -e "  ${C_DIM}  1. 開啟「音訊 MIDI 設定」(Audio MIDI Setup)${NC}"
                echo -e "  ${C_DIM}  2. 點左下角 + → 建立「多重輸出裝置」${NC}"
                echo -e "  ${C_DIM}  3. 勾選你的喇叭/耳機 + BlackHole 2ch${NC}"
                echo -e "  ${C_DIM}  4. 在系統音訊設定中，將輸出設為此多重輸出裝置${NC}"
            fi
        else
            check_fail "$desc ($pkg) 安裝失敗"
        fi
    fi
}

check_brew_deps() {
    section "系統套件 (Homebrew)"
    install_brew_formula "cmake" "CMake 建構工具"
    install_brew_formula "sdl2" "SDL2 音訊函式庫"
    install_brew_formula "ffmpeg" "FFmpeg 音訊轉檔工具"
    install_brew_cask "blackhole-2ch" "BlackHole 虛擬音訊"
}

# ─── Python ──────────────────────────────────────
check_python() {
    section "Python (ARM64)"

    local is_arm_mac=0
    [ "$(uname -m)" = "arm64" ] && is_arm_mac=1

    # Apple Silicon：必須用 ARM64 Python（Moonshine 的 libmoonshine.dylib 是 ARM64 限定）
    if [ "$is_arm_mac" -eq 1 ]; then
        # 優先檢查 ARM Python
        if [ -x "/opt/homebrew/bin/python3.12" ]; then
            PYTHON_CMD="/opt/homebrew/bin/python3.12"
            local ver
            ver=$("$PYTHON_CMD" --version 2>&1)
            check_ok "$ver (ARM64, $PYTHON_CMD)"
            return 0
        fi

        # ARM Python 不存在，嘗試自動安裝
        if [ -x "/opt/homebrew/bin/brew" ]; then
            check_install "正在用 ARM Homebrew 安裝 Python 3.12（Moonshine 需要 ARM64）..."
            /opt/homebrew/bin/brew install python@3.12 2>&1 | tail -3
            if [ -x "/opt/homebrew/bin/python3.12" ]; then
                PYTHON_CMD="/opt/homebrew/bin/python3.12"
                check_ok "Python 3.12 ARM64 安裝完成 ($PYTHON_CMD)"
                return 0
            else
                check_fail "ARM64 Python 安裝失敗"
                return 1
            fi
        else
            # 沒有 ARM Homebrew，嘗試安裝
            echo -e "  ${C_WARN}[偵測]${NC} 未找到 ARM Homebrew，嘗試安裝..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" </dev/null
            if [ -x "/opt/homebrew/bin/brew" ]; then
                check_install "正在用 ARM Homebrew 安裝 Python 3.12..."
                /opt/homebrew/bin/brew install python@3.12 2>&1 | tail -3
                if [ -x "/opt/homebrew/bin/python3.12" ]; then
                    PYTHON_CMD="/opt/homebrew/bin/python3.12"
                    check_ok "Python 3.12 ARM64 安裝完成 ($PYTHON_CMD)"
                    return 0
                fi
            fi
            check_fail "無法安裝 ARM64 Python，請手動執行: /opt/homebrew/bin/brew install python@3.12"
            return 1
        fi
    fi

    # Intel Mac：用一般 Python
    if command -v "$PYTHON_CMD" &>/dev/null; then
        local ver
        ver=$("$PYTHON_CMD" --version 2>&1)
        check_ok "$ver ($PYTHON_CMD)"
        return 0
    else
        check_install "正在安裝 Python 3.12..."
        brew install python@3.12
        if command -v "$PYTHON_CMD" &>/dev/null; then
            check_ok "Python 3.12 安裝完成"
            return 0
        else
            check_fail "Python 3.12 安裝失敗，請手動安裝"
            return 1
        fi
    fi
}

# ─── whisper.cpp ─────────────────────────────────
check_whisper_cpp() {
    section "whisper.cpp (語音辨識引擎)"

    # 檢查原始碼
    if [ ! -d "$WHISPER_DIR" ]; then
        check_install "正在下載 whisper.cpp..."
        run_spinner "下載中..." git clone https://github.com/ggerganov/whisper.cpp.git "$WHISPER_DIR"
        if [ $? -eq 0 ]; then
            check_ok "whisper.cpp 下載完成"
        else
            check_fail "whisper.cpp 下載失敗"
            return 1
        fi
    else
        check_ok "whisper.cpp 原始碼存在"
    fi

    # 檢查是否需要（重新）編譯
    local need_build=0
    if [ ! -f "$WHISPER_DIR/build/bin/whisper-stream" ]; then
        need_build=1
    else
        # 檢查 dylib 是否正常（路徑搬遷後會壞）
        if ! "$WHISPER_DIR/build/bin/whisper-stream" --help &>/dev/null 2>&1; then
            echo -e "  ${C_WARN}[偵測]${NC} whisper-stream 無法執行（可能路徑已變更），需重新編譯"
            need_build=1
        fi
    fi

    if [ "$need_build" -eq 1 ]; then
        check_install "正在編譯 whisper.cpp（可能需要幾分鐘）..."
        rm -rf "$WHISPER_DIR/build"
        cd "$WHISPER_DIR"

        # 偵測架構，選擇正確的 SDL2 路徑
        local arch
        arch=$(uname -m)
        local cmake_extra_flags=""
        if [ "$arch" = "arm64" ]; then
            # Apple Silicon: 使用 ARM Homebrew SDL2 + Metal
            if [ -d "/opt/homebrew/Cellar/sdl2" ]; then
                cmake_extra_flags="-DCMAKE_OSX_ARCHITECTURES=arm64 -DWHISPER_METAL=ON -DGGML_NATIVE=OFF -DGGML_CPU_ARM_ARCH=armv8.5-a+fp16 -DCMAKE_PREFIX_PATH=/opt/homebrew"
            fi
        fi

        local ncpu
        ncpu=$(sysctl -n hw.ncpu)
        run_spinner "編譯中..." bash -c "cd '$WHISPER_DIR' && cmake -B build -DWHISPER_SDL2=ON $cmake_extra_flags 2>&1 && cmake --build build --target whisper-stream -j$ncpu 2>&1"
        echo ""
        cd "$SCRIPT_DIR"

        if [ -f "$WHISPER_DIR/build/bin/whisper-stream" ]; then
            check_ok "whisper.cpp 編譯完成"
        else
            check_fail "whisper.cpp 編譯失敗"
            return 1
        fi
    else
        check_ok "whisper-stream 已編譯且可執行"
    fi
}

# ─── Whisper 模型 ─────────────────────────────────
check_whisper_models() {
    section "Whisper 語音模型"

    local has_model=0
    for model_file in "ggml-base.en.bin" "ggml-small.en.bin" "ggml-large-v3-turbo.bin" "ggml-medium.en.bin"; do
        local model_path="$MODELS_DIR/$model_file"
        if [ -f "$model_path" ]; then
            local size
            size=$(du -h "$model_path" | cut -f1 | xargs)
            check_ok "$model_file ($size)"
            has_model=1
        fi
    done

    if [ "$has_model" -eq 0 ]; then
        check_install "正在下載預設模型 (large-v3-turbo，約 809MB)..."
        cd "$WHISPER_DIR"
        run_spinner "下載中..." bash models/download-ggml-model.sh large-v3-turbo
        echo ""
        cd "$SCRIPT_DIR"
        if [ -f "$MODELS_DIR/ggml-large-v3-turbo.bin" ]; then
            check_ok "ggml-large-v3-turbo.bin 下載完成"
        else
            check_fail "模型下載失敗，請手動下載"
        fi
    fi
}

# ─── Python venv ─────────────────────────────────
check_venv() {
    section "Python 虛擬環境"

    local need_create=0
    if [ ! -d "$VENV_DIR" ]; then
        need_create=1
    else
        # 檢查 venv 是否可用（路徑搬遷後會壞）
        if ! "$VENV_DIR/bin/python3" --version &>/dev/null 2>&1; then
            echo -e "  ${C_WARN}[偵測]${NC} venv 已損壞（可能路徑已變更），需重建"
            need_create=1
        # Apple Silicon：檢查 venv 是否為 ARM64（x86 venv 跑不了 Moonshine）
        elif [ "$(uname -m)" = "arm64" ]; then
            local venv_arch
            venv_arch=$("$VENV_DIR/bin/python3" -c "import platform; print(platform.machine())" 2>/dev/null)
            if [ "$venv_arch" != "arm64" ]; then
                echo -e "  ${C_WARN}[偵測]${NC} venv 是 $venv_arch 架構，需要 ARM64，重建中"
                need_create=1
            fi
        fi
    fi

    if [ "$need_create" -eq 1 ]; then
        check_install "正在建立 Python 虛擬環境..."
        rm -rf "$VENV_DIR"
        "$PYTHON_CMD" -m venv "$VENV_DIR"
        if [ $? -eq 0 ]; then
            check_ok "虛擬環境建立完成"
        else
            check_fail "虛擬環境建立失敗"
            return 1
        fi
    else
        check_ok "虛擬環境正常"
    fi

    # 檢查必要套件
    source "$VENV_DIR/bin/activate"

    local missing_pkgs=()
    if ! python3 -c "import ctranslate2" &>/dev/null 2>&1; then
        missing_pkgs+=("ctranslate2")
    fi
    if ! python3 -c "import sentencepiece" &>/dev/null 2>&1; then
        missing_pkgs+=("sentencepiece")
    fi
    if ! python3 -c "import opencc" &>/dev/null 2>&1; then
        missing_pkgs+=("opencc-python-reimplemented")
    fi
    if ! python3 -c "import sounddevice" &>/dev/null 2>&1; then
        missing_pkgs+=("sounddevice")
    fi
    if ! python3 -c "import numpy" &>/dev/null 2>&1; then
        missing_pkgs+=("numpy")
    fi
    if ! python3 -c "import faster_whisper" &>/dev/null 2>&1; then
        missing_pkgs+=("faster-whisper")
    fi
    if ! python3 -c "import resemblyzer" &>/dev/null 2>&1; then
        # resemblyzer 依賴 webrtcvad，webrtcvad 需要 pkg_resources（setuptools < 81）
        if ! python3 -c "import pkg_resources" &>/dev/null 2>&1; then
            pip install --quiet --disable-pip-version-check "setuptools<81" 2>&1 | tail -1
        fi
        missing_pkgs+=("resemblyzer")
    fi
    if ! python3 -c "import spectralcluster" &>/dev/null 2>&1; then
        missing_pkgs+=("spectralcluster")
    fi

    if [ ${#missing_pkgs[@]} -gt 0 ]; then
        check_install "正在安裝 Python 套件: ${missing_pkgs[*]}..."
        run_spinner "安裝中..." pip install --quiet --disable-pip-version-check "${missing_pkgs[@]}"
        echo ""
        # 驗證（用 import 名稱，不是 pip 套件名稱）
        local all_ok=1
        for pkg in ctranslate2 sentencepiece opencc sounddevice numpy faster_whisper resemblyzer spectralcluster; do
            if python3 -c "import $pkg" &>/dev/null 2>&1; then
                check_ok "Python 套件: $pkg"
            else
                check_fail "Python 套件: $pkg 安裝失敗"
                all_ok=0
            fi
        done
    else
        check_ok "Python 套件: ctranslate2, sentencepiece, opencc, sounddevice, numpy, faster-whisper, resemblyzer, spectralcluster"
    fi

    deactivate
}

# ─── Moonshine ASR ──────────────────────────────
check_moonshine() {
    section "Moonshine ASR (英文串流辨識引擎)"

    source "$VENV_DIR/bin/activate"

    if python3 -c "from moonshine_voice import get_model_for_language" &>/dev/null 2>&1; then
        check_ok "moonshine-voice 已安裝"
    else
        check_install "正在安裝 moonshine-voice..."
        run_spinner "安裝中..." pip install --quiet --disable-pip-version-check moonshine-voice
        echo ""
        if python3 -c "from moonshine_voice import get_model_for_language" &>/dev/null 2>&1; then
            check_ok "moonshine-voice 安裝完成"
        else
            check_fail "moonshine-voice 安裝失敗（英文模式將改用 Whisper）"
        fi
    fi

    # 下載預設模型 (medium streaming)
    if python3 -c "from moonshine_voice import get_model_for_language" &>/dev/null 2>&1; then
        # 先檢查模型是否已存在
        local model_status
        model_status=$(python3 -c "
import os, sys
from moonshine_voice import get_model_for_language, ModelArch
try:
    path, arch = get_model_for_language('en', ModelArch.MEDIUM_STREAMING)
    if os.path.isdir(path):
        print('EXISTS:' + path)
    else:
        print('NEED_DOWNLOAD')
except Exception:
    print('NEED_DOWNLOAD')
" 2>/dev/null)
        if [[ "$model_status" == EXISTS:* ]]; then
            check_ok "Moonshine medium 模型就緒"
        else
            check_install "正在下載 Moonshine 模型 (medium, ~245MB)..."
            if run_spinner "下載中..." python3 -c "
from moonshine_voice import get_model_for_language, ModelArch
path, arch = get_model_for_language('en', ModelArch.MEDIUM_STREAMING)
"; then
                echo ""
                check_ok "Moonshine medium 模型下載完成"
            else
                check_fail "Moonshine 模型下載失敗（英文模式將改用 Whisper）"
            fi
        fi
    fi

    deactivate
}

# ─── Argos 翻譯模型 ──────────────────────────────
check_argos_model() {
    section "Argos 離線翻譯模型 (英→中)"

    if [ -d "$ARGOS_PKG_DIR" ] && [ -f "$ARGOS_PKG_DIR/sentencepiece.model" ] && [ -d "$ARGOS_PKG_DIR/model" ]; then
        check_ok "翻譯模型已安裝 ($ARGOS_PKG_DIR)"
    else
        check_install "正在下載 Argos 翻譯模型..."
        # 使用 argos-translate Python 套件來安裝模型
        source "$VENV_DIR/bin/activate"
        run_spinner "安裝套件..." pip install --quiet --disable-pip-version-check argostranslate
        echo ""
        run_spinner "下載模型..." python3 -c "
from argostranslate import package
package.update_package_index()
pkgs = package.get_available_packages()
en_zh = next((p for p in pkgs if p.from_code == 'en' and p.to_code == 'zh'), None)
if en_zh:
    path = en_zh.download()
    package.install_from_path(path)
    print('OK')
else:
    print('FAIL')
"
        echo ""
        deactivate

        if [ -d "$ARGOS_PKG_DIR" ]; then
            check_ok "翻譯模型安裝完成"
        else
            # 模型可能安裝在不同版本的目錄
            local found
            found=$(find "$HOME/.local/share/argos-translate/packages" -maxdepth 1 -name "translate-en_zh*" -type d 2>/dev/null | head -1)
            if [ -n "$found" ]; then
                check_ok "翻譯模型安裝完成 ($found)"
                echo -e "  ${C_WARN}[注意]${NC} 模型版本路徑可能與程式預設不同"
                echo -e "  ${C_DIM}  程式預設: $ARGOS_PKG_DIR${NC}"
                echo -e "  ${C_DIM}  實際路徑: $found${NC}"
                echo -e "  ${C_WHITE}  可能需要更新 translate_meeting.py 中的 ARGOS_PKG_PATH${NC}"
            else
                check_fail "翻譯模型安裝失敗，請手動安裝"
                echo -e "  ${C_DIM}  pip install argostranslate${NC}"
                echo -e "  ${C_DIM}  然後用 Python 安裝 en→zh 模型${NC}"
            fi
        fi
    fi
}

# ─── 升級 ────────────────────────────────────────
do_upgrade() {
    section "從 GitHub 升級程式"

    # 檢查 git
    if ! command -v git &>/dev/null; then
        check_fail "找不到 git，請先安裝：brew install git"
        return 1
    fi

    # 建立暫存目錄
    local tmp_dir
    tmp_dir=$(mktemp -d)
    trap "rm -rf '$tmp_dir'" EXIT

    echo -e "  ${C_DIM}正在從 GitHub 下載最新版本...${NC}"
    if ! git clone --depth 1 "$GITHUB_REPO" "$tmp_dir/repo" 2>/dev/null; then
        check_fail "無法連接 GitHub，請檢查網路連線"
        return 1
    fi

    # 取得遠端版本號
    local remote_version
    remote_version=$(grep -m1 'APP_VERSION' "$tmp_dir/repo/translate_meeting.py" 2>/dev/null | sed 's/.*"\(.*\)".*/\1/')
    local local_version
    local_version=$(grep -m1 'APP_VERSION' "$SCRIPT_DIR/translate_meeting.py" 2>/dev/null | sed 's/.*"\(.*\)".*/\1/')

    echo -e "  ${C_WHITE}目前版本: v${local_version:-未知}${NC}"
    echo -e "  ${C_WHITE}最新版本: v${remote_version:-未知}${NC}"

    if [ "$local_version" = "$remote_version" ]; then
        check_ok "已經是最新版本 (v${local_version})"
        return 0
    fi

    # 比較版本號：若遠端比本地舊，不蓋過（開發機本地可能比 GitHub 新）
    _ver_gt() {
        # 回傳 0 表示 $1 > $2（版本號比較）
        [ "$(printf '%s\n' "$1" "$2" | sort -V | tail -n1)" = "$1" ] && [ "$1" != "$2" ]
    }
    if [ -n "$local_version" ] && [ -n "$remote_version" ] && _ver_gt "$local_version" "$remote_version"; then
        echo -e "  ${C_WARN}[跳過]${NC} 本地版本 (v${local_version}) 比 GitHub (v${remote_version}) 還新，不覆蓋"
        return 0
    fi

    # 更新主要程式檔案
    local files_updated=0
    for fname in translate_meeting.py start.sh install.sh SOP.md; do
        if [ -f "$tmp_dir/repo/$fname" ]; then
            cp "$tmp_dir/repo/$fname" "$SCRIPT_DIR/$fname"
            ((files_updated++)) || true
        fi
    done

    # 確保腳本可執行
    chmod +x "$SCRIPT_DIR/start.sh" "$SCRIPT_DIR/install.sh" 2>/dev/null

    check_ok "已升級 v${local_version} → v${remote_version}（更新 ${files_updated} 個檔案）"
    echo ""
    echo -e "  ${C_WARN}建議重新執行 ./install.sh 確認相依套件完整${NC}"
    return 0
}

# ─── 遠端 GPU Whisper 伺服器（選填）──────────────
setup_remote_whisper() {
    section "遠端 GPU 語音辨識伺服器（非必要，若未裝則用本機進行語音辨識）"

    # 檢查是否已有設定
    local existing_host existing_port existing_user existing_key existing_wport
    existing_host=$(python3 -c "
import json, os
p = '$SCRIPT_DIR/config.json'
if os.path.isfile(p):
    c = json.load(open(p))
    rw = c.get('remote_whisper')
    if rw: print(rw.get('host',''))
" 2>/dev/null)

    if [ -n "$existing_host" ]; then
        # 已有設定，讀取完整資訊
        existing_port=$(python3 -c "import json; rw=json.load(open('$SCRIPT_DIR/config.json'))['remote_whisper']; print(rw.get('ssh_port',22))" 2>/dev/null)
        existing_user=$(python3 -c "import json; rw=json.load(open('$SCRIPT_DIR/config.json'))['remote_whisper']; print(rw.get('ssh_user','root'))" 2>/dev/null)
        existing_key=$(python3 -c "import json; rw=json.load(open('$SCRIPT_DIR/config.json'))['remote_whisper']; print(rw.get('ssh_key',''))" 2>/dev/null)
        existing_wport=$(python3 -c "import json; rw=json.load(open('$SCRIPT_DIR/config.json'))['remote_whisper']; print(rw.get('whisper_port',8978))" 2>/dev/null)

        echo -e "  ${C_WHITE}已有遠端設定: ${existing_user}@${existing_host}:${existing_port}${NC}"

        # 組合 SSH（含 ControlMaster）
        local ctrl_sock="/tmp/jt-ssh-cm-${existing_user}@${existing_host}:${existing_port}"
        local chk_opts="-o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new -p $existing_port"
        chk_opts="$chk_opts -o ControlMaster=auto -o ControlPath=$ctrl_sock -o ControlPersist=120"
        if [ -n "$existing_key" ]; then
            chk_opts="$chk_opts -i $existing_key"
        fi

        local need_repair=0
        local repair_items=""
        local gpu_info="" cuda_check="" pt_ok="" ct2_ok="" ow_ok=""

        # 背景 spinner + 輸出緩衝（SSH 檢查需時數秒）
        spinner_start "正在檢查遠端環境"
        {
            # 1. SSH 連線
            if ssh $chk_opts "$existing_user@$existing_host" "echo ok" &>/dev/null; then
                check_ok "SSH 連線正常"

                # 2. Python3 + ffmpeg
                if ssh $chk_opts "$existing_user@$existing_host" "command -v python3" &>/dev/null; then
                    if ssh $chk_opts "$existing_user@$existing_host" "command -v ffmpeg" &>/dev/null; then
                        check_ok "Python3 + ffmpeg 就緒"
                    else
                        echo -e "  ${C_WARN}[缺少]${NC} ffmpeg 未安裝"
                        need_repair=1
                        repair_items="${repair_items} ffmpeg"
                    fi
                else
                    echo -e "  ${C_WARN}[缺少]${NC} Python3 未安裝"
                    need_repair=1
                    repair_items="${repair_items} python3"
                fi

                # 3. venv
                if ssh $chk_opts "$existing_user@$existing_host" "~/jt-whisper-server/venv/bin/python3 --version" &>/dev/null; then
                    check_ok "venv 正常"
                else
                    echo -e "  ${C_WARN}[缺少]${NC} venv 損壞或不存在"
                    need_repair=1
                    repair_items="${repair_items} venv"
                fi

                # 4. server.py
                if ssh $chk_opts "$existing_user@$existing_host" "test -f ~/jt-whisper-server/server.py" &>/dev/null; then
                    check_ok "server.py 存在"
                else
                    echo -e "  ${C_WARN}[缺少]${NC} server.py 不存在"
                    need_repair=1
                    repair_items="${repair_items} server.py"
                fi

                # 5. faster-whisper 套件
                if ssh $chk_opts "$existing_user@$existing_host" "~/jt-whisper-server/venv/bin/python3 -c 'import faster_whisper'" &>/dev/null 2>&1; then
                    check_ok "faster-whisper 套件就緒"
                else
                    echo -e "  ${C_WARN}[缺少]${NC} faster-whisper 套件缺失"
                    need_repair=1
                    repair_items="${repair_items} packages"
                fi

                # 5b. resemblyzer + spectralcluster（講者辨識）
                if ssh $chk_opts "$existing_user@$existing_host" "~/jt-whisper-server/venv/bin/python3 -c 'import resemblyzer; import spectralcluster'" &>/dev/null 2>&1; then
                    check_ok "resemblyzer + spectralcluster 就緒（講者辨識）"
                else
                    echo -e "  ${C_WARN}[缺少]${NC} resemblyzer + spectralcluster 套件缺失（講者辨識）"
                    need_repair=1
                    repair_items="${repair_items} packages"
                fi

                # 6. NVIDIA GPU + CUDA
                gpu_info=$(ssh $chk_opts "$existing_user@$existing_host" "nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1" 2>/dev/null)
                if [ -n "$gpu_info" ]; then
                    check_ok "NVIDIA GPU: ${gpu_info}"
                    cuda_check=$(ssh $chk_opts "$existing_user@$existing_host" "~/jt-whisper-server/venv/bin/python3 -c \"
import torch
pt = torch.cuda.is_available()
ct2 = False
ow = False
try:
    import ctranslate2
    ct2 = bool(ctranslate2.get_supported_compute_types('cuda'))
except: pass
try:
    import whisper
    ow = True
except: pass
print(f'{pt},{ct2},{ow}')
\"" 2>/dev/null)
                    pt_ok=$(echo "$cuda_check" | cut -d, -f1)
                    ct2_ok=$(echo "$cuda_check" | cut -d, -f2)
                    ow_ok=$(echo "$cuda_check" | cut -d, -f3)
                    if [ "$pt_ok" = "True" ] && [ "$ct2_ok" = "True" ]; then
                        check_ok "CUDA 可用（faster-whisper + CTranslate2）"
                    elif [ "$pt_ok" = "True" ] && [ "$ow_ok" = "True" ]; then
                        check_ok "CUDA 可用（openai-whisper + PyTorch）"
                    else
                        if [ "$pt_ok" != "True" ]; then
                            echo -e "  ${C_WARN}[警告]${NC} 有 GPU 但 PyTorch CUDA 不可用 — 需修復"
                        else
                            echo -e "  ${C_WARN}[警告]${NC} PyTorch CUDA 正常但無可用 CUDA 辨識引擎 — 需修復"
                        fi
                        need_repair=1
                        repair_items="${repair_items} cuda"
                    fi
                else
                    echo -e "  ${C_DIM}未偵測到 NVIDIA GPU（將以 CPU 辨識）${NC}"
                fi
            else
                check_fail "SSH 連線失敗"
                need_repair=1
                repair_items="ssh"
            fi
        } > "$_CHECK_BUF" 2>&1
        spinner_stop
        cat "$_CHECK_BUF"

        if [ "$need_repair" -eq 0 ]; then
            # 確認 SSH 免密碼登入（ControlMaster 仍在，不會再問密碼）
            if [ -n "$existing_key" ] && [ -f "${existing_key}.pub" ]; then
                if ! ssh $chk_opts "$existing_user@$existing_host" "grep -qF '$(cat "${existing_key}.pub")' ~/.ssh/authorized_keys 2>/dev/null"; then
                    ssh $chk_opts "$existing_user@$existing_host" "mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys" < "${existing_key}.pub"
                    if [ $? -eq 0 ]; then
                        check_ok "SSH 公鑰已加入遠端，日後免密碼"
                    fi
                fi
            fi
            # 檢查預設模型是否已下載
            local model_ok
            model_ok=$(ssh $chk_opts "$existing_user@$existing_host" "~/jt-whisper-server/venv/bin/python3 -c \"
from huggingface_hub import scan_cache_dir
try:
    ci = scan_cache_dir()
    names = [r.repo_id for r in ci.repos]
    print('yes' if any('large-v3-turbo' in n for n in names) else 'no')
except: print('no')
\"" 2>/dev/null)
            # 預下載所有辨識模型
            ssh $chk_opts "$existing_user@$existing_host" "
                ~/jt-whisper-server/venv/bin/python3 -c \"
import sys
# 偵測後端
use_openai = False
try:
    import ctranslate2
    if not ctranslate2.get_supported_compute_types('cuda'):
        use_openai = True
except:
    use_openai = True

if use_openai:
    try:
        import whisper
    except ImportError:
        use_openai = False

models = ['base.en', 'small.en', 'medium.en', 'large-v3-turbo', 'large-v3']
if use_openai:
    name_map = {'large-v3-turbo': 'turbo'}
    for m in models:
        ow_name = name_map.get(m, m)
        try:
            whisper.load_model(ow_name, device='cpu')
            print(f'  {m}: 已就緒', flush=True)
        except Exception as e:
            print(f'  {m}: 下載失敗 ({e})', flush=True)
else:
    from faster_whisper import WhisperModel
    for m in models:
        try:
            WhisperModel(m, device='cpu', compute_type='int8')
            print(f'  {m}: 已就緒', flush=True)
        except Exception as e:
            print(f'  {m}: 下載失敗 ({e})', flush=True)
\"
            " 2>&1 | grep -v "^Shared connection"
            check_ok "辨識模型檢查完成"
            # 同步部署最新 server.py
            local scp_chk_opts="-o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new -P $existing_port"
            scp_chk_opts="$scp_chk_opts -o ControlMaster=auto -o ControlPath=$ctrl_sock -o ControlPersist=120"
            if [ -n "$existing_key" ]; then
                scp_chk_opts="$scp_chk_opts -i $existing_key"
            fi
            local local_hash remote_hash
            local_hash=$(md5 -q "$SCRIPT_DIR/remote_whisper_server.py" 2>/dev/null || md5sum "$SCRIPT_DIR/remote_whisper_server.py" 2>/dev/null | cut -d' ' -f1)
            remote_hash=$(ssh $chk_opts "$existing_user@$existing_host" "md5sum ~/jt-whisper-server/server.py 2>/dev/null | cut -d' ' -f1" 2>/dev/null)
            if [ "$local_hash" != "$remote_hash" ]; then
                scp $scp_chk_opts "$SCRIPT_DIR/remote_whisper_server.py" "$existing_user@$existing_host:~/jt-whisper-server/server.py" &>/dev/null
                if [ $? -eq 0 ]; then
                    check_ok "server.py 已同步更新"
                fi
            fi
            # 關閉 SSH 多工
            ssh -o ControlPath="$ctrl_sock" -O exit "$existing_user@$existing_host" &>/dev/null || true
            check_ok "遠端 GPU 辨識環境正常（${existing_user}@${existing_host}）"
            return 0
        fi

        # 關閉檢查用 SSH 多工（修復前先關閉，安裝流程會建新的）
        ssh -o ControlPath="$ctrl_sock" -O exit "$existing_user@$existing_host" &>/dev/null || true

        # 需要修復
        echo ""
        echo -e "  ${C_WARN}偵測到問題:${repair_items}${NC}"
        echo -ne "  ${C_WHITE}是否修復遠端環境？(Y/n): ${NC}"
        read -r do_repair
        if [[ "$do_repair" =~ ^[Nn]$ ]]; then
            echo -e "  ${C_DIM}跳過修復${NC}"
            return 0
        fi

        # 用既有設定進入安裝流程
        local rw_host="$existing_host"
        local rw_ssh_port="$existing_port"
        local rw_user="$existing_user"
        local rw_key="$existing_key"
        local rw_port="$existing_wport"
    else
        # 沒有設定，問要不要新設
        echo -e "  ${C_WHITE}若有 Linux + NVIDIA GPU 伺服器，可部署遠端 Whisper 辨識服務，大幅加快語音辨識速度${NC}"
        echo -e "  ${C_DIM}離線處理音訊檔（--input）時速度快 5-10 倍${NC}"
        echo -e "  ${C_DIM}支援系統：DGX OS / Ubuntu（需有 NVIDIA 驅動與 CUDA）${NC}"
        echo -e "  ${C_DIM}不設定則使用本機 CPU 辨識${NC}"
        echo ""
        echo -ne "  ${C_WHITE}是否設定遠端 GPU 辨識？(y/N): ${NC}"
        read -r setup_remote
        if [[ ! "$setup_remote" =~ ^[Yy]$ ]]; then
            echo -e "  ${C_DIM}跳過遠端設定${NC}"
            return 0
        fi

        # 收集 SSH 連線資訊
        echo ""
        echo -ne "  ${C_WHITE}SSH 伺服器 IP: ${NC}"
        read -r rw_host
        if [ -z "$rw_host" ]; then
            echo -e "  ${C_DIM}未輸入，跳過${NC}"
            return 0
        fi

        echo -ne "  ${C_WHITE}SSH Port [22]: ${NC}"
        read -r rw_ssh_port
        rw_ssh_port=${rw_ssh_port:-22}

        echo -ne "  ${C_WHITE}SSH 使用者: ${NC}"
        read -r rw_user
        if [ -z "$rw_user" ]; then
            echo -e "  ${C_DIM}未輸入使用者，跳過${NC}"
            return 0
        fi

        # 自動找 SSH key
        local rw_key=""
        if [ -f "$HOME/.ssh/id_ed25519" ]; then
            rw_key="$HOME/.ssh/id_ed25519"
        elif [ -f "$HOME/.ssh/id_rsa" ]; then
            rw_key="$HOME/.ssh/id_rsa"
        fi
        echo -ne "  ${C_WHITE}SSH Key 路徑 [${rw_key:-留空用密碼}]: ${NC}"
        read -r rw_key_input
        if [ -n "$rw_key_input" ]; then
            rw_key="$rw_key_input"
        fi

        echo -ne "  ${C_WHITE}Whisper 服務 Port [8978]: ${NC}"
        read -r rw_port
        rw_port=${rw_port:-8978}
    fi

    # 組合 SSH 指令（使用 ControlMaster 多工，只需輸入一次密碼）
    local ctrl_sock="/tmp/jt-ssh-cm-${rw_user}@${rw_host}:${rw_ssh_port}"
    local ssh_opts="-o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new -p $rw_ssh_port"
    ssh_opts="$ssh_opts -o ControlMaster=auto -o ControlPath=$ctrl_sock -o ControlPersist=120"
    if [ -n "$rw_key" ]; then
        ssh_opts="$ssh_opts -i $rw_key"
    fi

    # 清理函式：關閉 SSH 多工連線
    _cleanup_ssh_cm() {
        ssh -o ControlPath="$ctrl_sock" -O exit "$rw_user@$rw_host" &>/dev/null || true
    }

    # 測試 SSH 連線（第一次連線，建立 ControlMaster）
    echo ""
    echo -e "  ${C_DIM}測試 SSH 連線...${NC}"
    if ! ssh $ssh_opts "$rw_user@$rw_host" "echo ok" &>/dev/null; then
        check_fail "SSH 連線失敗（$rw_user@$rw_host:$rw_ssh_port）"
        echo -e "  ${C_DIM}請確認 SSH 設定後重新執行 install.sh${NC}"
        _cleanup_ssh_cm
        return 1
    fi
    check_ok "SSH 連線成功（後續操作免重複輸入密碼）"

    # 設定 SSH 免密碼登入（若尚未設定）
    if [ -n "$rw_key" ] && [ -f "${rw_key}.pub" ]; then
        if ! ssh $ssh_opts "$rw_user@$rw_host" "grep -qF '$(cat "${rw_key}.pub")' ~/.ssh/authorized_keys 2>/dev/null"; then
            ssh $ssh_opts "$rw_user@$rw_host" "mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys" < "${rw_key}.pub"
            if [ $? -eq 0 ]; then
                check_ok "SSH 公鑰已加入遠端，日後免密碼"
            fi
        else
            check_ok "SSH 免密碼登入已設定"
        fi
    fi

    # 檢查遠端 Python3 + ffmpeg + 編譯工具
    local need_apt=""
    if ! ssh $ssh_opts "$rw_user@$rw_host" "command -v python3" &>/dev/null; then
        need_apt="python3 python3-venv python3-pip"
    fi
    if ! ssh $ssh_opts "$rw_user@$rw_host" "command -v ffmpeg" &>/dev/null; then
        need_apt="$need_apt ffmpeg"
    fi
    # 編譯工具與系統函式庫（C 擴充套件需要）
    # webrtcvad: 需要 gcc + Python.h
    # soundfile: 需要 libsndfile（resemblyzer → librosa → soundfile）
    # cffi: 需要 libffi（soundfile → cffi）
    # pkg-config: 用於偵測系統函式庫
    local build_pkgs="build-essential python3-dev pkg-config libffi-dev libsndfile1-dev"
    for pkg in $build_pkgs; do
        if ! ssh $ssh_opts "$rw_user@$rw_host" "dpkg -s $pkg" &>/dev/null 2>&1; then
            need_apt="$need_apt $pkg"
        fi
    done
    if [ -n "$need_apt" ]; then
        check_install "遠端缺少:${need_apt}，正在安裝..."
        if ! run_spinner "安裝中..." ssh $ssh_opts "$rw_user@$rw_host" "apt update -qq && apt install -y -qq $need_apt"; then
            echo ""
            check_fail "無法在遠端安裝系統套件"
            _cleanup_ssh_cm
            return 1
        fi
        echo ""
    fi
    check_ok "Python3 + ffmpeg + 編譯工具就緒"

    # 檢查遠端 NVIDIA GPU + CUDA
    local remote_gpu_name
    remote_gpu_name=$(ssh $ssh_opts "$rw_user@$rw_host" "nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1" 2>/dev/null)
    local torch_index=""
    if [ -n "$remote_gpu_name" ]; then
        check_ok "NVIDIA GPU: ${remote_gpu_name}"
        # 偵測 CUDA 版本（major.minor），決定 PyTorch wheel
        local cuda_version cuda_major cuda_minor
        cuda_version=$(ssh $ssh_opts "$rw_user@$rw_host" "nvidia-smi 2>/dev/null | grep -oP 'CUDA Version: \K[0-9]+\.[0-9]+'" 2>/dev/null)
        if [ -n "$cuda_version" ]; then
            cuda_major=$(echo "$cuda_version" | cut -d. -f1)
            cuda_minor=$(echo "$cuda_version" | cut -d. -f2)
            check_ok "CUDA: ${cuda_version}"
            # Blackwell (sm_100) 需要 cu128+；CUDA 13.x 或 12.8+ 用 cu128
            if [ "$cuda_major" -ge 13 ] || { [ "$cuda_major" -eq 12 ] && [ "$cuda_minor" -ge 8 ]; }; then
                torch_index="https://download.pytorch.org/whl/cu128"
            elif [ "$cuda_major" -eq 12 ]; then
                torch_index="https://download.pytorch.org/whl/cu124"
            elif [ "$cuda_major" -eq 11 ]; then
                torch_index="https://download.pytorch.org/whl/cu118"
            fi
        else
            echo -e "  ${C_WARN}未偵測到 CUDA，PyTorch 將安裝 CPU 版${NC}"
        fi
    else
        echo -e "  ${C_WARN}未偵測到 NVIDIA GPU，PyTorch 將安裝 CPU 版（辨識速度較慢）${NC}"
    fi

    # 建立 venv
    ssh $ssh_opts "$rw_user@$rw_host" "
        mkdir -p ~/jt-whisper-server
        if [ ! -d ~/jt-whisper-server/venv ]; then
            python3 -m venv ~/jt-whisper-server/venv
        fi
    "

    # 檢查 PyTorch CUDA 是否已正常（避免重複安裝 2-3 GB）
    local skip_torch=0
    if [ -n "$torch_index" ]; then
        local pt_ok
        pt_ok=$(ssh $ssh_opts "$rw_user@$rw_host" "~/jt-whisper-server/venv/bin/python3 -c 'import torch; print(torch.cuda.is_available())'" 2>/dev/null)
        if [ "$pt_ok" = "True" ]; then
            check_ok "PyTorch CUDA 已正常，跳過重裝"
            skip_torch=1
        fi
    fi

    if [ "$skip_torch" -eq 0 ]; then
        local torch_extra=""
        local torch_msg="安裝 PyTorch..."
        if [ -n "$torch_index" ]; then
            torch_extra="--force-reinstall --index-url $torch_index"
            torch_msg="安裝 PyTorch GPU 版（約 2-3 GB）..."
        fi
        check_install "$torch_msg"
        run_spinner "安裝中..." ssh $ssh_opts "$rw_user@$rw_host" "
            PIP=~/jt-whisper-server/venv/bin/pip
            \$PIP install --disable-pip-version-check torch $torch_extra 2>&1
        "
        if [ $? -ne 0 ]; then
            echo ""
            check_fail "PyTorch 安裝失敗"
            _cleanup_ssh_cm
            return 1
        fi
        echo ""
        check_ok "PyTorch 安裝完成"
    fi

    # 安裝其他套件（ctranslate2 需要 force-reinstall 以確保 CUDA 版）
    check_install "安裝遠端 Python 套件..."
    local fw_extra=""
    if [ -n "$torch_index" ]; then
        fw_extra="--force-reinstall"
    fi
    # setuptools<81: 保留 pkg_resources（webrtcvad 等舊套件需要，setuptools 82+ 已移除）
    # 必須放在同一行，否則 --force-reinstall 會把 setuptools 升回最新版
    # 依賴鏈: resemblyzer → webrtcvad(需gcc+Python.h+pkg_resources) + librosa → soundfile(需libsndfile+libffi)
    run_spinner "安裝中..." ssh $ssh_opts "$rw_user@$rw_host" "
        PIP=~/jt-whisper-server/venv/bin/pip
        \$PIP install --disable-pip-version-check 'setuptools<81' wheel 2>&1
        \$PIP install --disable-pip-version-check $fw_extra \
            'setuptools<81' ctranslate2 faster-whisper fastapi uvicorn python-multipart resemblyzer spectralcluster 2>&1
    "
    if [ $? -ne 0 ]; then
        echo ""
        check_fail "遠端套件安裝失敗"
        _cleanup_ssh_cm
        return 1
    fi
    echo ""
    check_ok "遠端 Python 套件安裝完成"

    # 驗證 CUDA（PyTorch + CTranslate2）
    if [ -n "$torch_index" ]; then
        local cuda_check
        cuda_check=$(ssh $ssh_opts "$rw_user@$rw_host" "~/jt-whisper-server/venv/bin/python3 -c \"
import torch
pt = torch.cuda.is_available()
try:
    import ctranslate2
    ct2 = bool(ctranslate2.get_supported_compute_types('cuda'))
except:
    ct2 = False
print(f'{pt},{ct2}')
\"" 2>/dev/null)
        local pt_ok=$(echo "$cuda_check" | cut -d, -f1)
        local ct2_ok=$(echo "$cuda_check" | cut -d, -f2)
        if [ "$pt_ok" = "True" ] && [ "$ct2_ok" = "True" ]; then
            check_ok "CUDA 驗證通過（faster-whisper + CTranslate2 CUDA）"
        elif [ "$pt_ok" = "True" ]; then
            check_install "CTranslate2 無 CUDA，改裝 openai-whisper（PyTorch CUDA）..."
            run_spinner "安裝中..." ssh $ssh_opts "$rw_user@$rw_host" "
                PIP=~/jt-whisper-server/venv/bin/pip
                \$PIP install --disable-pip-version-check 'setuptools<81' openai-whisper 2>&1
            "
            echo ""
            # 驗證 openai-whisper
            local ow_ok
            ow_ok=$(ssh $ssh_opts "$rw_user@$rw_host" "~/jt-whisper-server/venv/bin/python3 -c 'import whisper; print(\"ok\")'" 2>/dev/null)
            if [ "$ow_ok" = "ok" ]; then
                check_ok "CUDA 驗證通過（openai-whisper + PyTorch CUDA）"
            else
                echo -e "  ${C_WARN}[警告]${NC} openai-whisper 安裝失敗，Whisper 將以 CPU 執行"
            fi
        else
            echo -e "  ${C_WARN}[警告]${NC} PyTorch CUDA 無法使用，Whisper 將以 CPU 執行"
        fi
    fi

    # SCP 部署 server.py（ControlMaster 也適用於 scp）
    local scp_opts="-o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new -P $rw_ssh_port"
    scp_opts="$scp_opts -o ControlMaster=auto -o ControlPath=$ctrl_sock -o ControlPersist=120"
    if [ -n "$rw_key" ]; then
        scp_opts="$scp_opts -i $rw_key"
    fi
    if ! scp $scp_opts "$SCRIPT_DIR/remote_whisper_server.py" "$rw_user@$rw_host:~/jt-whisper-server/server.py" &>/dev/null; then
        check_fail "SCP 部署失敗"
        _cleanup_ssh_cm
        return 1
    fi
    check_ok "server.py 已部署"

    # 測試啟動
    ssh $ssh_opts "$rw_user@$rw_host" "
        cd ~/jt-whisper-server
        nohup venv/bin/python3 server.py --port $rw_port > /tmp/jt-whisper-server.log 2>&1 &
        echo \$!
    " > /tmp/rw_pid.txt 2>/dev/null

    # Health check（最多 15 秒）+ spinner
    _test_health() {
        local ok=1
        for i in $(seq 1 15); do
            if curl -s --connect-timeout 2 "http://$rw_host:$rw_port/health" 2>/dev/null | grep -q '"ok"'; then
                ok=0
                break
            fi
            sleep 1
        done
        return $ok
    }
    run_spinner "測試啟動遠端伺服器..." _test_health
    local health_ok=$?

    # 停止測試 server
    ssh $ssh_opts "$rw_user@$rw_host" "pkill -f 'server.py --port $rw_port'" &>/dev/null

    if [ "$health_ok" -eq 0 ]; then
        echo ""
        check_ok "遠端伺服器測試成功"
    else
        echo ""
        check_fail "遠端伺服器無法啟動，請檢查防火牆或 GPU 驅動"
        echo -e "  ${C_DIM}可查看遠端 log: ssh $rw_user@$rw_host cat /tmp/jt-whisper-server.log${NC}"
        _cleanup_ssh_cm
        return 1
    fi

    # 預下載所有辨識模型
    check_install "預下載辨識模型（首次約 6 GB）..."
    ssh $ssh_opts "$rw_user@$rw_host" "
        ~/jt-whisper-server/venv/bin/python3 -c \"
import sys
# 偵測後端
use_openai = False
try:
    import ctranslate2
    if not ctranslate2.get_supported_compute_types('cuda'):
        use_openai = True
except:
    use_openai = True

if use_openai:
    try:
        import whisper
    except ImportError:
        use_openai = False

models = ['base.en', 'small.en', 'medium.en', 'large-v3-turbo', 'large-v3']
if use_openai:
    name_map = {'large-v3-turbo': 'turbo'}
    for m in models:
        ow_name = name_map.get(m, m)
        try:
            whisper.load_model(ow_name, device='cpu')
            print(f'  {m}: 已就緒', flush=True)
        except Exception as e:
            print(f'  {m}: 下載失敗 ({e})', flush=True)
else:
    from faster_whisper import WhisperModel
    for m in models:
        try:
            WhisperModel(m, device='cpu', compute_type='int8')
            print(f'  {m}: 已就緒', flush=True)
        except Exception as e:
            print(f'  {m}: 下載失敗 ({e})', flush=True)
\"
    " 2>&1 | grep -v "^Shared connection"
    check_ok "辨識模型下載完成"

    # 關閉 SSH 多工連線
    _cleanup_ssh_cm

    # 寫入 config.json（merge 進現有設定）
    python3 -c "
import json, os
config_path = '$SCRIPT_DIR/config.json'
cfg = {}
if os.path.isfile(config_path):
    with open(config_path, 'r') as f:
        cfg = json.load(f)
cfg['remote_whisper'] = {
    'host': '$rw_host',
    'ssh_port': int('$rw_ssh_port'),
    'ssh_user': '$rw_user',
    'ssh_key': '$rw_key',
    'whisper_port': int('$rw_port'),
}
with open(config_path, 'w') as f:
    json.dump(cfg, f, ensure_ascii=False, indent=2)
    f.write('\n')
print('  config.json 已更新')
"
    check_ok "設定已儲存至 config.json"
}

# ─── 總結 ────────────────────────────────────────
print_summary() {
    echo ""
    echo -e "${C_TITLE}============================================================${NC}"
    echo -e "${C_TITLE}${BOLD}  安裝結果${NC}"
    echo -e "${C_TITLE}============================================================${NC}"
    echo ""
    echo -e "  ${C_OK}通過: $passed${NC}"
    [ "$installed" -gt 0 ] && echo -e "  ${C_WARN}新安裝: $installed${NC}"
    [ "$failed" -gt 0 ] && echo -e "  ${C_ERR}失敗: $failed${NC}"
    echo ""

    if [ "$failed" -gt 0 ]; then
        echo -e "  ${C_ERR}有 $failed 個項目安裝失敗，請查看上方訊息修正後重新執行。${NC}"
        echo ""
        exit 1
    else
        echo -e "  ${C_OK}${BOLD}全部就緒！可以執行 ./start.sh 啟動系統。${NC}"
        echo ""
        echo -e "  ${C_DIM}提示：若日後將此資料夾搬移到其他位置，請重新執行 ./install.sh${NC}"
        echo -e "  ${C_DIM}      安裝程式會自動偵測並修復因路徑變更而損壞的環境${NC}"
        echo ""
    fi
}

# ─── 主流程 ──────────────────────────────────────
print_title

# 處理 --upgrade 參數
if [ "$1" = "--upgrade" ]; then
    do_upgrade
    exit $?
fi

check_homebrew || exit 1
check_brew_deps
check_python || exit 1
check_whisper_cpp
check_whisper_models
check_venv
check_moonshine
check_argos_model
setup_remote_whisper
print_summary
