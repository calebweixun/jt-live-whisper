<!--
Sync Impact Report
==================
Version: 1.0.0 (Initial Constitution)
Created: 2026-03-09
Modified Principles: N/A (Initial version)
Added Sections: All (Initial version)
Removed Sections: None

Templates Status:
✅ spec-template.md - Reviewed (no changes needed, user stories structure aligns)
✅ plan-template.md - Reviewed (no changes needed, constitution check section present)
✅ tasks-template.md - Reviewed (no changes needed, task organization aligns)

Follow-up TODOs: None
-->

# jt-live-whisper Constitution

**專案使命**：打造 100% 全地端運行的 AI 語音工具集，透過 Web 化技術打破裝置相容性限制，在保障隱私、零成本、高效能的前提下，為使用者提供即時轉錄、即時翻譯、講者辨識與會議摘要功能。

## Core Principles

### I. Web 化優先 (Web-First for Cross-Platform)

**核心要求**：
- 所有功能必須提供 Web 介面選項，使不同裝置的使用者可以方便直接使用
- 透過 Web 技術打破 macOS / Windows / Linux 之間的相容性與差異
- 前端採用輕量化技術（原生 JavaScript / 輕量框架），避免重量級 SPA 框架（React / Vue / Angular）
- Web 介面必須與地端運行原則相容：可透過本地端 Web Server 提供服務

**理由**：目前系統僅支援 macOS，透過 Web 化可擴展到所有平台，同時保持地端運行的核心價值。

### II. 地端運行與隱私保護 (On-Premise & Privacy-First) [NON-NEGOTIABLE]

**核心要求**：
- 所有 AI 模型必須在使用者自有設備或區域網路內運行，禁止連接第三方雲端 API
- 所有模型必須預先下載到系統中，開發和部署過程中不得連網下載
- 使用者的語音資料、轉錄內容、會議記錄不得離開使用者控制的環境
- 支援兩種部署模式：單機模式（所有處理在本機）、本機 + 區域網路 GPU 伺服器模式

**理由**：隱私保護是本專案的核心價值，不可妥協。使用者的會議內容、語音資料可能涉及商業機密或個人隱私。

### III. 效能與輕量化優先 (Performance & Lightweight)

**核心要求**：
- 開發技術棧以效能、輕量化為第一考量
- 避免引入重量級框架或不必要的依賴
- 優化資源使用，系統必須能在低配設備（8GB RAM MacBook Air）正常運行
- 追求快速啟動（< 5 秒）、低記憶體佔用（< 500MB 不含模型）
- 即時轉錄延遲必須控制在合理範圍（Whisper < 2s, Moonshine < 500ms）

**效能指標**：
- 啟動時間：< 5 秒
- 記憶體佔用（不含模型）：< 500MB
- 即時轉錄延遲：Whisper < 2s, Moonshine < 500ms
- Web 介面載入時間：< 1 秒

**理由**：語音即時轉錄對效能要求高，使用者體驗直接受延遲影響。輕量化確保在各種設備上都能流暢運行。

### IV. 最小化開發 (Minimal Development & YAGNI)

**核心要求**：
- 不要過度開發：每個功能都要有明確的使用者需求
- 嚴格遵循 YAGNI（You Ain't Gonna Need It）原則
- 遵循開發指南與命令（.specify 規範）
- 每個新功能都必須在 spec.md 中明確定義後才能實作
- 避免「以防萬一」的抽象層或「未來可能需要」的功能

**審查標準**：
- 新功能必須回答：「現在就需要嗎？」「沒有它系統無法運作嗎？」
- 複雜度增加必須有明確的價值回報

**理由**：保持專案精簡、可維護，避免功能膨脹（feature creep）。

### V. 版本控制與可追溯性 (Version Control & Traceability)

**核心要求**：
- 開發時必須執行 git commit、push 確保操作步驟被記錄
- 每個 commit 必須有清晰的繁體中文訊息說明變更內容
- 使用語義化版本（Semantic Versioning）：MAJOR.MINOR.PATCH
  - MAJOR：重大架構變更或不相容的 API 變更
  - MINOR：新增功能但保持向下相容
  - PATCH：錯誤修正、文件更新
- 保持完整的開發歷程記錄，重要決策必須記錄在 commit message 或文件中

**Commit 訊息格式**：
```
類型: 簡短描述（50 字元以內）

詳細說明（如需要）：
- 變更內容
- 變更理由
- 影響範圍
```

