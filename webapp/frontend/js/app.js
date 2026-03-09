/**
 * 主應用程式邏輯
 * 整合音訊擷取、WebSocket 通訊和轉譯顯示
 */

class App {
    constructor() {
        // 判斷 WebSocket URL
        const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
        const host = window.location.hostname || 'localhost';
        const port = 8000; // 後端端口
        this.wsUrl = `${protocol}//${host}:${port}/api/v1/ws`;
        
        // 初始化模組
        this.audioCapture = new AudioCapture();
        this.wsClient = new WebSocketClient(this.wsUrl);
        this.transcriptionDisplay = new TranscriptionDisplay('transcription-content', 'translation-content');
        
        // 狀態
        this.isRecording = false;
        this.envCheckPassed = false;
        
        // 綁定 UI 元素
        this._bindElements();
        
        // 綁定事件
        this._bindEvents();
        
        // 執行環境檢查
        this._performEnvironmentCheck();
    }
    
    /**
     * 綁定 UI 元素
     */
    _bindElements() {
        // 環境檢查對話框
        this.envCheckDialog = document.getElementById('env-check-dialog');
        this.envCheckClose = document.getElementById('env-check-close');
        this.envCheckRetry = document.getElementById('env-check-retry');
        
        // 錯誤對話框
        this.errorDialog = document.getElementById('error-dialog');
        this.errorContent = document.getElementById('error-content');
        this.errorClose = document.getElementById('error-close');
        
        // 主應用容器
        this.appContainer = document.getElementById('app-container');
        
        // 控制元素
        this.startBtn = document.getElementById('start-btn');
        this.stopBtn = document.getElementById('stop-btn');
        this.clearBtn = document.getElementById('clear-btn');
        this.copyBtn = document.getElementById('copy-btn');
        this.downloadBtn = document.getElementById('download-btn');
        this.clearTranslationBtn = document.getElementById('clear-translation-btn');
        this.copyTranslationBtn = document.getElementById('copy-translation-btn');
        
        // 配置元素
        this.sourceLang = document.getElementById('source-lang');
        this.targetLang = document.getElementById('target-lang');
        this.computeMode = document.getElementById('compute-mode');
        this.enableTranslation = document.getElementById('enable-translation');
        
        // 狀態元素
        this.statusIndicator = document.getElementById('status-indicator');
        this.sessionId = document.getElementById('session-id');
        this.serverVersion = document.getElementById('server-version');
        this.gpuStatus = document.getElementById('gpu-status');
        this.recordingInfo = document.getElementById('recording-info');
        
        // 翻譯面板
        this.translationPanel = document.getElementById('translation-panel');
    }
    
    /**
     * 綁定事件
     */
    _bindEvents() {
        // 環境檢查
        this.envCheckClose.addEventListener('click', () => this._closeEnvCheck());
        this.envCheckRetry.addEventListener('click', () => this._performEnvironmentCheck());
        
        // 錯誤對話框
        this.errorClose.addEventListener('click', () => this._closeErrorDialog());
        
        // 錄音控制
        this.startBtn.addEventListener('click', () => this._handleStart());
        this.stopBtn.addEventListener('click', () => this._handleStop());
        
        // 轉譯結果操作
        this.clearBtn.addEventListener('click', () => this.transcriptionDisplay.clearTranscriptions());
        this.copyBtn.addEventListener('click', async () => {
            const success = await this.transcriptionDisplay.copyTranscriptions();
            if (success) this._showToast('已複製到剪貼簿');
        });
        this.downloadBtn.addEventListener('click', () => this.transcriptionDisplay.downloadTranscriptions());
        
        // 翻譯結果操作
        this.clearTranslationBtn.addEventListener('click', () => this.transcriptionDisplay.clearTranslations());
        this.copyTranslationBtn.addEventListener('click', async () => {
            const success = await this.transcriptionDisplay.copyTranslations();
            if (success) this._showToast('已複製到剪貼簿');
        });
        
        // 配置變更
        this.enableTranslation.addEventListener('change', (e) => {
            this.translationPanel.style.display = e.target.checked ? 'block' : 'none';
        });
        
        // WebSocket 事件
        this.wsClient.on('connected', (data) => this._handleConnected(data));
        this.wsClient.on('disconnected', () => this._handleDisconnected());
        this.wsClient.on('started', (data) => this._handleStarted(data));
        this.wsClient.on('transcription', (data) => this._handleTranscription(data));
        this.wsClient.on('translation', (data) => this._handleTranslation(data));
        this.wsClient.on('processing', (data) => this._handleProcessing(data));
        this.wsClient.on('stopped', (data) => this._handleStopped(data));
        this.wsClient.on('error', (data) => this._handleError(data));
    }
    
