/**
 * 音訊擷取模組
 * 使用 MediaRecorder API 擷取麥克風音訊
 */

class AudioCapture {
    constructor() {
        this.mediaRecorder = null;
        this.audioStream = null;
        this.audioChunks = [];
        this.chunkIndex = 0;
        this.isRecording = false;
        this.startTime = null;
        this.durationInterval = null;
        
        // 音訊設定
        this.config = {
            mimeType: 'audio/webm',
            audioBitsPerSecond: 128000,
            timeslice: 3000  // 每 3 秒發送一次
        };
        
        // 檢查支援的 MIME 類型
        this.supportedMimeType = this._getSupportedMimeType();
    }
    
    /**
     * 檢查 MediaRecorder 支援的 MIME 類型
     */
    _getSupportedMimeType() {
        const types = [
            'audio/webm',
            'audio/webm;codecs=opus',
            'audio/ogg;codecs=opus',
            'audio/mp4'
        ];
        
        for (const type of types) {
            if (MediaRecorder.isTypeSupported(type)) {
                console.log(`✓ 支援的音訊格式: ${type}`);
                return type;
            }
        }
        
        console.warn('⚠️ 沒有找到支援的音訊格式');
        return null;
    }
    
    /**
     * 請求麥克風權限並初始化音訊串流
     */
    async requestMicrophonePermission() {
        try {
            const constraints = {
                audio: {
                    echoCancellation: true,
                    noiseSuppression: true,
                    autoGainControl: true,
                    sampleRate: 16000
                }
            };
            
            this.audioStream = await navigator.mediaDevices.getUserMedia(constraints);
            console.log('✓ 麥克風權限已授予');
            return true;
        } catch (error) {
            console.error('✗ 麥克風權限被拒絕:', error);
            throw new Error(`麥克風權限錯誤: ${error.message}`);
        }
    }
    
    /**
     * 開始錄音
     * @param {Function} onDataAvailable - 當音訊資料可用時的回調函式
     */
    startRecording(onDataAvailable) {
        if (!this.audioStream) {
            throw new Error('請先請求麥克風權限');
        }
        
        if (this.isRecording) {
            console.warn('⚠️ 已經在錄音中');
            return;
        }
        
        try {
            // 建立 MediaRecorder
            const options = {
                mimeType: this.supportedMimeType,
                audioBitsPerSecond: this.config.audioBitsPerSecond
            };
            
            this.mediaRecorder = new MediaRecorder(this.audioStream, options);
            this.audioChunks = [];
            this.chunkIndex = 0;
            this.isRecording = true;
            this.startTime = Date.now();
            
            // 當有音訊資料可用時
            this.mediaRecorder.ondataavailable = async (event) => {
                if (event.data && event.data.size > 0) {
                    this.audioChunks.push(event.data);
                    
                    // 轉換為 Base64 並傳送
                    const base64Audio = await this._blobToBase64(event.data);
                    
                    if (onDataAvailable) {
                        onDataAvailable({
                            audio: base64Audio,
                            chunk_index: this.chunkIndex++,
                            timestamp: Date.now()
                        });
                    }
                }
            };
            
            // 錄音停止時
            this.mediaRecorder.onstop = () => {
                console.log('✓ 錄音已停止');
                this.isRecording = false;
            };
            
            // 錯誤處理
            this.mediaRecorder.onerror = (error) => {
                console.error('✗ MediaRecorder 錯誤:', error);
                this.isRecording = false;
            };
            
            // 開始錄音（每 3 秒產生一個資料塊）
            this.mediaRecorder.start(this.config.timeslice);
            console.log('✓ 開始錄音');
            
            // 開始計時
            this._startDurationTimer();
            
        } catch (error) {
            console.error('✗ 啟動錄音失敗:', error);
            this.isRecording = false;
            throw error;
        }
    }
    
    /**
     * 停止錄音
     */
    stopRecording() {
        if (!this.isRecording) {
            console.warn('⚠️ 目前沒有在錄音');
            return;
        }
        
        if (this.mediaRecorder && this.mediaRecorder.state !== 'inactive') {
            this.mediaRecorder.stop();
        }
        
        this._stopDurationTimer();
        
        // 停止音訊串流
        if (this.audioStream) {
            this.audioStream.getTracks().forEach(track => track.stop());
        }
        
        this.isRecording = false;
        console.log('✓ 錄音已停止');
    }
    
    /**
     * 獲取錄音時長（秒）
     */
    getDuration() {
        if (!this.startTime) return 0;
        return Math.floor((Date.now() - this.startTime) / 1000);
    }
    
    /**
     * 開始計時器
     */
    _startDurationTimer() {
        this.durationInterval = setInterval(() => {
            const duration = this.getDuration();
            const minutes = Math.floor(duration / 60);
            const seconds = duration % 60;
            const display = `${String(minutes).padStart(2, '0')}:${String(seconds).padStart(2, '0')}`;
            
            // 更新 UI
            const durationEl = document.getElementById('recording-duration');
            if (durationEl) {
                durationEl.textContent = display;
            }
        }, 1000);
    }
    
    /**
     * 停止計時器
     */
    _stopDurationTimer() {
        if (this.durationInterval) {
            clearInterval(this.durationInterval);
            this.durationInterval = null;
        }
    }
    
    /**
     * 將 Blob 轉換為 Base64
     */
    _blobToBase64(blob) {
        return new Promise((resolve, reject) => {
            const reader = new FileReader();
            reader.onloadend = () => {
                // 移除 "data:audio/webm;base64," 前綴
                const base64 = reader.result.split(',')[1];
                resolve(base64);
            };
            reader.onerror = reject;
            reader.readAsDataURL(blob);
        });
    }
    
    /**
     * 獲取音訊串流分析器（用於音量顯示）
     */
    createAudioAnalyser() {
        if (!this.audioStream) return null;
        
        const audioContext = new (window.AudioContext || window.webkitAudioContext)();
        const analyser = audioContext.createAnalyser();
        const source = audioContext.createMediaStreamSource(this.audioStream);
        
        analyser.fftSize = 256;
        source.connect(analyser);
        
        return analyser;
    }
    
    /**
     * 監控音量等級
     */
    startAudioLevelMonitoring(onLevel) {
        const analyser = this.createAudioAnalyser();
        if (!analyser) return null;
        
        const dataArray = new Uint8Array(analyser.frequencyBinCount);
        
        const checkLevel = () => {
            if (!this.isRecording) return;
            
            analyser.getByteFrequencyData(dataArray);
            const average = dataArray.reduce((a, b) => a + b) / dataArray.length;
            const level = Math.min(100, Math.floor((average / 255) * 100));
            
            if (onLevel) {
                onLevel(level);
            }
            
            requestAnimationFrame(checkLevel);
        };
        
        checkLevel();
    }
    
    /**
     * 檢查 MediaRecorder 支援
     */
    static isSupported() {
        return !!(navigator.mediaDevices && 
                  navigator.mediaDevices.getUserMedia && 
                  window.MediaRecorder);
    }
}

// 匯出為全域變數
window.AudioCapture = AudioCapture;
