# Feature Specification: Web 音訊串流轉譯介面

**Feature Branch**: `001-web-streaming-interface`  
**Created**: 2026-03-09  
**Status**: Draft  
**Input**: 建立 Web 介面，透過 Docker 部署在 LAN Server 上，提供音訊串流功能讓使用者可以即時轉譯和翻譯文字。支援 GPU (RTX 5060) 運算和 OpenVINO 本地運算兩種模式。

## User Scenarios & Testing *(mandatory)*

### User Story 1 - 透過瀏覽器存取即時轉譯服務 (Priority: P1)

使用者在區域網路內的任何裝置（Windows、macOS、Linux、平板、手機）上開啟瀏覽器，連線到 Server 的 Web 介面，開始音訊串流並即時看到語音轉譯為文字。

**Why this priority**: 這是核心 MVP 功能，實現「透過 Web 打破裝置相容性限制」的主要目標。使用者無需安裝任何軟體，只需瀏覽器即可使用。

**Independent Test**: 在任意裝置（如 Windows 筆電）上開啟瀏覽器，連線到 http://[server-ip]:8000，點擊「開始轉譯」，對麥克風說話，畫面應即時顯示轉譯文字。

**Acceptance Scenarios**:

1. **Given** 使用者在區域網路內且 Server 正在運行，**When** 使用者在瀏覽器輸入 Server IP 位址，**Then** 系統顯示 Web 介面主頁
2. **Given** 使用者在 Web 介面主頁，**When** 使用者點擊「開始轉譯」並授權麥克風權限，**Then** 系統開始擷取音訊並串流到 Server
3. **Given** 音訊串流正在進行，**When** 使用者說話，**Then** 轉譯文字在 3 秒內顯示於畫面上
4. **Given** 轉譯正在進行，**When** 使用者點擊「停止」，**Then** 系統停止擷取音訊並顯示完整轉譯記錄

---

### User Story 2 - 即時翻譯轉譯文字 (Priority: P2)

使用者在轉譯過程中啟用翻譯功能，系統將轉譯出的文字即時翻譯為指定語言（如英文轉繁體中文，或繁體中文轉英文）。

**Why this priority**: 翻譯是現有系統的核心價值功能之一，可大幅提升使用者體驗，但技術上可在基礎轉譯功能完成後獨立開發。

**Independent Test**: 在 Web 介面啟動轉譯後，勾選「啟用翻譯」並選擇「英文→繁體中文」，對麥克風說英文，畫面應同時顯示英文轉譯和繁體中文翻譯。

**Acceptance Scenarios**:

1. **Given** 使用者在 Web 介面，**When** 使用者在設定中選擇「啟用翻譯」，**Then** 系統顯示語言對選項（英→中、中→英）
2. **Given** 翻譯功能已啟用，**When** 轉譯文字產生後，**Then** 翻譯文字在 5 秒內顯示於轉譯文字下方
3. **Given** 翻譯正在進行，**When** 使用者切換語言對設定，**Then** 後續翻譯使用新的語言對設定

---

### User Story 3 - 選擇運算模式 (Priority: P3)

使用者在 Web 介面設定中選擇使用 Server 端 GPU 運算或自己裝置的 OpenVINO 運算。

**Why this priority**: 提供彈性選項，讓使用者根據自己的需求和設備能力選擇最適合的運算模式。不影響基本功能運作。

**Independent Test**: 在 Web 介面設定中選擇「使用本地運算（OpenVINO）」，開始轉譯時模型在本地裝置運行；切換到「使用 Server GPU」，模型在 Server 端運行。

**Acceptance Scenarios**:

1. **Given** 使用者在 Web 介面設定頁面，**When** 使用者選擇「運算模式」，**Then** 系統顯示兩個選項：「Server GPU」和「本地運算（OpenVINO）」
2. **Given** 使用者選擇「Server GPU」模式，**When** 開始轉譯，**Then** 音訊串流到 Server，Server 使用 GPU 進行推論並回傳結果
3. **Given** 使用者選擇「本地運算」模式，**When** 開始轉譯，**Then** 系統下載 OpenVINO 模型到瀏覽器，在本地進行推論
4. **Given** 系統運行中，**When** Server GPU 不可用或離線，**Then** 系統自動提示使用者切換到本地運算模式

---

### User Story 4 - Docker 容器化部署 (Priority: P4)

IT 管理員使用 Docker Compose 一鍵部署整個系統到區域網路的 Server 上，包含 Web 服務、API 服務和 GPU 運算支援。

