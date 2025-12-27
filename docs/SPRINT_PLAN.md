# SMARTCARE+ Sprint Plan

> Agile development roadmap for 3-person university team  
> **Timeline**: 4 Sprints × 1 Week = 4 Weeks (1 Month)  
> **Accelerator**: GenAI (GitHub Copilot Pro+) - 6x development speed  
> **UI Theme**: Dark Mode | Futuristic | Modern Glassmorphism  
> **Note**: Using pre-recorded videos as simulated live CCTV (university project constraint)

---

## Team Roster

| Member | Component | Primary Stack |
|--------|-----------|---------------|
| **Neelaka** | Physio Service | Python (MediaPipe, TensorFlow), Flutter |
| **Kulasekara** | Nutrition Service | Python (CNN, USDA API), Flutter |
| **Madhushani** | Guardian Service | Python (LSTM, Fall Detection), Flutter |

---

## Sprint Overview

```
┌────────────────────────────────────────────────────────────────────────┐
│                 SMARTCARE+ TIMELINE (1 MONTH - GenAI Accelerated)       │
├────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  WEEK 1 (Sprint 1): Foundation + Core Setup                             │
│  ═══════════════════════════════════════════                            │
│  [████████]                                                             │
│  - Project setup, Firebase, Auth, WebSocket, Dark Theme                 │
│  - Copilot generates boilerplate, schemas, base widgets                 │
│                                                                         │
│  WEEK 2 (Sprint 2): Core Features (Parallel Dev)                        │
│  ═══════════════════════════════════════════════                        │
│  [████████]                                                             │
│  - Each member builds main feature simultaneously                       │
│  - Copilot accelerates endpoint + widget generation                     │
│                                                                         │
│  WEEK 3 (Sprint 3): AI/ML + Advanced Features                           │
│  ═══════════════════════════════════════════════                        │
│  [████████]                                                             │
│  - ML model integration (pre-trained models)                            │
│  - Real-time video processing pipelines                                 │
│                                                                         │
│  WEEK 4 (Sprint 4): Integration + Polish + Demo                         │
│  ═══════════════════════════════════════════════                        │
│  [████████]                                                             │
│  - End-to-end testing, UI polish, documentation                         │
│  - Demo preparation                                                     │
│                                                                         │
└────────────────────────────────────────────────────────────────────────┘
```

---

## Week 1 (Sprint 1): Foundation + Core Setup
**Duration**: Days 1-7 | **Focus**: Infrastructure, Auth, Theme, WebSocket Base

> 🤖 **GenAI Acceleration**: Copilot generates boilerplate code, Firebase schemas, base widgets, and API scaffolding

### Day 1-2: Project Setup (All Team)

| Task | Backend | Frontend | Owner | Hours |
|------|---------|----------|-------|-------|
| Repository setup | Monorepo (`/backend`, `/frontend`), .gitignore | - | All | 2 |
| Firebase project | Console setup, service accounts, Firestore rules | - | Madhushani | 3 |
| FastAPI skeleton | Main app, routers, CORS, error handlers | - | Neelaka | 4 |
| Flutter skeleton | - | Project init, folder structure | Kulasekara | 4 |
| **Dark Futuristic Theme** | - | theme.dart with glassmorphism, neon accents | Kulasekara | 4 |

### Day 3-4: Authentication + Core Services

| Task | Type | Description | Owner | Hours |
|------|------|-------------|-------|-------|
| Firebase Auth | Backend | Token verification middleware | Madhushani | 4 |
| User endpoints | Backend | CRUD for users (elderly, caregiver, guardian) | Madhushani | 4 |
| Shared utilities | Backend | Logger, validators, response models | Neelaka | 3 |
| Login/Register screens | Frontend | Dark theme, neon buttons, glassmorphic cards | Kulasekara | 6 |
| Auth state management | Frontend | Firebase Auth + Riverpod | Madhushani | 4 |
| API service | Frontend | HTTP client with auth interceptor | Neelaka | 3 |

### Day 5-7: WebSocket + Dashboard Foundation