    /**
     * 執行環境檢查
     */
    async _performEnvironmentCheck() {
        const checks = {
            'browser-support': { label: '瀏覽器支援', check: this._checkBrowserSupport },
            'websocket-support': { label: 'WebSocket 支援', check: this._checkWebSocketSupport },
            'mediarecorder-support': { label: 'MediaRecorder 支援', check: this._checkMediaRecorderSupport },
            'microphone-permission': { label: '麥克風權限', check: this._checkMicrophonePermission },
            'server-connection': { label: 'Server 連線', check: this._checkServerConnection }
        };
        
        let allPassed = true;
        
        for (const [id, { label, check }] of Object.entries(checks)) {
            const statusEl = document.getElementById(id);
            statusEl.textContent = '檢查中...';
            statusEl.className = 'check-status checking';
            
            try {
                const result = await check.call(this);
                statusEl.textContent = result ? '✓ 通過' : '✗ 失敗';
                statusEl.className = result ? 'check-status success' : 'check-status error';
                
                if (!result) allPassed = false;
            } catch (error) {
                statusEl.textContent = `✗ ${error.message}`;
                statusEl.className = 'check-status error';
                allPassed = false;
            }
        }
        
        // 更新按鈕狀態
        this.envCheckClose.disabled = !allPassed;
        this.envCheckRetry.style.display = allPassed ? 'none' : 'inline-block';
        this.envCheckPassed = allPassed;
    }
    
    /**
     * 檢查瀏覽器支援
     */
    _checkBrowserSupport() {
        return !!(navigator.mediaDevices && navigator.clipboard);
    }
    
    /**
     * 檢查 WebSocket 支援
     */
    _checkWebSocketSupport() {
        return WebSocketClient.isSupported();
    }
    
    /**
     * 檢查 MediaRecorder 支援
     */
    _checkMediaRecorderSupport() {
        return AudioCapture.isSupported();
    }
    
    /**
     * 檢查麥克風權限
     */
    async _checkMicrophonePermission() {
        try {
            await this.audioCapture.requestMicrophonePermission();
            return true;
        } catch (error) {
            return false;
        }
    }
    
    /**
     * 檢查 Server 連線
     */
    async _checkServerConnection() {
        try {
            const host = window.location.hostname || 'localhost';
            const response = await fetch(`http://${host}:8000/api/v1/health`);
            const data = await response.json();
            
            if (data.success) {
                // 更新 Server 資訊
                this.serverVersion.textContent = data.data.version || '1.0.0';
                
                // GPU 狀態
                const gpu = data.data.services?.transcription?.gpu || data.data.gpu_info;
                if (gpu && gpu.available) {
                    this.gpuStatus.textContent = `GPU: ✓ ${gpu.device_name || 'Available'}`;
                } else {
                    this.gpuStatus.textContent = 'GPU: ✗ 不可用';
                }
                
                return true;
            }
            return false;
        } catch (error) {
            return false;
        }
    }
    
    /**
     * 關閉環境檢查對話框
     */
    _closeEnvCheck() {
        if (!this.envCheckPassed) return;
        
        this.envCheckDialog.style.display = 'none';
        this.appContainer.style.opacity = '1';
        
        // 連接 WebSocket
        this._connectWebSocket();
    }
    
    /**
     * 連接 WebSocket
     */
    async _connectWebSocket() {
        try {
            await this.wsClient.connect();
            this.wsClient.startHeartbeat();
        } catch (error) {
            this._showError('無法連接到 Server', error.message);
        }
    }
    
