# Tasks: Web 音訊串流轉譯介面

**Input**: Design documents from `/specs/001-web-streaming-interface/`  
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

**Tests**: Tests are OPTIONAL and not included in this task list as they were not explicitly requested in the specification.

## Format: `- [ ] [ID] [P?] [Story?] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3, US4)
- Include exact file paths in descriptions

---

## Phase 1: Setup (Project Initialization)

**Purpose**: 建立專案結構和基礎配置

- [ ] T001 Create webapp directory structure per plan.md (webapp/backend/src/, webapp/frontend/, data/)
- [ ] T002 Initialize Python project with requirements.txt in webapp/backend/ (FastAPI 0.104+, uvicorn 0.24+, faster-whisper 0.10+, websockets 12.0+, httpx, pydantic, python-multipart)
- [ ] T003 [P] Create .gitignore for webapp/ (add venv/, __pycache__/, data/, *.pyc, .env)
- [ ] T004 [P] Create data directory structure (data/sessions/, data/audio/, data/transcripts/, data/translations/, data/logs/)
- [ ] T005 [P] Create README.md in webapp/ with deployment instructions from quickstart.md

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [ ] T006 Create configuration management in webapp/backend/src/config.py (load from environment variables and YAML)
- [ ] T007 [P] Create Pydantic base models for Session in webapp/backend/src/models/session.py
- [ ] T008 [P] Create Pydantic base models for AudioStream in webapp/backend/src/models/audio_stream.py
- [ ] T009 [P] Create Pydantic base models for TranscriptionTask in webapp/backend/src/models/task.py
- [ ] T010 [P] Create Pydantic base models for TranslationResult in webapp/backend/src/models/translation.py
- [ ] T011 Create storage service for JSON file operations in webapp/backend/src/services/storage.py (save/load sessions, transcripts, translations)
- [ ] T012 [P] Setup FastAPI application with CORS middleware in webapp/backend/src/main.py
- [ ] T013 [P] Implement health check endpoint GET /api/v1/health per contracts/api.md in webapp/backend/src/api/health.py
- [ ] T014 [P] Implement system config endpoint GET /api/v1/config per contracts/api.md in webapp/backend/src/api/config.py
- [ ] T015 Create error handling middleware and exception handlers in webapp/backend/src/main.py
- [ ] T016 [P] Setup logging infrastructure in webapp/backend/src/config.py (log to data/logs/app.log and data/logs/error.log)

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - 透過瀏覽器存取即時轉譯服務 (Priority: P1) 🎯 MVP

**Goal**: 使用者可在任何裝置的瀏覽器中連線到 Server，開始音訊串流並即時看到語音轉譯為文字

**Independent Test**: 在任意裝置（如 Windows 筆電）上開啟瀏覽器，連線到 http://[server-ip]:8000，點擊「開始轉譯」，對麥克風說話，畫面應即時顯示轉譯文字

### Backend Implementation for User Story 1

- [ ] T017 [P] [US1] Implement audio processor service for WebM to WAV conversion in webapp/backend/src/services/audio_processor.py (use ffmpeg)
- [ ] T018 [P] [US1] Implement transcription service using faster-whisper in webapp/backend/src/services/transcription.py (model: large-v3-turbo, device: cuda)
- [ ] T019 [US1] Implement WebSocket connection handler in webapp/backend/src/api/websocket.py (handle connect, start, audio_chunk, stop per contracts/websocket.md)
- [ ] T020 [US1] Implement session management logic in webapp/backend/src/services/session_manager.py (create session, update status, save to data/sessions/)
- [ ] T021 [US1] Integrate audio processing pipeline in websocket.py (receive WebM chunks → convert to WAV → save to data/audio/)
- [ ] T022 [US1] Integrate transcription pipeline in websocket.py (WAV audio → faster-whisper → send transcription message)
- [ ] T023 [US1] Implement error handling for GPU unavailable in websocket.py (send error message per contracts/websocket.md)
- [ ] T024 [US1] Add session persistence (save transcripts to data/transcripts/ per data-model.md)