**Why this priority**: 簡化部署流程，但對最終使用者體驗沒有直接影響。可在功能開發完成後進行容器化打包。

**Independent Test**: 在 Ubuntu Server 上執行 `docker-compose up -d`，系統啟動後可透過瀏覽器存取服務。

**Acceptance Scenarios**:

1. **Given** Server 已安裝 Docker 和 NVIDIA Container Toolkit，**When** 管理員執行 `docker-compose up -d`，**Then** 所有服務容器啟動並正常運行
2. **Given** Docker 容器正在運行，**When** 使用者連線到 Server IP，**Then** Web 介面正常顯示
3. **Given** 容器正在運行，**When** 管理員執行 `docker-compose logs`，**Then** 系統顯示所有服務的運行日誌
4. **Given** 容器正在運行，**When** 管理員執行 `docker-compose down`，**Then** 所有服務正常停止並清理資源

---

### Edge Cases

- **網路中斷**：當使用者的網路連線中斷時，系統應保存已轉譯的內容，並在重新連線後提示使用者繼續或重新開始
- **麥克風權限拒絕**：當使用者拒絕瀏覽器的麥克風權限請求時，系統應顯示清楚的錯誤訊息和解決步驟
- **Server 運算資源耗盡**：當多個使用者同時使用且 Server GPU 資源不足時，系統應將新請求排隊或提示使用者稍後再試
- **OpenVINO 模型載入失敗**：當使用者選擇本地運算但模型下載或載入失敗時，系統應自動降級為 Server GPU 模式（若可用）
- **音訊串流延遲過高**：當網路延遲導致音訊串流品質下降時，系統應自動調整串流參數或提示使用者使用本地運算模式
- **瀏覽器相容性**：當使用者使用不支援 WebRTC 或 WebAudio API 的舊版瀏覽器時，系統應顯示瀏覽器升級建議

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: 系統必須提供 Web 介面，使用者可透過瀏覽器存取服務，無需安裝任何軟體
- **FR-002**: 系統必須支援在區域網路內訪問，不依賴外部網路連線
- **FR-003**: 系統必須能夠擷取使用者裝置的麥克風音訊並串流到 Server
- **FR-004**: 系統必須即時轉譯音訊為文字，延遲不超過 3 秒
- **FR-005**: 系統必須支援中文和英文的語音轉譯
- **FR-006**: 系統必須提供翻譯功能，支援英文→繁體中文和繁體中文→英文
- **FR-007**: 系統必須支援 GPU (CUDA) 運算模式，利用 Server 的 RTX 5060 顯卡
- **FR-008**: 系統必須支援 OpenVINO 本地運算模式，允許使用者使用自己裝置的算力
- **FR-009**: 系統必須在運算模式之間提供清楚的切換選項
- **FR-010**: 系統必須顯示即時的轉譯和翻譯結果於 Web 介面
- **FR-011**: 系統必須支援暫停、繼續和停止轉譯操作
- **FR-012**: 系統必須在停止後保存完整的轉譯記錄
- **FR-013**: 系統必須透過 Docker 容器化部署，包含所有必要的依賴和配置
- **FR-014**: 系統必須支援 NVIDIA Container Toolkit 以在 Docker 中使用 GPU
- **FR-015**: 系統必須提供清楚的錯誤訊息和使用者引導（繁體中文）
- **FR-016**: Web 介面必須使用輕量化技術，載入時間不超過 1 秒
- **FR-017**: 系統必須相容主流瀏覽器（Chrome、Edge、Firefox、Safari）的近兩年版本
- **FR-018**: 系統必須在 Server GPU 不可用時提供降級機制（如提示使用本地運算）
- **FR-019**: 系統必須記錄所有轉譯和翻譯操作的日誌供管理員查詢

### Key Entities

