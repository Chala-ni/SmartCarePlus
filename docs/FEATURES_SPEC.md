# SMARTCARE+ Feature Specifications

> Detailed breakdown of Backend Endpoints (FastAPI) and Frontend Widgets (Flutter) by Team Member  
> **Critical**: Physio & Guardian components utilize WebSocket + Worker Threads for video streaming

---

## Table of Contents

1. [Neelaka - Physio Service](#1-neelaka---physio-service-physiotherapy--mobility-analysis)
2. [Kulasekara - Nutrition Service](#2-kulasekara---nutrition-service-dietary-management--meal-planning)
3. [Madhushani - Guardian Service](#3-madhushani---guardian-service-real-time-safety-monitoring)
4. [Shared Components](#4-shared-components)
5. [WebSocket Protocol Specification](#5-websocket-protocol-specification)

---

## 1. Neelaka - Physio Service (Physiotherapy & Mobility Analysis)

### Overview

AI-powered physiotherapy monitoring system for elderly mobility assessment, fall risk prediction, and exercise compliance tracking. Uses **MediaPipe Pose** for skeletal tracking and **TensorFlow/Scikit-learn** for gait analysis.

### 1.1 Backend Endpoints (FastAPI)

#### REST API Endpoints

| Method | Endpoint | Description | Request Body | Response |
|--------|----------|-------------|--------------|----------|
| `POST` | `/api/physio/analyze-gait` | Analyze gait from uploaded video | `multipart/form-data: video file` | Gait metrics JSON |
| `POST` | `/api/physio/tug-test` | Process TUG (Timed Up and Go) test video | `multipart/form-data: video file` | TUG score, time, analysis |
| `POST` | `/api/physio/balance-assessment` | Analyze balance from stance video | `multipart/form-data: video file` | Balance score, sway metrics |
| `POST` | `/api/physio/rom-analysis` | Range of Motion analysis | `multipart/form-data: video file, joint: string` | ROM degrees, flexibility score |
| `GET` | `/api/physio/exercises` | Get exercise library | Query: `category`, `difficulty` | Exercise list |
| `GET` | `/api/physio/exercises/{user_id}` | Get prescribed exercises for user | - | Personalized exercise plan |
| `POST` | `/api/physio/exercise-session` | Log completed exercise session | `{user_id, exercise_id, duration, reps}` | Session record |
| `GET` | `/api/physio/progress/{user_id}` | Get physiotherapy progress over time | Query: `start_date`, `end_date` | Progress metrics, charts data |
| `GET` | `/api/physio/fall-risk/{user_id}` | Get current fall risk score | - | Risk score (0-100), factors |
| `GET` | `/api/physio/reports/{user_id}` | Generate PDF progress report | Query: `period` | PDF download / report JSON |
| `POST` | `/api/physio/prescribe` | Caregiver prescribes exercises | `{user_id, exercises[], notes}` | Prescription record |

#### WebSocket Endpoint (Real-time Video Analysis) ⚠️ CRITICAL

| Endpoint | Description | Protocol |
|----------|-------------|----------|
| `WS /ws/physio/stream/{user_id}` | Real-time video stream for gait analysis | WebSocket + Worker Threads |

**WebSocket Message Types:**

```typescript
// Client → Server
interface PhysioFrameMessage {
  type: "FRAME";
  data: string;          // Base64 encoded frame
  timestamp: number;     // Unix timestamp ms
  frameId: number;       // Sequential frame ID
}

interface PhysioControlMessage {
  type: "START_ANALYSIS" | "STOP_ANALYSIS" | "START_TUG_TEST";
  analysisType: "gait" | "balance" | "tug" | "rom";
}

// Server → Client
interface PoseResultMessage {
  type: "POSE_RESULT";
  frameId: number;
  landmarks: PoseLandmark[];   // 33 MediaPipe landmarks
  confidence: number;
}

interface GaitMetricsMessage {
  type: "GAIT_METRICS";
  strideLength: number;        // cm
  cadence: number;             // steps/min
  speed: number;               // m/s
  symmetryIndex: number;       // 0-1
  hipAngle: number;            // degrees
  kneeAngle: number;           // degrees
}

interface TUGResultMessage {
  type: "TUG_RESULT";
  totalTime: number;           // seconds
  sitToStandTime: number;
  walkTime: number;
  turnTime: number;
  standToSitTime: number;
  riskCategory: "low" | "moderate" | "high";
}
```

**Worker Thread Architecture:**

```
┌─────────────────────────────────────────────────────────────┐
│                 PHYSIO VIDEO PROCESSING                      │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  WebSocket Handler (async, non-blocking)                     │
│  └── Receives frames at 15-30 FPS                           │
│      │                                                       │
│      ▼                                                       │
│  Frame Queue (ThreadPoolExecutor)                            │
│  └── Distributes to worker threads                          │
│      │                                                       │
│      ├──► Thread 1: MediaPipe Pose Estimation               │
│      │    └── Extracts 33 body landmarks                    │
│      │                                                       │
│      ├──► Thread 2: Gait Metrics Calculator                 │
│      │    └── Stride, cadence, speed from landmarks         │
│      │                                                       │
│      └──► Thread 3: Fall Risk Inference (TensorFlow)        │
│           └── LSTM model predicts risk score                │
│                                                              │
│  Results aggregated → Sent back via WebSocket                │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

### 1.2 Frontend Widgets (Flutter)

#### Screens

| Screen | File | Description |
|--------|------|-------------|
| `PhysioHomeScreen` | `physio_home_screen.dart` | Dashboard with recent sessions, risk score, quick actions |
| `GaitAnalysisScreen` | `gait_analysis_screen.dart` | Live camera gait analysis with real-time feedback |
| `TUGTestScreen` | `tug_test_screen.dart` | Guided TUG test with timer and instructions |
| `ExerciseLibraryScreen` | `exercise_library_screen.dart` | Browse prescribed and general exercises |
| `ExerciseSessionScreen` | `exercise_session_screen.dart` | Active exercise with pose guidance |
| `PhysioReportScreen` | `physio_report_screen.dart` | View/export progress reports |

#### Custom Widgets

| Widget | File | Props | Description |
|--------|------|-------|-------------|
| `CameraStreamWidget` | `camera_stream_widget.dart` | `onFrame`, `analysisType`, `wsEndpoint` | **WebSocket** video capture & streaming to backend |
| `PoseOverlayWidget` | `pose_overlay_widget.dart` | `landmarks`, `connections`, `highlightJoints` | Draws MediaPipe skeleton on camera preview |
| `GaitMetricsCard` | `gait_metrics_card.dart` | `strideLength`, `cadence`, `speed`, `symmetry` | Real-time gait metrics display |
| `FallRiskIndicator` | `fall_risk_indicator.dart` | `riskScore`, `riskLevel`, `factors` | Circular gauge showing fall risk (0-100) |
| `ExerciseCard` | `exercise_card.dart` | `exercise`, `onStart`, `onDetails` | Exercise tile with thumbnail, duration, difficulty |
| `ProgressChart` | `progress_chart.dart` | `dataPoints`, `metricType`, `dateRange` | Line/bar chart for progress visualization |
| `TUGTimerWidget` | `tug_timer_widget.dart` | `onComplete`, `autoDetect` | Timer with phase detection for TUG test |
| `JointAngleDisplay` | `joint_angle_display.dart` | `jointName`, `currentAngle`, `targetAngle` | Real-time joint angle feedback |

#### Widget Hierarchy (Gait Analysis Screen)

```
GaitAnalysisScreen
├── AppBar (title: "Gait Analysis")
├── Stack
│   ├── CameraStreamWidget          ← WebSocket connection
│   │   └── connects to: /ws/physio/stream/{userId}
│   └── PoseOverlayWidget           ← Skeleton overlay
│       └── receives: landmarks from WebSocket
├── Positioned (bottom panel)
│   └── GaitMetricsCard             ← Real-time metrics
│       ├── strideLength
│       ├── cadence  
│       ├── speed
│       └── symmetryIndex
└── FloatingActionButton
    └── Start/Stop Analysis
```

---

## 2. Kulasekara - Nutrition Service (Dietary Management & Meal Planning)

### Overview

Intelligent nutrition tracking and meal planning system for elderly dietary needs. Uses **CNN (MobileNetV2)** for food recognition and **USDA FoodData Central** database for nutritional information. Generates personalized meal plans based on medical conditions and RDA requirements.

### 2.1 Backend Endpoints (FastAPI)

#### REST API Endpoints

| Method | Endpoint | Description | Request Body | Response |
|--------|----------|-------------|--------------|----------|
| `POST` | `/api/nutrition/analyze-food` | Recognize food from image | `multipart/form-data: image` | Food items, nutrients |
| `GET` | `/api/nutrition/food/{food_id}` | Get detailed nutrition data | - | USDA nutrition facts |
| `GET` | `/api/nutrition/search` | Search food database | Query: `query`, `limit` | Food search results |
| `POST` | `/api/nutrition/log-meal` | Log a meal entry | `{user_id, foods[], meal_type, portion_sizes[]}` | Meal log record |
| `GET` | `/api/nutrition/daily-summary/{user_id}` | Get daily nutrient intake | Query: `date` | Calories, macros, micros |
| `GET` | `/api/nutrition/weekly-summary/{user_id}` | Get weekly nutrition summary | Query: `week_start` | Aggregated weekly data |
| `GET` | `/api/nutrition/meal-plan/{user_id}` | Get current meal plan | Query: `date` | Daily meal plan |
| `POST` | `/api/nutrition/generate-plan` | Generate personalized meal plan | `{user_id, duration_days, preferences}` | Generated meal plan |
| `GET` | `/api/nutrition/restrictions/{user_id}` | Get user dietary restrictions | - | Restrictions, allergies |
| `PUT` | `/api/nutrition/restrictions/{user_id}` | Update dietary restrictions | `{restrictions[], allergies[], conditions[]}` | Updated restrictions |
| `POST` | `/api/nutrition/hydration/log` | Log water/fluid intake | `{user_id, amount_ml, beverage_type}` | Hydration log |
| `GET` | `/api/nutrition/hydration/{user_id}` | Get daily hydration data | Query: `date` | Hydration summary |
| `GET` | `/api/nutrition/interactions/{user_id}` | Check food-medication interactions | Query: `food_ids[]` | Interaction warnings |
| `GET` | `/api/nutrition/reports/weekly/{user_id}` | Generate weekly nutrition report | - | Report data / PDF |
| `GET` | `/api/nutrition/recommendations/{user_id}` | Get AI diet recommendations | - | Personalized suggestions |

#### Data Models

```python
# Pydantic Schemas

class FoodItem(BaseModel):
    food_id: str
    name: str
    brand: Optional[str]
    serving_size: float
    serving_unit: str
    calories: float
    protein: float
    carbohydrates: float
    fat: float
    fiber: float
    sodium: float
    vitamins: Dict[str, float]
    minerals: Dict[str, float]

class MealLog(BaseModel):
    user_id: str
    meal_type: Literal["breakfast", "lunch", "dinner", "snack"]
    foods: List[FoodItem]
    portion_multipliers: List[float]
    logged_at: datetime
    notes: Optional[str]

class MealPlan(BaseModel):
    user_id: str
    date: date
    meals: Dict[str, List[FoodItem]]  # breakfast, lunch, dinner, snacks
    total_calories: float
    total_protein: float
    total_carbs: float
    total_fat: float
    rda_coverage: Dict[str, float]  # nutrient -> % of RDA

class DietaryRestrictions(BaseModel):
    user_id: str
    allergies: List[str]              # e.g., ["peanuts", "shellfish"]
    intolerances: List[str]           # e.g., ["lactose", "gluten"]
    medical_conditions: List[str]     # e.g., ["diabetes", "hypertension"]
    dietary_preferences: List[str]    # e.g., ["vegetarian", "low-sodium"]
    avoid_foods: List[str]            # specific foods to avoid
```

---

### 2.2 Frontend Widgets (Flutter)

#### Screens

| Screen | File | Description |
|--------|------|-------------|
| `NutritionHomeScreen` | `nutrition_home_screen.dart` | Dashboard with today's intake, goals, quick log |
| `FoodScannerScreen` | `food_scanner_screen.dart` | Camera food recognition with AI |
| `MealLogScreen` | `meal_log_screen.dart` | View/edit meal history |
| `MealPlanScreen` | `meal_plan_screen.dart` | View weekly meal plan with recipes |
| `HydrationScreen` | `hydration_screen.dart` | Track daily water intake |
| `NutritionReportScreen` | `nutrition_report_screen.dart` | Weekly/monthly nutrition analysis |
| `DietaryRestrictionsScreen` | `dietary_restrictions_screen.dart` | Manage allergies, conditions |

#### Custom Widgets

| Widget | File | Props | Description |
|--------|------|-------|-------------|
| `FoodScannerWidget` | `food_scanner_widget.dart` | `onFoodDetected`, `showConfidence` | Camera-based food recognition |
| `NutritionFactsCard` | `nutrition_facts_card.dart` | `foodItem`, `servingSize` | FDA-style nutrition label |
| `MealCard` | `meal_card.dart` | `meal`, `onEdit`, `onDelete` | Meal entry with foods, calories |
| `DietCardWidget` | `diet_card_widget.dart` | `mealPlan`, `onSwap` | Daily meal plan card with swap option |
| `HydrationTracker` | `hydration_tracker.dart` | `current`, `goal`, `onAdd` | Water intake progress with quick-add |
| `MacroPieChart` | `macro_pie_chart.dart` | `protein`, `carbs`, `fat` | Macronutrient distribution pie chart |
| `CalorieProgress` | `calorie_progress.dart` | `consumed`, `goal`, `burned` | Circular calorie budget indicator |
| `NutrientBar` | `nutrient_bar.dart` | `nutrient`, `value`, `rda`, `unit` | Single nutrient progress bar |
| `FoodSearchWidget` | `food_search_widget.dart` | `onSelect`, `recentFoods` | Searchable food database |
| `PortionSelector` | `portion_selector.dart` | `servingSize`, `onChanged` | Adjust portion size slider |
| `InteractionWarning` | `interaction_warning.dart` | `interactions` | Food-medication interaction alert |

#### Widget Hierarchy (Food Scanner Screen)

```
FoodScannerScreen
├── AppBar (title: "Scan Food")
├── Stack
│   ├── CameraPreview
│   │   └── FoodScannerWidget
│   │       └── onFoodDetected: (foods) => showResults()
│   └── AnimatedContainer (results overlay)
│       └── FoodResultsSheet
│           ├── ListView
│           │   └── FoodItem tiles with confidence %
│           └── Button: "Add to Meal Log"
├── BottomSheet (when food selected)
│   ├── NutritionFactsCard
│   ├── PortionSelector
│   └── Button: "Log This Food"
└── FloatingActionButton
    └── Manual food search
```

---

## 3. Madhushani - Guardian Service (Real-time Safety Monitoring)

### Overview

Real-time elderly safety monitoring system with fall detection, activity recognition, and emergency alerts. Uses **MediaPipe Pose** combined with **LSTM neural networks** for fall detection, and provides live video streaming to caregivers via **WebSocket**. 

> ⚠️ **Note**: For university demonstration, uses pre-recorded videos simulating live CCTV feeds.

### 3.1 Backend Endpoints (FastAPI)

#### REST API Endpoints

| Method | Endpoint | Description | Request Body | Response |
|--------|----------|-------------|--------------|----------|
| `POST` | `/api/guardian/register-device` | Register monitoring device | `{device_id, device_type, elderly_id}` | Device record |
| `GET` | `/api/guardian/elderly/{elderly_id}/status` | Get current status | - | Status (active, inactive, alert) |
| `GET` | `/api/guardian/elderly/{elderly_id}/location` | Get current location | - | GPS coordinates, zone |
| `GET` | `/api/guardian/elderly/{elderly_id}/vitals` | Get latest vital signs | - | Heart rate, SpO2, etc. |
| `POST` | `/api/guardian/fall-alert` | Report fall detection event | `{elderly_id, confidence, fall_type, location}` | Alert record |
| `POST` | `/api/guardian/sos` | Trigger SOS emergency | `{elderly_id, location, message}` | SOS acknowledgment |
| `GET` | `/api/guardian/alerts/{guardian_id}` | Get all alerts for guardian | Query: `status`, `priority`, `limit` | Alert list |
| `PUT` | `/api/guardian/alerts/{alert_id}/acknowledge` | Acknowledge an alert | `{response_action, notes}` | Updated alert |
| `GET` | `/api/guardian/alerts/{alert_id}` | Get alert details | - | Full alert info |
| `POST` | `/api/guardian/geofence` | Create geofence zone | `{elderly_id, name, coordinates[], radius}` | Geofence record |
| `GET` | `/api/guardian/geofence/{elderly_id}` | Get user's geofences | - | Geofence list |
| `DELETE` | `/api/guardian/geofence/{geofence_id}` | Delete geofence | - | Success message |
| `GET` | `/api/guardian/activity-log/{elderly_id}` | Get activity history | Query: `start`, `end`, `activity_type` | Activity list |
| `GET` | `/api/guardian/anomalies/{elderly_id}` | Get detected anomalies | Query: `date_range` | Anomaly list |
| `POST` | `/api/guardian/settings` | Configure alert thresholds | `{elderly_id, fall_sensitivity, inactivity_threshold}` | Updated settings |
| `GET` | `/api/guardian/reports/daily/{elderly_id}` | Daily safety report | Query: `date` | Report data |

#### WebSocket Endpoints (Real-time Monitoring) ⚠️ CRITICAL

| Endpoint | Description | Protocol |
|----------|-------------|----------|
| `WS /ws/guardian/stream/{elderly_id}` | Live video monitoring stream | WebSocket + Worker Threads |
| `WS /ws/guardian/alerts/{guardian_id}` | Real-time alert notifications | WebSocket |

**WebSocket Message Types:**

```typescript
// === VIDEO STREAM (Guardian watching Elderly) ===

// Client → Server
interface VideoStreamRequest {
  type: "START_STREAM" | "STOP_STREAM";
  quality: "low" | "medium" | "high";
  elderlyId: string;
}

// Server → Client
interface VideoFrameMessage {
  type: "VIDEO_FRAME";
  elderlyId: string;
  frame: string;           // Base64 JPEG
  timestamp: number;
  analysisOverlay?: {
    pose: PoseLandmark[];
    activity: string;
    confidence: number;
  };
}

// === FALL DETECTION (Processing Pipeline) ===

// Server → Client (Alert Channel)
interface FallAlertMessage {
  type: "FALL_ALERT";
  priority: "CRITICAL";
  elderlyId: string;
  timestamp: number;
  data: {
    confidence: number;        // 0.0 - 1.0
    fallType: "forward" | "backward" | "sideways" | "collapse";
    location: { lat: number; lng: number };
    frameCapture: string;      // Base64 image at fall moment
    responseRequired: boolean;
  };
}

// === ACTIVITY MONITORING ===

interface ActivityChangeMessage {
  type: "ACTIVITY_CHANGE";
  elderlyId: string;
  timestamp: number;
  previousActivity: string;
  currentActivity: string;    // walking, sitting, lying, standing
  duration: number;           // time in previous activity (seconds)
}

interface InactivityWarningMessage {
  type: "INACTIVITY_WARNING";
  priority: "HIGH";
  elderlyId: string;
  inactiveDuration: number;   // seconds
  lastActivity: string;
  lastLocation: { lat: number; lng: number };
}

// === GEOFENCE ===

interface GeofenceBreachMessage {
  type: "GEOFENCE_BREACH";
  priority: "HIGH";
  elderlyId: string;
  geofenceId: string;
  geofenceName: string;
  breachType: "EXIT" | "ENTER";
  location: { lat: number; lng: number };
}

// === SOS ===

interface SOSMessage {
  type: "SOS_TRIGGERED";
  priority: "CRITICAL";
  elderlyId: string;
  timestamp: number;
  location: { lat: number; lng: number };
  triggerMethod: "button" | "voice" | "auto";
}
```

**Worker Thread Architecture (Fall Detection):**

```
┌─────────────────────────────────────────────────────────────┐
│               GUARDIAN FALL DETECTION PIPELINE               │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Video Source (Pre-recorded / Simulated CCTV)                │
│  └── Frames streamed at 15 FPS                              │
│      │                                                       │
│      ▼                                                       │
│  WebSocket Handler (async I/O, non-blocking)                 │
│  └── Receives/sends frames to/from Flutter app              │
│      │                                                       │
│      ▼                                                       │
│  Worker Thread Pool (ThreadPoolExecutor)                     │
│  ├──► Thread 1: Pose Estimation (MediaPipe)                 │
│  │    └── Extract 33 landmarks, calculate velocities        │
│  │        │                                                  │
│  │        ▼                                                  │
│  ├──► Thread 2: Fall Detection Model (LSTM)                 │
│  │    └── Input: 30-frame landmark sequence                 │
│  │    └── Output: {is_fall, confidence, fall_type}          │
│  │        │                                                  │
│  │        ▼ (if fall detected)                              │
│  │    Alert Manager                                          │
│  │    └── Push to Alert WebSocket                           │
│  │    └── Store in Firestore                                │
│  │    └── Send FCM Push Notification                        │
│  │                                                           │
│  └──► Thread 3: Activity Classification                     │
│       └── Classify: walking, sitting, lying, standing       │
│       └── Detect inactivity anomalies                       │
│                                                              │
│  Results sent back via WebSocket (< 100ms latency target)    │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

### 3.2 Frontend Widgets (Flutter)

#### Screens

| Screen | File | Description |
|--------|------|-------------|
| `GuardianHomeScreen` | `guardian_home_screen.dart` | Dashboard with elderly status cards, recent alerts |
| `LiveMonitorScreen` | `live_monitor_screen.dart` | Real-time video monitoring with activity overlay |
| `AlertsScreen` | `alerts_screen.dart` | Alert history with filtering and response actions |
| `ActivityLogScreen` | `activity_log_screen.dart` | Timeline of daily activities |
| `GeofenceScreen` | `geofence_screen.dart` | Map-based geofence management |
| `EmergencyScreen` | `emergency_screen.dart` | Emergency contact, SOS response view |
| `ElderlyProfileScreen` | `elderly_profile_screen.dart` | Elderly person's profile, settings, devices |

#### Custom Widgets

| Widget | File | Props | Description |
|--------|------|-------|-------------|
| `LiveFeedWidget` | `live_feed_widget.dart` | `elderlyId`, `wsEndpoint`, `showOverlay` | **WebSocket** live video stream from monitoring source |
| `AlertCard` | `alert_card.dart` | `alert`, `onAcknowledge`, `onExpand` | Alert tile with priority, timestamp, actions |
| `SOSButton` | `sos_button.dart` | `onTrigger`, `confirmationRequired` | Large emergency SOS button |
| `ActivityTimeline` | `activity_timeline.dart` | `activities`, `date` | Vertical timeline of daily activities |
| `LocationMapWidget` | `location_map_widget.dart` | `location`, `geofences`, `trackHistory` | Google Map with location & geofences |
| `VitalSignsCard` | `vital_signs_card.dart` | `heartRate`, `spO2`, `lastUpdated` | Vital signs display (from wearable) |
| `StatusIndicator` | `status_indicator.dart` | `status`, `activity`, `lastSeen` | Elderly current status badge |
| `FallAlertModal` | `fall_alert_modal.dart` | `alert`, `onRespond`, `onDismiss` | Full-screen fall alert with video capture |
| `GeofenceEditor` | `geofence_editor.dart` | `onSave`, `existingGeofence` | Draw/edit geofence on map |
| `InactivityWarning` | `inactivity_warning.dart` | `duration`, `lastActivity` | Inactivity alert banner |

#### Widget Hierarchy (Live Monitor Screen)

```
LiveMonitorScreen
├── AppBar
│   ├── title: "Live Monitoring - {ElderlyName}"
│   └── actions: [FullscreenButton, SettingsButton]
├── Column
│   ├── Expanded (video section)
│   │   └── Stack
│   │       ├── LiveFeedWidget              ← WebSocket video stream
│   │       │   └── connects to: /ws/guardian/stream/{elderlyId}
│   │       ├── Positioned (top-left)
│   │       │   └── StatusIndicator         ← Current activity
│   │       ├── Positioned (top-right)
│   │       │   └── RecordButton            ← Save clip
│   │       └── Positioned (bottom)
│   │           └── ActivityBar             ← Walking, Sitting, etc.
│   │
│   ├── Container (info panel)
│   │   ├── Row
│   │   │   ├── VitalSignsCard (heart rate)
│   │   │   └── VitalSignsCard (SpO2)
│   │   └── LocationMapWidget (mini map)
│   │
│   └── Container (recent alerts)
│       └── ListView.horizontal
│           └── AlertCard (last 5 alerts)
│
└── FloatingActionButton
    └── SOSButton (manual emergency trigger)
```

---

## 4. Shared Components

### 4.1 Backend Shared (`/api/shared/`)

| Module | Description |
|--------|-------------|
| `firebase_client.py` | Firebase Admin SDK initialization, Firestore/Auth operations |
| `storage.py` | Firebase Storage for video uploads, image storage |
| `notifications.py` | FCM push notification sender |
| `logger.py` | Structured logging with correlation IDs |
| `validators.py` | Common validation functions (user_id, dates, etc.) |

### 4.2 Frontend Shared (`/mobile/lib/core/`)

| Service | File | Description |
|---------|------|-------------|
| `ApiService` | `api_service.dart` | HTTP client with auth interceptor |
| `WebSocketService` | `websocket_service.dart` | WebSocket connection manager with reconnection |
| `AuthService` | `auth_service.dart` | Firebase Auth wrapper |
| `StorageService` | `storage_service.dart` | SharedPreferences for local data |

### 4.3 Shared Widgets (`/mobile/lib/widgets/common/`)

| Widget | Description |
|--------|-------------|
| `LoadingWidget` | Centered loading spinner |
| `ErrorWidget` | Error display with retry button |
| `CustomButton` | Styled button with loading state |
| `CustomCard` | Elevated card with consistent styling |
| `StatCard` | Dashboard statistic card |
| `EmptyState` | Empty list/data placeholder |

---

## 5. WebSocket Protocol Specification

### 5.1 Connection Flow

```
┌──────────────┐                              ┌──────────────┐
│   Flutter    │                              │   FastAPI    │
│   Client     │                              │   Server     │
└──────┬───────┘                              └──────┬───────┘
       │                                              │
       │  1. HTTP Upgrade Request                     │
       │  GET /ws/guardian/stream/{elderly_id}        │
       │  Headers: Authorization: Bearer {token}      │
       │ ─────────────────────────────────────────►   │
       │                                              │
       │  2. Validate JWT Token                       │
       │                                              │
       │  3. WebSocket Handshake Complete             │
       │ ◄─────────────────────────────────────────   │
       │                                              │
       │  4. Send: { type: "START_STREAM" }           │
       │ ─────────────────────────────────────────►   │
       │                                              │
       │  5. Server starts worker thread for video    │
       │     processing (non-blocking main loop)      │
       │                                              │
       │  6. Receive: { type: "VIDEO_FRAME", ... }    │
       │ ◄─────────────────────────────────────────   │
       │  (continuous at ~15 FPS)                     │
       │                                              │
       │  7. If fall detected:                        │
       │     Receive: { type: "FALL_ALERT", ... }     │
       │ ◄─────────────────────────────────────────   │
       │                                              │
       │  8. Send: { type: "STOP_STREAM" }            │
       │ ─────────────────────────────────────────►   │
       │                                              │
       │  9. Connection Close                         │
       │ ◄────────────────────────────────────────►   │
       │                                              │
```

### 5.2 Authentication

All WebSocket connections require JWT authentication:

```python
# Backend WebSocket auth middleware
async def websocket_auth(websocket: WebSocket, token: str = Query(...)):
    try:
        payload = verify_firebase_token(token)
        return payload["uid"]
    except Exception:
        await websocket.close(code=4001, reason="Unauthorized")
        raise WebSocketException(code=4001, reason="Invalid token")
```

```dart
// Flutter WebSocket connection with auth
final wsUrl = 'wss://api.smartcareplus.com/ws/guardian/stream/$elderlyId'
    '?token=${await authService.getIdToken()}';
final channel = WebSocketChannel.connect(Uri.parse(wsUrl));
```

### 5.3 Error Codes

| Code | Description |
|------|-------------|
| 4001 | Unauthorized - Invalid or expired token |
| 4002 | Forbidden - User doesn't have access to resource |
| 4003 | Not Found - Elderly user not found |
| 4004 | Rate Limited - Too many connections |
| 4005 | Server Error - Processing failed |

---

## Summary Matrix

| Team Member | Component | Backend Endpoints | WebSocket Endpoints | Flutter Screens | Flutter Widgets |
|-------------|-----------|-------------------|---------------------|-----------------|-----------------|
| **Neelaka** | Physio Service | 11 REST | 1 WS (video) | 6 | 8 |
| **Kulasekara** | Nutrition Service | 15 REST | 0 | 7 | 11 |
| **Madhushani** | Guardian Service | 17 REST | 2 WS (video + alerts) | 7 | 10 |
| **Shared** | Core | - | - | - | 6 |