### Frontend Implementation for User Story 1

- [ ] T025 [P] [US1] Create HTML structure in webapp/frontend/index.html (header, transcription display area, control buttons)
- [ ] T026 [P] [US1] Create CSS styling in webapp/frontend/css/style.css (輕量化設計，responsive layout)
- [ ] T027 [P] [US1] Implement MediaRecorder audio capture in webapp/frontend/js/audio.js (capture microphone, encode to WebM, 1s chunks)
- [ ] T028 [P] [US1] Implement WebSocket client in webapp/frontend/js/websocket.js (connect, send/receive messages per contracts/websocket.md)
- [ ] T029 [US1] Implement main app logic in webapp/frontend/js/app.js (initialize components, handle UI events, coordinate audio + websocket)
- [ ] T030 [US1] Implement transcription display in webapp/frontend/js/transcription.js (show real-time transcription results, handle is_final flag)
- [ ] T031 [US1] Add error handling and user feedback in webapp/frontend/js/app.js (show error messages, handle connection failures)
- [ ] T032 [US1] Implement microphone permission request flow in webapp/frontend/js/audio.js (getUserMedia with error handling)

### API Endpoints for User Story 1

- [ ] T033 [P] [US1] Implement GET /api/v1/sessions/{session_id} per contracts/api.md in webapp/backend/src/api/sessions.py
- [ ] T034 [P] [US1] Implement GET /api/v1/sessions per contracts/api.md in webapp/backend/src/api/sessions.py (list with pagination)

**Checkpoint**: At this point, User Story 1 should be fully functional - users can transcribe audio in real-time via browser

---

## Phase 4: User Story 2 - 即時翻譯轉譯文字 (Priority: P2)

**Goal**: 使用者在轉譯過程中啟用翻譯功能，系統將轉譯出的文字即時翻譯為指定語言

**Independent Test**: 在 Web 介面啟動轉譯後，勾選「啟用翻譯」並選擇「英文→繁體中文」，對麥克風說英文，畫面應同時顯示英文轉譯和繁體中文翻譯

### Backend Implementation for User Story 2

- [ ] T035 [P] [US2] Implement Ollama translation service in webapp/backend/src/services/translation.py (HTTP API call to Ollama, model: qwen2.5:7b)
- [ ] T036 [P] [US2] Implement Argos Translate fallback in webapp/backend/src/services/translation.py (offline translation as backup)
- [ ] T037 [US2] Integrate translation pipeline in websocket.py (after transcription → translate → send translation message)
- [ ] T038 [US2] Add translation result persistence in websocket.py (save to data/translations/ per data-model.md)
- [ ] T039 [US2] Implement translation configuration in websocket.py start message handler (enable_translation, source_lang, target_lang)
- [ ] T040 [US2] Add translation error handling in websocket.py (Ollama timeout → fallback to Argos)

### Frontend Implementation for User Story 2

- [ ] T041 [P] [US2] Create translation settings UI in webapp/frontend/index.html (checkbox for enable translation, dropdown for language pairs)
- [ ] T042 [P] [US2] Implement translation display in webapp/frontend/js/translation.js (show translated text below transcription)
- [ ] T043 [US2] Update WebSocket start message in webapp/frontend/js/websocket.js (include translation config)
- [ ] T044 [US2] Add translation message handling in webapp/frontend/js/websocket.js (receive and display translation results)
- [ ] T045 [US2] Update main app logic in webapp/frontend/js/app.js (capture translation settings from UI)

**Checkpoint**: At this point, User Stories 1 AND 2 should both work - real-time transcription with optional translation

---

## Phase 5: User Story 3 - 選擇運算模式 (Priority: P3)

**Goal**: 使用者在 Web 介面設定中選擇使用 Server 端 GPU 運算或自己裝置的 OpenVINO 運算

