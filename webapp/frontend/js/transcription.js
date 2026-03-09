/**
 * 轉譯顯示模組
 * 處理轉譯和翻譯結果的顯示
 */

class TranscriptionDisplay {
    constructor(transcriptionContainerId, translationContainerId) {
        this.transcriptionContainer = document.getElementById(transcriptionContainerId);
        this.translationContainer = document.getElementById(translationContainerId);
        this.transcriptions = [];
        this.translations = [];
    }
    
    /**
     * 添加轉譯結果
     */
    addTranscription(data) {
        // 移除空狀態
        this._removeEmptyState(this.transcriptionContainer);
        
        // 建立轉譯項目
        const item = document.createElement('div');
        item.className = 'transcript-item';
        item.dataset.taskId = data.task_id;
        
        // 時間戳記
        const timeEl = document.createElement('div');
        timeEl.className = 'transcript-time';
        timeEl.textContent = this._formatTime(data.start_time, data.end_time);
        item.appendChild(timeEl);
        
        // 轉譯文字
        const textEl = document.createElement('div');
        textEl.className = 'transcript-text';
        textEl.textContent = data.text || '(無法識別)';
        item.appendChild(textEl);
        
        // 信心度和語言資訊
        if (data.confidence !== undefined || data.language) {
            const infoEl = document.createElement('div');
            infoEl.className = 'transcript-confidence';
            
            const parts = [];
            if (data.confidence !== undefined) {
                parts.push(`信心度: ${(data.confidence * 100).toFixed(1)}%`);
            }
            if (data.language) {
                parts.push(`語言: ${data.language}`);
            }
            if (!data.is_final) {
                parts.push('(處理中)');
            }
            
            infoEl.textContent = parts.join(' | ');
            item.appendChild(infoEl);
        }
        
        // 添加到容器
        this.transcriptionContainer.appendChild(item);
        
        // 捲動到最新項目
        this._scrollToBottom(this.transcriptionContainer);
        
        // 儲存到陣列
        this.transcriptions.push(data);
    }
    
    /**
     * 添加翻譯結果
     */
    addTranslation(data) {
        // 移除空狀態
        this._removeEmptyState(this.translationContainer);
        
        // 建立翻譯項目
        const item = document.createElement('div');
        item.className = 'translation-item';
        item.dataset.translationId = data.translation_id;
        
        // 原文
        const sourceEl = document.createElement('div');
        sourceEl.className = 'translation-source';
        sourceEl.innerHTML = `<strong>原文 (${data.source_lang}):</strong> ${data.source_text}`;
        item.appendChild(sourceEl);
        
        // 譯文
        const targetEl = document.createElement('div');
        targetEl.className = 'translation-text';
        targetEl.innerHTML = `<strong>翻譯 (${data.target_lang}):</strong> ${data.translated_text}`;
        item.appendChild(targetEl);
        
        // 服務資訊
        if (data.service || data.processing_time) {
            const infoEl = document.createElement('div');
            infoEl.className = 'translation-info';
            infoEl.style.fontSize = '12px';
            infoEl.style.color = '#6b7280';
            infoEl.style.marginTop = '4px';
            
            const parts = [];
            if (data.service) {
                parts.push(`服務: ${data.service}`);
            }
            if (data.processing_time) {
                parts.push(`耗時: ${data.processing_time.toFixed(2)}s`);
            }
            
            infoEl.textContent = parts.join(' | ');
            item.appendChild(infoEl);
        }
        
        // 添加到容器
        this.translationContainer.appendChild(item);
        
        // 捲動到最新項目
        this._scrollToBottom(this.translationContainer);
        
        // 儲存到陣列
        this.translations.push(data);
    }
    
    /**
     * 顯示處理中狀態
     */
    showProcessing(stage, progress, message) {
        // 可以在 UI 顯示處理進度
        console.log(`處理中: ${stage} - ${progress * 100}% - ${message}`);
    }
    
    /**
     * 清除轉譯結果
     */
    clearTranscriptions() {
        this.transcriptionContainer.innerHTML = `
            <div class="empty-state">
                <p>👆 點擊「開始錄音」開始使用</p>
                <p class="hint">支援即時語音轉譯和翻譯</p>
            </div>
        `;
        this.transcriptions = [];
    }
    
    /**
     * 清除翻譯結果
     */
    clearTranslations() {
        this.translationContainer.innerHTML = `
            <div class="empty-state">
                <p>翻譯結果將顯示在這裡</p>
            </div>
        `;
        this.translations = [];
    }
    
    /**
     * 獲取所有轉譯文字
     */
    getAllTranscriptions() {
        return this.transcriptions.map(t => t.text).join('\n');
    }
    
    /**
     * 獲取所有翻譯文字
     */
    getAllTranslations() {
        return this.translations.map(t => t.translated_text).join('\n');
    }
    
    /**
     * 複製轉譯文字到剪貼簿
     */
    async copyTranscriptions() {
        const text = this.getAllTranscriptions();
        if (!text) {
            alert('沒有可複製的轉譯內容');
            return false;
        }
        
        try {
            await navigator.clipboard.writeText(text);
            return true;
        } catch (error) {
            console.error('✗ 複製失敗:', error);
            return false;
        }
    }
    
    /**
     * 複製翻譯文字到剪貼簿
     */
    async copyTranslations() {
        const text = this.getAllTranslations();
        if (!text) {
            alert('沒有可複製的翻譯內容');
            return false;
        }
        
        try {
            await navigator.clipboard.writeText(text);
            return true;
        } catch (error) {
            console.error('✗ 複製失敗:', error);
            return false;
        }
    }
    
    /**
     * 下載轉譯結果為文字檔
     */
    downloadTranscriptions() {
        const text = this.getAllTranscriptions();
        if (!text) {
            alert('沒有可下載的轉譯內容');
            return;
        }
        
        const blob = new Blob([text], { type: 'text/plain;charset=utf-8' });
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = `transcription_${new Date().getTime()}.txt`;
        a.click();
        URL.revokeObjectURL(url);
    }
    
    /**
     * 格式化時間
     */
    _formatTime(startTime, endTime) {
        if (startTime === undefined) return '';
        
        const formatSeconds = (seconds) => {
            const mins = Math.floor(seconds / 60);
            const secs = Math.floor(seconds % 60);
            return `${String(mins).padStart(2, '0')}:${String(secs).padStart(2, '0')}`;
        };
        
        if (endTime !== undefined) {
            return `${formatSeconds(startTime)} - ${formatSeconds(endTime)}`;
        } else {
            return formatSeconds(startTime);
        }
    }
    
    /**
     * 移除空狀態
     */
    _removeEmptyState(container) {
        const emptyState = container.querySelector('.empty-state');
        if (emptyState) {
            emptyState.remove();
        }
    }
    
    /**
     * 捲動到底部
     */
    _scrollToBottom(container) {
        container.scrollTop = container.scrollHeight;
    }
}

// 匯出為全域變數
window.TranscriptionDisplay = TranscriptionDisplay;