| Task | Type | Description | Owner | Hours |
|------|------|-------------|-------|-------|
| WebSocket manager | Backend | Base handler with auth, connection pool | Neelaka | 6 |
| Worker thread setup | Backend | ThreadPoolExecutor for video | Madhushani | 6 |
| FCM integration | Backend | Push notification sender | Madhushani | 3 |
| WebSocket service | Frontend | Connection manager with reconnection | Madhushani | 5 |
| Dashboard shell | Frontend | Bottom nav, dark theme, glow effects | All | 4 |
| Home screen placeholders | Frontend | Physio, Nutrition, Guardian cards | All | 4 |

**Sprint 1 Deliverables:**
- [ ] Monorepo with `/backend` and `/frontend` folders
- [ ] Dark futuristic theme with glassmorphism implemented
- [ ] Firebase Auth working (login/register)
- [ ] WebSocket connection works end-to-end
- [ ] Dashboard shell with bottom navigation

---

## Week 2 (Sprint 2): Core Features (Parallel Development)
**Duration**: Days 8-14 | **Focus**: Each member builds their main features simultaneously

> 🤖 **GenAI Acceleration**: Copilot generates endpoints, widgets, and data models from specs

### Neelaka (Physio Service) - All Week

| Day | Task | Type | Description | Hours |
|-----|------|------|-------------|-------|
| 8-9 | MediaPipe + Gait API | Backend | Setup MediaPipe, `POST /analyze-gait`, metrics calculator | 12 |
| 10 | TUG Test API | Backend | `POST /physio/tug-test`, fall risk scoring | 6 |
| 11 | Exercise endpoints | Backend | Exercise library CRUD, prescriptions | 6 |
| 12 | Camera stream widget | Frontend | Capture frames, WebSocket streaming | 6 |
| 13 | Pose overlay + Gait screen | Frontend | Skeleton overlay, real-time metrics display | 8 |
| 14 | TUG test screen | Frontend | Guided test with timer, dark neon UI | 6 |

### Kulasekara (Nutrition Service) - All Week

| Day | Task | Type | Description | Hours |
|-----|------|------|-------------|-------|
| 8-9 | USDA API + Food DB | Backend | FoodData Central integration, local cache | 10 |
| 10 | Meal logging API | Backend | `POST /log-meal`, daily/weekly summaries | 6 |
| 11 | Meal plan generator | Backend | RDA-based algorithm, dietary restrictions | 8 |
| 12 | Food scanner widget | Frontend | Camera capture, futuristic scan animation | 6 |
| 13 | Meal log + Plan screens | Frontend | Dark glassmorphic cards, neon accents | 8 |
| 14 | Nutrition dashboard | Frontend | Macro charts, hydration tracker | 6 |

### Madhushani (Guardian Service) - All Week

| Day | Task | Type | Description | Hours |
|-----|------|------|-------------|-------|
| 8-9 | Alert system | Backend | Alert CRUD, WebSocket push, SOS endpoint | 10 |
| 10 | Video stream WebSocket | Backend | `/ws/guardian/stream/{id}`, pre-recorded loader | 8 |
| 11 | Activity classifier | Backend | Basic activity detection (walking, sitting, lying) | 6 |
| 12 | Live feed widget | Frontend | WebSocket video display, dark theme | 6 |
| 13 | Alert cards + SOS | Frontend | Neon alert badges, glowing SOS button | 6 |
| 14 | Live monitor screen | Frontend | Full monitoring with activity overlay | 8 |

**Sprint 2 Deliverables:**
- [ ] Neelaka: Gait analysis + TUG test working end-to-end
- [ ] Kulasekara: Food logging + meal plans generated
- [ ] Madhushani: Live video stream + alerts working

---

## Week 3 (Sprint 3): AI/ML Integration + Advanced Features
**Duration**: Days 15-21 | **Focus**: Pre-trained models, real-time inference, remaining features

> 🤖 **GenAI Acceleration**: Using pre-trained models (MediaPipe, MobileNetV2) + Copilot for integration code
> ⚡ **Strategy**: Use transfer learning & pre-trained weights instead of training from scratch

### Neelaka (Physio ML Integration) - Days 15-18