**Independent Test**: 在 Web 介面設定中選擇「使用本地運算（OpenVINO）」，開始轉譯時模型在本地裝置運行；切換到「使用 Server GPU」，模型在 Server 端運行

**⚠️ NOTE**: 本地運算模式實作複雜度高（whisper.cpp WASM 整合），可視時間評估是否實作。優先確保 P1 和 P2 完成。

### Backend Implementation for User Story 3

- [ ] T046 [P] [US3] Update websocket.py to handle compute_mode parameter (validate and route based on server_gpu vs local_openvino)
- [ ] T047 [P] [US3] Add GPU availability check in webapp/backend/src/services/transcription.py (check CUDA, return error if unavailable)
- [ ] T048 [US3] Implement auto-fallback logic in websocket.py (if GPU unavailable → suggest local compute)

### Frontend Implementation for User Story 3

- [ ] T049 [P] [US3] Create compute mode selector UI in webapp/frontend/index.html (radio buttons: Server GPU / 本地運算)
- [ ] T050 [P] [US3] Implement OpenVINO WASM integration in webapp/frontend/js/openvino.js (load whisper.cpp WASM, download GGML model)
- [ ] T051 [US3] Implement local transcription in webapp/frontend/js/audio.js (if local mode → use OpenVINO WASM instead of WebSocket)
- [ ] T052 [US3] Update main app logic in webapp/frontend/js/app.js (switch between WebSocket and local processing based on compute mode)
- [ ] T053 [US3] Add model download progress UI in webapp/frontend/js/openvino.js (show download progress for GGML model)

**Checkpoint**: All three user stories should now work independently - transcription, translation, and compute mode selection

---

## Phase 6: User Story 4 - Docker 容器化部署 (Priority: P4)

**Goal**: IT 管理員使用 Docker Compose 一鍵部署整個系統到區域網路的 Server 上

**Independent Test**: 在 Ubuntu Server 上執行 `docker-compose up -d`，系統啟動後可透過瀏覽器存取服務

### Backend Docker Implementation

- [ ] T054 [US4] Create backend Dockerfile in webapp/backend/Dockerfile (base: nvidia/cuda:12.1.1-cudnn8-runtime-ubuntu22.04)
- [ ] T055 [US4] Add faster-whisper model download in Dockerfile (download large-v3-turbo to /models/ during build)
- [ ] T056 [US4] Configure CUDA environment in Dockerfile (NVIDIA_VISIBLE_DEVICES, CUDA_VISIBLE_DEVICES)
- [ ] T057 [US4] Add ffmpeg installation in Dockerfile (apt-get install ffmpeg)
- [ ] T058 [US4] Set working directory and entrypoint in Dockerfile (CMD: uvicorn main:app)

### Frontend Docker Implementation

- [ ] T059 [P] [US4] Create frontend Dockerfile in webapp/frontend/Dockerfile (base: nginx:alpine)
- [ ] T060 [P] [US4] Create nginx configuration in webapp/frontend/nginx.conf (serve static files, proxy /api and /ws to backend)
- [ ] T061 [US4] Copy frontend files to nginx in Dockerfile

### Docker Compose

- [ ] T062 [US4] Create docker-compose.yml in webapp/ (define backend and frontend services)
- [ ] T063 [US4] Configure backend service in docker-compose.yml (runtime: nvidia, volumes for data/, environment variables)
- [ ] T064 [US4] Configure frontend service in docker-compose.yml (nginx, port 8000, depends_on backend)
- [ ] T065 [US4] Add Ollama service to docker-compose.yml (optional external service for translation)
- [ ] T066 [US4] Create environment variable template .env.example in webapp/ (list all configurable variables)

### Additional Endpoints for User Story 4

- [ ] T067 [P] [US4] Implement DELETE /api/v1/sessions/{session_id} per contracts/api.md in webapp/backend/src/api/sessions.py (delete session data and files)
- [ ] T068 [P] [US4] Implement GET /api/v1/sessions/{session_id}/transcript per contracts/api.md in webapp/backend/src/api/sessions.py (download transcript in txt/json/srt format)
- [ ] T069 [P] [US4] Implement GET /api/v1/sessions/{session_id}/audio per contracts/api.md in webapp/backend/src/api/sessions.py (download audio file)

