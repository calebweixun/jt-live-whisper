/**
 * WebSocket 客戶端模組
 * 處理與後端的 WebSocket 通訊
 */

class WebSocketClient {
    constructor(url) {
        this.url = url;
        this.ws = null;
        this.connected = false;
        this.sessionId = null;
        this.reconnectAttempts = 0;
        this.maxReconnectAttempts = 3;
        this.reconnectDelay = 2000;
        
        // 事件處理器
        this.handlers = {
            connected: [],
            disconnected: [],
            transcription: [],
            translation: [],
            error: [],
            processing: [],
            started: [],
            stopped: []
        };
    }
    
    /**
     * 連接 WebSocket
     */
    connect() {
        return new Promise((resolve, reject) => {
            try {
                this.ws = new WebSocket(this.url);
                
                this.ws.onopen = () => {
                    console.log('✓ WebSocket 已連線');
                    this.connected = true;
                    this.reconnectAttempts = 0;
                };
                
                this.ws.onmessage = (event) => {
                    this._handleMessage(event.data);
                };
                
                this.ws.onerror = (error) => {
                    console.error('✗ WebSocket 錯誤:', error);
                    this._emit('error', { message: 'WebSocket 連線錯誤' });
                };
                
                this.ws.onclose = (event) => {
                    console.log('✓ WebSocket 已斷線');
                    this.connected = false;
                    this.sessionId = null;
                    this._emit('disconnected', { code: event.code, reason: event.reason });
                    
                    // 嘗試重新連線
                    if (this.reconnectAttempts < this.maxReconnectAttempts) {
                        this._attemptReconnect();
                    }
                };
                
                // 監聽 connected 事件以 resolve Promise
                const connectHandler = (data) => {
                    this.sessionId = data.session_id;
                    resolve(data);
                };
                
                this.on('connected', connectHandler);
                
                // 超時處理
                setTimeout(() => {
                    if (!this.connected) {
                        this.off('connected', connectHandler);
                        reject(new Error('連線超時'));
                    }
                }, 10000);
                
            } catch (error) {
                console.error('✗ 建立 WebSocket 失敗:', error);
                reject(error);
            }
        });
    }
    
    /**
     * 斷開連接
     */
    disconnect() {
        if (this.ws) {
            this.ws.close();
            this.ws = null;
        }
        this.connected = false;
        this.sessionId = null;
    }
    
    /**
     * 發送訊息
     */
    send(message) {
        if (!this.connected || !this.ws) {
            console.error('✗ WebSocket 未連線');
            return false;
        }
        
        try {
            this.ws.send(JSON.stringify(message));
            return true;
        } catch (error) {
            console.error('✗ 發送訊息失敗:', error);
            return false;
        }
    }
    
    /**
     * 發送開始訊息
     */
    sendStart(config) {
        return this.send({
            type: 'start',
            data: {
                compute_mode: config.computeMode || 'server_gpu',
                source_lang: config.sourceLang || 'en',
                target_lang: config.targetLang || 'zh-TW',
                enable_translation: config.enableTranslation || false
            }
        });
    }
    
    /**
     * 發送音訊塊
     */
    sendAudioChunk(audioData) {
        return this.send({
            type: 'audio_chunk',
            data: audioData
        });
    }
    
    /**
     * 發送停止訊息
     */
    sendStop() {
        return this.send({
            type: 'stop',
            data: {}
        });
    }
    
    /**
     * 發送 ping
     */
    sendPing() {
        return this.send({
            type: 'ping'
        });
    }
    
    /**
     * 處理接收到的訊息
     */
    _handleMessage(data) {
        try {
            const message = JSON.parse(data);
            const { type, data: messageData, timestamp } = message;
            
            console.log(`← 收到訊息: ${type}`, messageData);
            
            switch (type) {
                case 'connected':
                    this._emit('connected', messageData);
                    break;
                
                case 'started':
                    this._emit('started', messageData);
                    break;
                
                case 'processing':
                    this._emit('processing', messageData);
                    break;
                
                case 'transcription':
                    this._emit('transcription', messageData);
                    break;
                
                case 'translation':
                    this._emit('translation', messageData);
                    break;
                
                case 'stopped':
                    this._emit('stopped', messageData);
                    break;
                
                case 'error':
                    this._emit('error', messageData);
                    break;
                
                case 'pong':
                    // Pong 回應，保持連線
                    break;
                
                default:
                    console.warn('⚠️ 未知訊息類型:', type);
            }
            
        } catch (error) {
            console.error('✗ 解析訊息失敗:', error);
        }
    }
    
    /**
     * 嘗試重新連線
     */
    _attemptReconnect() {
        this.reconnectAttempts++;
        console.log(`嘗試重新連線... (${this.reconnectAttempts}/${this.maxReconnectAttempts})`);
        
        setTimeout(() => {
            this.connect().catch(error => {
                console.error('✗ 重新連線失敗:', error);
            });
        }, this.reconnectDelay);
    }
    
    /**
     * 註冊事件處理器
     */
    on(event, handler) {
        if (this.handlers[event]) {
            this.handlers[event].push(handler);
        }
    }
    
    /**
     * 移除事件處理器
     */
    off(event, handler) {
        if (this.handlers[event]) {
            this.handlers[event] = this.handlers[event].filter(h => h !== handler);
        }
    }
    
    /**
     * 觸發事件
     */
    _emit(event, data) {
        if (this.handlers[event]) {
            this.handlers[event].forEach(handler => {
                try {
                    handler(data);
                } catch (error) {
                    console.error(`✗ 事件處理器錯誤 (${event}):`, error);
                }
            });
        }
    }
    
    /**
     * 啟動心跳檢測
     */
    startHeartbeat(interval = 30000) {
        this.heartbeatInterval = setInterval(() => {
            if (this.connected) {
                this.sendPing();
            }
        }, interval);
    }
    
    /**
     * 停止心跳檢測
     */
    stopHeartbeat() {
        if (this.heartbeatInterval) {
            clearInterval(this.heartbeatInterval);
            this.heartbeatInterval = null;
        }
    }
    
    /**
     * 檢查 WebSocket 支援
     */
    static isSupported() {
        return 'WebSocket' in window;
    }
}

// 匯出為全域變數
window.WebSocketClient = WebSocketClient;