| Day | Task | Type | Description | Hours |
|-----|------|------|-------------|-------|
| 15 | Pre-trained model setup | Backend | Load MediaPipe + scikit-learn fall risk classifier | 6 |
| 16 | Real-time inference | Backend | Worker thread inference, WebSocket streaming | 8 |
| 17 | Exercise library | Backend | Seed exercises, session logging | 4 |
| 17 | Progress reports | Backend | Historical data, PDF generation | 4 |
| 18 | Exercise screens | Frontend | Library + session with pose feedback | 8 |
| 18 | Progress charts | Frontend | Animated line charts, dark neon theme | 4 |

### Kulasekara (Nutrition ML Integration) - Days 15-18

| Day | Task | Type | Description | Hours |
|-----|------|------|-------------|-------|
| 15 | MobileNetV2 food model | Backend | Load pre-trained Food-101 model | 6 |
| 16 | `POST /analyze-food` | Backend | Image inference, confidence filtering | 6 |
| 16 | Food-medication check | Backend | Interaction warnings | 4 |
| 17 | AI scanner animation | Frontend | Futuristic scanning effect, particle effects | 6 |
| 18 | Results display | Frontend | Recognized foods, nutrition facts cards | 6 |
| 18 | Hydration tracking | Full | Backend + frontend hydration feature | 4 |

### Madhushani (Guardian ML Integration) - Days 15-18

| Day | Task | Type | Description | Hours |
|-----|------|------|-------------|-------|
| 15 | Fall detection LSTM | Backend | Load pre-trained fall detection model | 6 |
| 16 | Detection pipeline | Backend | Frame → Pose → LSTM → Alert (worker thread) | 8 |
| 17 | Geofence system | Backend | CRUD, breach detection | 6 |
| 17 | Geofence map widget | Frontend | Google Maps, draw/edit zones | 6 |
| 18 | Fall alert modal | Frontend | Full-screen alert, captured frame, vibration | 6 |
| 18 | Activity timeline | Frontend | Dark timeline widget with icons | 4 |

### Days 19-21: Performance Optimization (All Team)

| Task | Owner | Description | Hours |
|------|-------|-------------|-------|
| Thread pool tuning | Neelaka | Optimize workers, prevent memory leaks | 4 |
| Frame rate optimization | Madhushani | Skip frames, reduce FPS if needed | 4 |
| Pre-recorded video polish | Madhushani | Robust simulated CCTV system | 4 |
| Model warm-up | Kulasekara | Pre-load models on service start | 3 |
| Caching | Kulasekara | Cache food lookups, reduce API calls | 3 |
| Error recovery | All | WebSocket reconnection, graceful failures | 4 |

**Sprint 3 Deliverables:**
- [ ] All ML models running in real-time (pre-trained)
- [ ] Fall detection triggers alert within 500ms
- [ ] Food recognition working on camera capture
- [ ] Geofencing with breach alerts
- [ ] Progress reports and exercise library

---

## Week 4 (Sprint 4): Integration + Polish + Demo
**Duration**: Days 22-28 | **Focus**: Testing, UI polish, documentation, demo preparation

> 🤖 **GenAI Acceleration**: Copilot generates tests, documentation, and polish code

### Days 22-24: Integration Testing & Bug Fixes

| Task | Description | Owner | Hours |
|------|-------------|-------|-------|
| API integration testing | Test all endpoints together | All | 4 |
| User journey testing | Full elderly + caregiver flows | All | 4 |
| Firebase security rules | Lock down Firestore/Storage access | Madhushani | 3 |
| Error handling polish | Consistent error responses, user messages | Kulasekara | 3 |
| Bug fixes | Address critical issues found | All | 8 |
| Unit tests | Key backend services | All | 4 |
| Widget tests | Critical Flutter widgets | All | 3 |

### Days 25-26: UI Polish & Dark Theme Refinement

| Task | Description | Owner | Hours |
|------|-------------|-------|-------|
| Physio UI polish | Animations, neon glow effects, transitions | Neelaka | 6 |
| Nutrition UI polish | Chart animations, glassmorphic cards | Kulasekara | 6 |
| Guardian UI polish | Alert animations, live feed overlays | Madhushani | 6 |
| Loading states | Skeleton loaders, shimmer effects | All | 3 |
| Error states | Empty states, retry buttons | All | 2 |
| Responsive adjustments | Tablet support, different screen sizes | All | 3 |

### Days 27-28: Documentation & Demo Prep