**Checkpoint**: Docker deployment complete - entire system can be deployed with one command

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories

- [ ] T070 [P] Add Ping/Pong mechanism in webapp/backend/src/api/websocket.py (implement ping/pong messages per contracts/websocket.md)
- [ ] T071 [P] Add reconnection support in webapp/backend/src/api/websocket.py (support reconnect message with session_id)
- [ ] T072 [P] Implement connection timeout in webapp/backend/src/api/websocket.py (30s no activity → auto disconnect)
- [ ] T073 [P] Add reconnection logic in webapp/frontend/js/websocket.js (retry connection with exponential backoff)
- [ ] T074 [P] Implement data cleanup script in webapp/backend/scripts/cleanup.py (delete old sessions based on retention_days from config)
- [ ] T075 [P] Add file size limit validation in webapp/backend/src/services/storage.py (enforce max_audio_size_mb from config)
- [ ] T076 [P] Add concurrent connection limit in webapp/backend/src/api/websocket.py (enforce max_connections from config)
- [ ] T077 [P] Optimize audio buffering in webapp/backend/src/services/audio_processor.py (batch process chunks to reduce disk I/O)
- [ ] T078 [P] Add loading states to UI in webapp/frontend/js/app.js (show spinner during connection, processing)
- [ ] T079 [P] Add browser compatibility check in webapp/frontend/js/app.js (check for MediaRecorder, WebSocket, getUserMedia support)
- [ ] T080 [P] Update README.md in webapp/ with complete deployment guide from quickstart.md
- [ ] T081 [P] Create configuration example file config.example.yaml in webapp/backend/ (show all config options from data-model.md)
- [ ] T082 Run quickstart.md validation (follow 5-minute deployment process and verify all steps work)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3-6)**: All depend on Foundational phase completion
  - User Story 1 (P1, Phase 3): Can start after Phase 2 - Core MVP
  - User Story 2 (P2, Phase 4): Can start after Phase 2 - Depends on US1 being complete for testing
  - User Story 3 (P3, Phase 5): Can start after Phase 2 - Independent but lower priority
  - User Story 4 (P4, Phase 6): Can start after Phase 2 - Independent deployment work
- **Polish (Phase 7)**: Depends on desired user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 2) - No dependencies on other stories
- **User Story 2 (P2)**: Can start after Foundational (Phase 2) - Builds on US1 transcription pipeline
- **User Story 3 (P3)**: Can start after Foundational (Phase 2) - Independent but complex (WASM)
- **User Story 4 (P4)**: Can start after Foundational (Phase 2) - Independent Docker packaging

### Within Each User Story

- Models before services (T007-T010 before T011, T017, T018)
- Services before API/WebSocket handlers (T017-T018 before T019-T024)
- Backend core before frontend (backend WebSocket before frontend client)
- Core implementation before UI polish

### Parallel Opportunities

**Phase 1 (Setup)**: T003, T004, T005 can run in parallel

**Phase 2 (Foundational)**: T007, T008, T009, T010, T012, T013, T014, T016 can run in parallel

**Within User Story 1**:
- T017, T018 (services) can run in parallel
- T025, T026, T027, T028 (frontend base) can run in parallel  
- T033, T034 (API endpoints) can run in parallel

**Within User Story 2**:
- T035, T036 (translation services) can run in parallel
- T041, T042 (frontend translation UI) can run in parallel

**Within User Story 3**:
- T046, T047 (backend compute mode) can run in parallel
- T049, T050 (frontend OpenVINO) can run in parallel

**Within User Story 4**:
- T054-T058 (backend Docker) and T059-T061 (frontend Docker) can run in parallel
- T067, T068, T069 (additional API endpoints) can run in parallel

**Phase 7 (Polish)**: Most tasks marked [P] can run in parallel (different concerns)