    /**
     * 處理開始錄音
     */
    async _handleStart() {
        if (this.isRecording) return;
        
        try {
            // 獲取配置
            const config = {
                computeMode: this.computeMode.value,
                sourceLang: this.sourceLang.value,
                targetLang: this.targetLang.value,
                enableTranslation: this.enableTranslation.checked
            };
            
            // 發送開始訊息
            this.wsClient.sendStart(config);
            
            // 開始錄音
            this.audioCapture.startRecording((audioData) => {
                this.wsClient.sendAudioChunk(audioData);
            });
            
            // 開始音量監控
            this.audioCapture.startAudioLevelMonitoring((level) => {
                this._updateAudioLevel(level);
            });
            
            // 更新 UI
            this.isRecording = true;
            this.startBtn.style.display = 'none';
            this.stopBtn.style.display = 'inline-flex';
            this.recordingInfo.style.display = 'block';
            
        } catch (error) {
            this._showError('啟動錄音失敗', error.message);
        }
    }
    
    /**
     * 處理停止錄音
     */
    _handleStop() {
        if (!this.isRecording) return;
        
        // 停止錄音
        this.audioCapture.stopRecording();
        
        // 發送停止訊息
        this.wsClient.sendStop();
        
        // 更新 UI
        this.isRecording = false;
        this.startBtn.style.display = 'inline-flex';
        this.stopBtn.style.display = 'none';
        this.recordingInfo.style.display = 'none';
    }
    
    /**
     * 處理 WebSocket 連接成功
     */
    _handleConnected(data) {
        this.sessionId.textContent = data.session_id.substring(0, 8) + '...';
        this.statusIndicator.textContent = '已連線';
        this.statusIndicator.className = 'status-badge status-connected';
        console.log('✓ 已連線到 Server');
    }
    
    /**
     * 處理 WebSocket 斷線
     */
    _handleDisconnected() {
        this.statusIndicator.textContent = '未連線';
        this.statusIndicator.className = 'status-badge status-disconnected';
        console.log('✓ 已斷線');
    }
    
    /**
     * 處理開始轉譯
     */
    _handleStarted(data) {
        console.log('✓ 開始轉譯');
    }
    
    /**
     * 處理轉譯結果
     */
    _handleTranscription(data) {
        this.transcriptionDisplay.addTranscription(data);
    }
    
    /**
     * 處理翻譯結果
     */
    _handleTranslation(data) {
        this.transcriptionDisplay.addTranslation(data);
    }
    
    /**
     * 處理處理中狀態
     */
    _handleProcessing(data) {
        this.transcriptionDisplay.showProcessing(data.stage, data.progress, data.message);
    }
    
    /**
     * 處理停止
     */
    _handleStopped(data) {
        console.log('✓ 停止轉譯');
        this._showToast(`已完成 - 時長: ${data.total_duration}s`);
    }
    
    /**
     * 處理錯誤
     */
    _handleError(data) {
        this._showError(data.message, data.details?.reason || '');
        
        // 如果是不可恢復的錯誤，停止錄音
        if (!data.recoverable && this.isRecording) {
            this._handleStop();
        }
    }
    
    /**
     * 更新音量等級
     */
    _updateAudioLevel(level) {
        const audioLevelBar = document.getElementById('audio-level-bar');
        if (audioLevelBar) {
            audioLevelBar.style.setProperty('--audio-level', `${level}%`);
        }
    }
    
    /**
     * 顯示錯誤對話框
     */
    _showError(title, message) {
        this.errorContent.innerHTML = `<strong>${title}</strong><br>${message}`;
        this.errorDialog.style.display = 'flex';
    }
    
    /**
     * 關閉錯誤對話框
     */
    _closeErrorDialog() {
        this.errorDialog.style.display = 'none';
    }
    
    /**
     * 顯示 Toast 通知
     */
    _showToast(message) {
        // 簡單的 Toast 實現
        alert(message);
    }
}

// 當 DOM 載入完成後初始化應用程式
document.addEventListener('DOMContentLoaded', () => {
    window.app = new App();
});