- **音訊串流 (Audio Stream)**: 使用者裝置麥克風擷取的音訊資料，以串流方式傳送到 Server。包含音訊格式（取樣率、位元深度）、時間戳記。
- **轉譯任務 (Transcription Task)**: 一次完整的語音轉譯工作階段，包含開始時間、結束時間、轉譯內容、使用的語言和運算模式。
- **翻譯結果 (Translation Result)**: 對轉譯文字的翻譯輸出，關聯到原始轉譯任務，包含來源語言、目標語言、翻譯內容。
- **運算模式配置 (Compute Mode Config)**: 使用者選擇的運算方式設定，包含模式類型（Server GPU / 本地 OpenVINO）、相關參數。
- **使用者會話 (User Session)**: 使用者的 Web 連線狀態，包含連線時間、裝置資訊、當前任務。

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 使用者可在任意裝置（Windows、macOS、Linux、平板、手機）上透過瀏覽器存取服務並完成轉譯任務
- **SC-002**: Web 介面載入時間不超過 1 秒（在區域網路環境下）
- **SC-003**: 語音轉譯延遲不超過 3 秒（從說話到文字顯示）
- **SC-004**: 翻譯結果在轉譯文字產生後 5 秒內顯示
- **SC-005**: 系統支援至少 5 個同時連線的使用者而不顯著降低效能（Server GPU 模式）
- **SC-006**: OpenVINO 本地運算模式可在無 Server 連線的情況下獨立運作
- **SC-007**: Docker 部署從執行命令到服務可用不超過 2 分鐘（首次啟動，模型已下載）
- **SC-008**: 95% 的主流瀏覽器版本（近兩年）可正常使用所有核心功能
- **SC-009**: 使用者在首次使用時可在 5 分鐘內完成第一次轉譯任務（包含權限設定）
- **SC-010**: 系統在 Server GPU 故障時可自動提示並引導使用者切換到本地運算模式

## Assumptions

- Server 已安裝 Ubuntu 20.04+ 或其他支援 Docker 的 Linux 發行版
- Server 已安裝 NVIDIA Driver 和 NVIDIA Container Toolkit
- Server 配備 RTX 5060 顯卡並可正常運作
- 使用者裝置和 Server 在同一區域網路內，網路延遲 < 50ms
- 使用者使用近兩年版本的主流瀏覽器（Chrome 90+、Edge 90+、Firefox 88+、Safari 14+）
- 使用者裝置已連接可用的麥克風
- AI 模型（Whisper、faster-whisper、翻譯模型）已預先下載並包含在 Docker Image 中
- 使用者熟悉基本的網頁操作（點擊按鈕、授權權限）
- 系統管理員熟悉基本的 Docker 和 Linux 指令
- 本地運算模式的使用者裝置具備足夠的計算能力（至少 8GB RAM、較新的 CPU）

## Dependencies

- **Whisper.cpp / faster-whisper**: 語音轉譯 AI 模型引擎
- **Ollama 或相容的 LLM Server**: 用於翻譯功能（或使用 Argos Translate 作為離線備援）
- **OpenVINO**: 本地運算模式的推論引擎
- **Docker 與 NVIDIA Container Toolkit**: 容器化部署和 GPU 支援
- **WebRTC / WebAudio API**: 瀏覽器端音訊擷取和串流
- **FastAPI**: 後端 Web 服務框架
- **現有的 remote_whisper_server.py**: 可能需要擴充或整合現有的 GPU 轉譯服務

## Out of Scope

- **使用者帳號系統**: 此版本不實作使用者註冊、登入、權限管理（區域網路內信任所有使用者）
- **音訊檔案上傳轉譯**: 此版本只專注於即時音訊串流，不支援上傳音訊檔案進行離線轉譯
- **講者辨識**: 此版本不實作多講者辨識功能（Speaker Diarization）
- **會議摘要**: 此版本不實作 AI 會議摘要功能
- **外部網路存取**: 此版本不實作 HTTPS、域名、外網穿透等功能
- **行動裝置 App**: 此版本只提供 Web 介面，不開發原生 iOS/Android App
- **語音合成 (TTS)**: 此版本不實作文字轉語音功能
- **多語言介面**: 此版本介面只提供繁體中文，不支援其他語言的 UI
- **進階配置選項**: 此版本不提供模型參數調整、音訊品質設定等進階選項
- **歷史記錄管理**: 此版本不實作轉譯記錄的搜尋、分類、匯出等管理功能

## Risks

- **瀏覽器相容性**: 不同瀏覽器對 WebRTC 和 WebAudio API 的支援程度不同，可能需要額外的相容性處理
- **OpenVINO 模型大小**: OpenVINO 模型可能較大，透過瀏覽器下載可能耗時較長或失敗
- **同時連線數限制**: Server GPU 資源有限，同時連線數過多時效能可能顯著下降
- **網路頻寬**: 音訊串流需要穩定的網路頻寬，網路不穩定時轉譯品質可能受影響
- **瀏覽器安全性政策**: 某些瀏覽器對麥克風權限和跨域請求有嚴格限制，可能影響功能使用