---

## Parallel Example: User Story 1 Backend

```bash
# Launch all User Story 1 backend services in parallel:
Task T017: "Implement audio processor service in webapp/backend/src/services/audio_processor.py"
Task T018: "Implement transcription service in webapp/backend/src/services/transcription.py"

# These can be developed simultaneously as they handle different concerns
```

## Parallel Example: User Story 1 Frontend

```bash
# Launch all User Story 1 frontend base components in parallel:
Task T025: "Create HTML structure in webapp/frontend/index.html"
Task T026: "Create CSS styling in webapp/frontend/css/style.css"
Task T027: "Implement MediaRecorder audio capture in webapp/frontend/js/audio.js"
Task T028: "Implement WebSocket client in webapp/frontend/js/websocket.js"

# These can be developed simultaneously as they touch different files
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001-T005)
2. Complete Phase 2: Foundational (T006-T016) **CRITICAL - blocks all stories**
3. Complete Phase 3: User Story 1 (T017-T034)
4. **STOP and VALIDATE**: Test User Story 1 independently
   - Open browser on any device
   - Connect to http://[server-ip]:8000
   - Click "開始轉譯" and speak into microphone
   - Verify transcription appears in real-time
5. Deploy/demo if ready - this is a working product!

### Incremental Delivery (Recommended)

1. Complete Setup + Foundational (Phase 1-2) → Foundation ready
2. Add User Story 1 (Phase 3) → Test independently → Deploy/Demo (MVP! 🎯)
3. Add User Story 2 (Phase 4) → Test independently → Deploy/Demo (Now with translation!)
4. *Optional*: Add User Story 3 (Phase 5) → Test independently → Deploy/Demo (Compute mode flexibility)
5. Add User Story 4 (Phase 6) → Test independently → Deploy/Demo (Easy Docker deployment)
6. Polish (Phase 7) → Final refinements

Each story adds value without breaking previous stories.

### Parallel Team Strategy

With multiple developers:

1. Team completes Setup + Foundational together (Phase 1-2)
2. Once Foundational is done:
   - **Developer A**: User Story 1 backend (T017-T024, T033-T034)
   - **Developer B**: User Story 1 frontend (T025-T032)
   - **Developer C**: User Story 4 Docker setup (T054-T069) - can work in parallel
3. After User Story 1 complete:
   - **Developer A**: User Story 2 backend (T035-T040)
   - **Developer B**: User Story 2 frontend (T041-T045)
   - **Developer C**: User Story 3 (T046-T053) or Polish tasks (T070-T082)

---

## Notes

- **[P] tasks** = different files, no dependencies - can run in parallel
- **[Story] label** = maps task to specific user story for traceability
- **Path conventions**: All paths follow plan.md structure (webapp/backend/, webapp/frontend/)
- **Tests**: Not included as they were not explicitly requested in specification
- **User Story 3 (P3)**: OpenVINO WASM integration is complex - consider deferring if time limited
- **MVP focus**: User Story 1 (P1) is the core MVP - prioritize completing this first
- **Commit strategy**: Commit after each task or logical group
- **Checkpoints**: Stop at each checkpoint to validate story independently before moving forward
- **Independent stories**: Each user story should be functional on its own once complete

---

## Task Count Summary

- **Phase 1 (Setup)**: 5 tasks
- **Phase 2 (Foundational)**: 11 tasks (BLOCKING)
- **Phase 3 (User Story 1 - P1 MVP)**: 18 tasks
- **Phase 4 (User Story 2 - P2)**: 11 tasks
- **Phase 5 (User Story 3 - P3)**: 8 tasks
- **Phase 6 (User Story 4 - P4)**: 16 tasks
- **Phase 7 (Polish)**: 13 tasks

**Total**: 82 tasks

**MVP Scope (P1 only)**: 34 tasks (Phase 1 + Phase 2 + Phase 3)

**Parallel opportunities identified**: 25+ tasks can run in parallel across different phases