類型：feat（新功能）/ fix（修正）/ docs（文件）/ refactor（重構）/ perf（效能）/ test（測試）

**理由**：確保開發過程可追溯、可回溯，便於團隊協作和問題定位。

### VI. 繁體中文優先 (Traditional Chinese First)

**核心要求**：
- 所有開發者問答一律以繁體中文進行
- 程式碼註解使用繁體中文（英文技術術語除外）
- 文件（README.md、SOP.md、specs/）使用繁體中文
- 使用者介面使用繁體中文
- Git commit 訊息使用繁體中文
- 例外：變數名稱、函式名稱、API endpoint 使用英文（符合程式碼慣例）

**理由**：專案由台灣開發者主導，目標使用者主要為繁體中文使用者，使用繁體中文可降低溝通成本、提高文件可讀性。

## 技術棧與工具鏈要求

### 技術棧標準

**後端（必須）**：
- Python 3.12+
- FastAPI（輕量高效的 Web 框架）
- uvicorn（ASGI 伺服器）

**前端（建議）**：
- 原生 JavaScript（ES6+）或輕量框架（Alpine.js、Preact、Lit）
- 避免：React、Vue、Angular 等重量級框架
- CSS：原生 CSS 或輕量化工具（Tailwind CSS、UnoCSS）

**AI 模型（固定）**：
- 語音辨識：Whisper (whisper.cpp)、Moonshine、faster-whisper
- 翻譯 / 摘要：Qwen 2.5、Phi-4、GPT-OSS 等開源 LLM（透過 Ollama）
- 翻譯備援：Argos Translate（完全離線）
- 講者辨識：resemblyzer + spectralcluster

**部署方式**：
- 單機模式：所有處理在本機（MacBook / Mac mini）
- 本機 + GPU 伺服器模式：音訊擷取在本機，語音辨識和講者辨識在區域網路 GPU 伺服器

### 依賴管理

- 使用 `requirements.txt` 或 `pyproject.toml` 管理 Python 依賴
- 每個依賴都要有明確的版本號
- 新增依賴必須在 spec.md 中說明理由

### 測試要求（選用）

- 測試並非強制，但如果實作測試，必須遵循 TDD 原則
- 測試必須在功能實作前編寫並確認失敗（Red）
- 功能實作後測試必須通過（Green）
- 測試框架：pytest

## 開發工作流程

### 特性開發流程

1. **需求確認**：在 `.specify/specs/` 中建立 spec.md，明確定義使用者故事和驗收標準
2. **計畫制定**：執行 `/speckit.plan` 產生 plan.md，定義技術架構和實作步驟
3. **任務拆解**：執行 `/speckit.tasks` 產生 tasks.md，拆解為可執行的小任務
4. **實作**：執行 `/speckit.implement` 或手動逐項完成 tasks.md 中的任務
5. **提交**：每完成一個任務或一個邏輯完整的變更，執行 git commit 並 push
6. **驗證**：根據 spec.md 中的驗收標準驗證功能

### Git Commit 規範

- 每個 commit 必須對應一個明確的變更
- Commit message 必須使用繁體中文
- 格式：`類型: 簡短描述`
- 類型：feat / fix / docs / refactor / perf / test

### 程式碼審查標準（如適用）

- 是否符合憲章原則？
- 是否引入不必要的依賴？
- 是否有效能問題？
- 是否有隱私安全疑慮（資料外洩）？
- 註解和文件是否使用繁體中文？

## Governance

### 憲章優先級

本憲章是專案的最高指導原則，所有開發活動必須符合憲章要求。當憲章與其他文件衝突時，以憲章為準。

### 修訂流程

- 憲章修訂必須記錄修訂理由、影響範圍
- 版本號遵循語義化版本：
  - MAJOR：移除或重新定義核心原則
  - MINOR：新增原則或實質性擴充指導
  - PATCH：文字澄清、錯字修正、非語意性調整
- 修訂後必須更新 `LAST_AMENDED_DATE` 和 `Version`
- 修訂後必須產生 Sync Impact Report（參見檔案頂端）

### 合規檢查

- 所有 spec.md 必須包含 Constitution Check 區段，驗證是否符合憲章要求
- 所有 plan.md 必須包含 Constitution Check 區段
- 開發過程中如有違反憲章的情況，必須在文件中明確說明並提出替代方案

**Version**: 1.0.0 | **Ratified**: 2026-03-09 | **Last Amended**: 2026-03-09