| Task | Description | Owner | Hours |
|------|-------------|-------|-------|
| API documentation | Swagger/OpenAPI auto-generated | Neelaka | 2 |
| README files | Setup instructions for backend/frontend | All | 2 |
| Demo videos recording | Record app walkthrough videos | Madhushani | 4 |
| Pre-recorded CCTV videos | Prepare simulated camera footage | Madhushani | 3 |
| Presentation slides | University project presentation | All | 4 |
| Demo environment | Cloud deployment, test devices | Neelaka | 4 |
| Final testing | End-to-end demo rehearsal | All | 3 |

**Sprint 4 Deliverables:**
- [ ] All features integrated and working
- [ ] Dark futuristic UI polished with animations
- [ ] Documentation complete
- [ ] Demo ready for university presentation
- [ ] Pre-recorded videos prepared for simulated CCTV

---

## Time Allocation Summary

| Week | Focus | Hours/Person | Total Team Hours |
|------|-------|--------------|------------------|
| Week 1 (Sprint 1) | Foundation + Core | ~45 | ~135 |
| Week 2 (Sprint 2) | Core Features | ~45 | ~135 |
| Week 3 (Sprint 3) | AI/ML + Advanced | ~45 | ~135 |
| Week 4 (Sprint 4) | Integration + Demo | ~40 | ~120 |
| **Total** | - | **~175** | **~525** |

> ⚡ **GenAI Multiplier**: With Copilot Pro+, expect 3-6x faster code generation, reducing manual coding time by ~60%

---

## Risk Management

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| ML model accuracy too low | Medium | High | Start training early, use transfer learning |
| WebSocket performance issues | Medium | High | Dedicated sprint for optimization |
| Firebase costs exceed budget | Low | Medium | Monitor usage, use emulators for dev |
| Team member unavailable | Medium | Medium | Cross-training, documentation |
| Pre-recorded video not realistic | Low | Low | Use multiple scenarios, angles |

---

## Definition of Done

A feature is "Done" when:

- [ ] Code is complete and follows style guide
- [ ] Unit tests written and passing
- [ ] Code reviewed by another team member
- [ ] API endpoint documented (if backend)
- [ ] Works on both Android emulator and physical device (if frontend)
- [ ] No critical bugs
- [ ] Merged to `main` branch

---

## Sprint Ceremonies (1-Week Sprints)

| Ceremony | Frequency | Duration | Participants |
|----------|-----------|----------|--------------|
| Sprint Planning | Monday morning | 1 hour | All |
| Daily Standup | Daily | 15 min | All |
| Code Review | Ongoing (PR-based) | - | Pairs |
| Sprint Review | Friday | 30 min | All + Supervisor |
| Quick Retro | Friday | 15 min | All |

---

## Communication Tools

| Tool | Purpose |
|------|---------|
| GitHub | Code repository, Issues, PRs |
| Discord/Slack | Daily communication |
| Trello/Notion | Sprint board, backlog |
| Google Meet | Sprint ceremonies (if remote) |
| WhatsApp | Quick messages |

---

## Milestones Summary

| Milestone | Sprint | Date | Deliverable |
|-----------|--------|------|-------------|
| M1: Foundation Complete | 1 | Day 7 | Auth, WebSocket, dark theme, dashboards |
| M2: Core Features | 2 | Day 14 | All main features working |
| M3: ML Integrated | 3 | Day 21 | Real-time AI with pre-trained models |
| M4: Demo Ready | 4 | Day 28 | Final polished product for presentation |

---

## GenAI (Copilot Pro+) Usage Strategy

| Use Case | How Copilot Helps | Time Saved |
|----------|-------------------|------------|
| Boilerplate code | Generate FastAPI endpoints, Flutter widgets | 70% |
| Data models | Pydantic schemas, Firestore models | 80% |
| Tests | Unit tests, widget tests generation | 60% |
| Documentation | README, API docs, comments | 75% |
| UI Components | Dark theme widgets, animations | 50% |
| Error handling | Try-catch patterns, validation | 65% |

---

> **Note on Pre-recorded Videos**: Since this is a university project, live CCTV integration is simulated using pre-recorded videos stored in Firebase Storage. The system is designed to easily swap in live camera feeds in a production environment by changing the video source in the Guardian service.
