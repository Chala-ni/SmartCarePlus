# SMARTCARE+ Project Structure

> **Monorepo Architecture** for AI-Based Elderly Care Ecosystem  
> **Stack**: Flutter (Mobile) | FastAPI (Backend) | Firebase (Auth/DB) | Python AI/ML (MediaPipe, TensorFlow, Scikit-learn)  
> **UI Theme**: 🌙 Dark Mode | ⚡ Futuristic | 🔮 Glassmorphism + Neon Accents  
> **Development**: Accelerated with GenAI (GitHub Copilot Pro+)

---

## Root Directory

```
SmartCarePlus/
│
├── 📁 backend/                      # Backend - FastAPI Python Services
│   ├── 📁 core/                     # Shared Core Utilities (WebSocket, Threading, Config)
│   │   ├── __init__.py
│   │   ├── config.py                # Environment variables, Firebase config
│   │   ├── database.py              # Firebase/Firestore connection manager
│   │   ├── auth.py                  # Firebase Auth middleware & JWT validation
│   │   ├── exceptions.py            # Custom exception handlers
│   │   ├── 📁 websocket/            # WebSocket Infrastructure
│   │   │   ├── __init__.py
│   │   │   ├── manager.py           # WebSocket connection manager
│   │   │   ├── events.py            # WebSocket event types & handlers
│   │   │   └── broadcaster.py       # Real-time event broadcaster
│   │   └── 📁 threading/            # Worker Thread Utilities
│   │       ├── __init__.py
│   │       ├── video_processor.py   # Non-blocking video frame processor
│   │       ├── thread_pool.py       # Thread pool manager for CPU-bound tasks
│   │       └── task_queue.py        # Background task queue (Redis-backed)
│   │
│   ├── 📁 physio_service/           # Neelaka - Physiotherapy Analysis Module
│   │   ├── __init__.py
│   │   ├── router.py                # FastAPI router with all physio endpoints
│   │   ├── schemas.py               # Pydantic models for request/response
│   │   ├── service.py               # Business logic layer
│   │   ├── 📁 models/               # AI/ML Models
│   │   │   ├── __init__.py
│   │   │   ├── gait_analyzer.py     # MediaPipe + TensorFlow gait analysis
│   │   │   ├── tug_test.py          # Timed Up and Go test processor
│   │   │   ├── balance_scorer.py    # Balance assessment algorithms
│   │   │   ├── fall_risk.py         # Fall risk prediction (Random Forest/XGBoost)
│   │   │   └── pose_estimator.py    # MediaPipe Pose landmark extractor
│   │   ├── 📁 utils/
│   │   │   ├── __init__.py
│   │   │   ├── angle_calculator.py  # Joint angle computations
│   │   │   ├── gait_metrics.py      # Stride length, cadence, speed metrics
│   │   │   └── video_utils.py       # Frame extraction, preprocessing
│   │   ├── 📁 websocket/
│   │   │   ├── __init__.py
│   │   │   └── physio_stream.py     # Real-time video stream handler for physio analysis
│   │   └── 📁 data/
│   │       ├── exercises.json       # Exercise library definitions
│   │       └── risk_thresholds.json # Fall risk scoring thresholds
│   │
│   ├── 📁 nutrition_service/        # Kulasekara - Nutrition & Meal Planning Module
│   │   ├── __init__.py
│   │   ├── router.py                # FastAPI router with nutrition endpoints
│   │   ├── schemas.py               # Pydantic models
│   │   ├── service.py               # Business logic layer
│   │   ├── 📁 models/               # AI/ML Models
│   │   │   ├── __init__.py
│   │   │   ├── food_classifier.py   # CNN food image recognition (MobileNetV2)
│   │   │   ├── portion_estimator.py # Serving size estimation
│   │   │   ├── meal_recommender.py  # Personalized meal plan generator
│   │   │   └── interaction_checker.py # Food-medication interaction detector
│   │   ├── 📁 utils/
│   │   │   ├── __init__.py
│   │   │   ├── usda_client.py       # USDA FoodData Central API client
│   │   │   ├── nutrition_calc.py    # Macro/micronutrient calculations
│   │   │   └── rda_validator.py     # Recommended Daily Allowance checker
│   │   └── 📁 data/
│   │       ├── usda_cache.json      # Cached USDA food data
│   │       ├── food_categories.json # Food classification categories
│   │       ├── elderly_rda.json     # RDA values for 65+ age group
│   │       └── interactions.json    # Drug-food interaction database
│   │
│   ├── 📁 guardian_service/         # Madhushani - Real-time Monitoring & Safety Module
│   │   ├── __init__.py
│   │   ├── router.py                # FastAPI router with guardian endpoints
│   │   ├── schemas.py               # Pydantic models
│   │   ├── service.py               # Business logic layer
│   │   ├── 📁 models/               # AI/ML Models
│   │   │   ├── __init__.py
│   │   │   ├── fall_detector.py     # Fall detection (LSTM + pose-based)
│   │   │   ├── activity_recognizer.py # Activity classification model
│   │   │   ├── anomaly_detector.py  # Behavioral anomaly detection (Isolation Forest)
│   │   │   └── pose_tracker.py      # Real-time pose tracking
│   │   ├── 📁 utils/
│   │   │   ├── __init__.py
│   │   │   ├── alert_manager.py     # Alert priority & notification logic
│   │   │   ├── geofence.py          # Geofencing utilities
│   │   │   └── vital_parser.py      # Wearable vital signs parser
│   │   ├── 📁 websocket/
│   │   │   ├── __init__.py
│   │   │   ├── guardian_stream.py   # Real-time video monitoring WebSocket
│   │   │   └── alert_socket.py      # Real-time alert broadcasting
│   │   └── 📁 data/
│   │       ├── activity_labels.json # Activity classification labels
│   │       └── alert_templates.json # Alert message templates
│   │
│   ├── 📁 shared/                   # Shared Utilities Across Services
│   │   ├── __init__.py
│   │   ├── firebase_client.py       # Firebase Admin SDK wrapper
│   │   ├── storage.py               # Firebase Storage for video/images
│   │   ├── notifications.py         # FCM push notification sender
│   │   ├── logger.py                # Centralized logging configuration
│   │   └── validators.py            # Common validation functions
│   │
│   ├── 📁 ml_models/                # Pre-trained Model Weights
│   │   ├── physio/
│   │   │   ├── gait_lstm.h5         # Gait analysis LSTM model
│   │   │   └── fall_risk_rf.pkl     # Fall risk Random Forest model
│   │   ├── nutrition/
│   │   │   └── food_classifier.h5   # Food image CNN model
│   │   └── guardian/
│   │       ├── fall_detector.h5     # Fall detection LSTM model
│   │       └── activity_model.pkl   # Activity recognition model
│   │
│   ├── 📁 tests/                    # Backend Tests
│   │   ├── __init__.py
│   │   ├── conftest.py              # Pytest fixtures
│   │   ├── 📁 physio/
│   │   │   ├── test_gait.py
│   │   │   └── test_tug.py
│   │   ├── 📁 nutrition/
│   │   │   ├── test_food_classifier.py
│   │   │   └── test_meal_plan.py
│   │   └── 📁 guardian/
│   │       ├── test_fall_detection.py
│   │       └── test_websocket.py
│   │
│   ├── 📁 scripts/                  # Utility Scripts
│   │   ├── seed_database.py         # Initialize Firestore with sample data
│   │   ├── train_models.py          # Model training entry point
│   │   └── generate_test_video.py   # Generate test video from samples
│   │
│   ├── main.py                      # FastAPI application entry point
│   ├── requirements.txt             # Python dependencies
│   ├── Dockerfile                   # Docker configuration
│   └── .env.example                 # Environment variables template
│
├── 📁 frontend/                     # Frontend - Flutter Mobile Application
│   ├── 📁 android/                  # Android-specific configuration
│   ├── 📁 ios/                      # iOS-specific configuration
│   │
│   ├── 📁 lib/
│   │   ├── main.dart                # App entry point
│   │   │
│   │   ├── 📁 core/                 # Core Application Layer
│   │   │   ├── 📁 config/
│   │   │   │   ├── app_config.dart  # Environment configuration
│   │   │   │   ├── routes.dart      # Route definitions
│   │   │   │   └── theme.dart       # 🌙 DARK FUTURISTIC THEME
│   │   │   ├── 📁 constants/
│   │   │   │   ├── api_endpoints.dart
│   │   │   │   ├── colors.dart      # Neon color palette
│   │   │   │   └── strings.dart
│   │   │   ├── 📁 services/
│   │   │   │   ├── api_service.dart        # HTTP client wrapper
│   │   │   │   ├── websocket_service.dart  # WebSocket connection manager
│   │   │   │   ├── auth_service.dart       # Firebase Auth wrapper
│   │   │   │   └── storage_service.dart    # Local storage (SharedPreferences)
│   │   │   └── 📁 utils/
│   │   │       ├── validators.dart
│   │   │       ├── date_formatter.dart
│   │   │       └── permission_handler.dart
│   │   │
│   │   ├── 📁 models/               # Data Models (Dart Classes)
│   │   │   ├── user_model.dart
│   │   │   ├── elderly_model.dart
│   │   │   ├── 📁 physio/
│   │   │   │   ├── gait_result.dart
│   │   │   │   ├── exercise.dart
│   │   │   │   └── fall_risk.dart
│   │   │   ├── 📁 nutrition/
│   │   │   │   ├── food_item.dart
│   │   │   │   ├── meal_plan.dart
│   │   │   │   └── nutrition_log.dart
│   │   │   └── 📁 guardian/
│   │   │       ├── alert.dart
│   │   │       ├── activity_log.dart
│   │   │       └── location.dart
│   │   │
│   │   ├── 📁 providers/            # State Management (Riverpod)
│   │   │   ├── auth_provider.dart
│   │   │   ├── physio_provider.dart
│   │   │   ├── nutrition_provider.dart
│   │   │   └── guardian_provider.dart
│   │   │
│   │   ├── 📁 screens/              # Screen/Page Widgets
│   │   │   ├── 📁 auth/
│   │   │   │   ├── login_screen.dart
│   │   │   │   ├── register_screen.dart
│   │   │   │   └── profile_screen.dart
│   │   │   ├── 📁 home/
│   │   │   │   ├── home_screen.dart
│   │   │   │   └── dashboard_screen.dart
│   │   │   ├── 📁 physio/           # Neelaka - Physio Screens
│   │   │   │   ├── physio_home_screen.dart
│   │   │   │   ├── gait_analysis_screen.dart
│   │   │   │   ├── tug_test_screen.dart
│   │   │   │   ├── exercise_library_screen.dart
│   │   │   │   ├── exercise_session_screen.dart
│   │   │   │   └── physio_report_screen.dart
│   │   │   ├── 📁 nutrition/        # Kulasekara - Nutrition Screens
│   │   │   │   ├── nutrition_home_screen.dart
│   │   │   │   ├── food_scanner_screen.dart
│   │   │   │   ├── meal_log_screen.dart
│   │   │   │   ├── meal_plan_screen.dart
│   │   │   │   ├── hydration_screen.dart
│   │   │   │   ├── nutrition_report_screen.dart
│   │   │   │   └── dietary_restrictions_screen.dart
│   │   │   └── 📁 guardian/         # Madhushani - Guardian Screens
│   │   │       ├── guardian_home_screen.dart
│   │   │       ├── live_monitor_screen.dart
│   │   │       ├── alerts_screen.dart
│   │   │       ├── activity_log_screen.dart
│   │   │       ├── geofence_screen.dart
│   │   │       ├── emergency_screen.dart
│   │   │       └── elderly_profile_screen.dart
│   │   │
│   │   └── 📁 widgets/              # Reusable Widget Components
│   │       ├── 📁 common/           # Shared Widgets (Dark Theme)
│   │       │   ├── glassmorphic_card.dart     # Frosted glass card effect
│   │       │   ├── neon_button.dart           # Glowing neon button
│   │       │   ├── gradient_background.dart   # Dark gradient backgrounds
│   │       │   ├── shimmer_loading.dart       # Loading skeleton with glow
│   │       │   ├── glow_icon.dart             # Icons with neon glow
│   │       │   ├── animated_counter.dart      # Animated number displays
│   │       │   └── empty_state.dart           # Empty state placeholder
│   │       ├── 📁 physio/           # Neelaka - Physio Widgets
│   │       │   ├── camera_stream_widget.dart  # WebSocket video streaming
│   │       │   ├── pose_overlay_widget.dart   # MediaPipe skeleton overlay
│   │       │   ├── gait_metrics_card.dart     # Real-time gait display
│   │       │   ├── fall_risk_indicator.dart   # Circular gauge with glow
│   │       │   ├── exercise_card.dart
│   │       │   ├── progress_chart.dart        # Animated line charts
│   │       │   ├── tug_timer_widget.dart
│   │       │   └── joint_angle_display.dart
│   │       ├── 📁 nutrition/        # Kulasekara - Nutrition Widgets
│   │       │   ├── food_scanner_widget.dart   # AI food scanner with animation
│   │       │   ├── nutrition_facts_card.dart  # FDA-style label
│   │       │   ├── meal_card.dart
│   │       │   ├── diet_card_widget.dart
│   │       │   ├── hydration_tracker.dart     # Water tracking with waves
│   │       │   ├── macro_pie_chart.dart       # Animated pie chart
│   │       │   ├── calorie_progress.dart      # Circular progress with glow
│   │       │   ├── nutrient_bar.dart
│   │       │   ├── food_search_widget.dart
│   │       │   ├── portion_selector.dart
│   │       │   └── interaction_warning.dart   # Alert with neon border
│   │       └── 📁 guardian/         # Madhushani - Guardian Widgets
│   │           ├── live_feed_widget.dart      # WebSocket video display
│   │           ├── alert_card.dart            # Glowing alert badges
│   │           ├── sos_button.dart            # Pulsing emergency button
│   │           ├── activity_timeline.dart
│   │           ├── location_map_widget.dart
│   │           ├── vital_signs_card.dart      # Heart rate with pulse animation
│   │           ├── status_indicator.dart
│   │           ├── fall_alert_modal.dart      # Full-screen alert
│   │           ├── geofence_editor.dart
│   │           └── inactivity_warning.dart
│   │
│   ├── 📁 assets/
│   │   ├── 📁 images/               # App images
│   │   ├── 📁 icons/                # Custom neon-glow icons
│   │   ├── 📁 animations/           # Lottie animations (futuristic)
│   │   │   ├── loading_pulse.json   # Neon pulse loading
│   │   │   ├── scan_effect.json     # AI scan animation
│   │   │   ├── success_glow.json    # Success confirmation
│   │   │   └── alert_pulse.json     # Emergency alert animation
│   │   └── 📁 fonts/
│   │       ├── Orbitron/            # Futuristic headings
│   │       ├── Exo2/                # Modern UI text
│   │       └── Inter/               # Body text
│   │
│   ├── pubspec.yaml                 # Flutter dependencies
│   ├── analysis_options.yaml        # Dart analyzer configuration
│   └── README.md
│
├── 📁 docs/                         # Documentation
│   ├── PROJECT_STRUCTURE.md         # This file
│   ├── FEATURES_SPEC.md             # Feature specifications
│   └── SPRINT_PLAN.md               # 1-Month development timeline
│
├── 📁 scripts/                      # Utility Scripts
│   ├── setup.ps1                    # Windows setup script
│   ├── setup.sh                     # Linux/Mac setup script
│   └── run_all.ps1                  # Run both backend and frontend
│
├── 📁 .github/
│   └── 📁 workflows/
│       ├── backend-ci.yml           # Python linting, tests (backend/)
│       ├── frontend-ci.yml          # Flutter analyze, test (frontend/)
│       ├── deploy-backend.yml       # Deploy to Cloud Run/Railway
│       └── deploy-frontend.yml      # Build APK, Firebase App Distribution
│
├── .gitignore
└── README.md
```

---

## 🎨 Dark Futuristic Theme Specification

### Color Palette

```dart
// frontend/lib/core/constants/colors.dart

class AppColors {
  // Primary Dark Backgrounds
  static const Color background = Color(0xFF0A0E17);      // Deep space black
  static const Color surface = Color(0xFF111827);         // Card background
  static const Color surfaceLight = Color(0xFF1F2937);    // Elevated surface
  
  // Neon Accent Colors
  static const Color neonCyan = Color(0xFF00F5FF);        // Primary accent
  static const Color neonPurple = Color(0xFFBF00FF);      // Secondary accent
  static const Color neonPink = Color(0xFFFF00E5);        // Tertiary accent
  static const Color neonGreen = Color(0xFF00FF88);       // Success states
  static const Color neonOrange = Color(0xFFFF6B00);      // Warning states
  static const Color neonRed = Color(0xFFFF0055);         // Error/Alert states
  
  // Text Colors
  static const Color textPrimary = Color(0xFFFFFFFF);     // White text
  static const Color textSecondary = Color(0xFF9CA3AF);   // Gray text
  static const Color textMuted = Color(0xFF6B7280);       // Muted text
  
  // Glassmorphism
  static const Color glassWhite = Color(0x1AFFFFFF);      // 10% white
  static const Color glassBorder = Color(0x33FFFFFF);     // 20% white border
  
  // Gradients
  static const List<Color> primaryGradient = [neonCyan, neonPurple];
  static const List<Color> alertGradient = [neonRed, neonOrange];
  static const List<Color> successGradient = [neonGreen, neonCyan];
}
```

### Theme Configuration

```dart
// frontend/lib/core/config/theme.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/colors.dart';

class AppTheme {
  static ThemeData get darkFuturistic => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.background,
    
    // Color Scheme
    colorScheme: const ColorScheme.dark(
      primary: AppColors.neonCyan,
      secondary: AppColors.neonPurple,
      surface: AppColors.surface,
      background: AppColors.background,
      error: AppColors.neonRed,
    ),
    
    // Typography
    textTheme: TextTheme(
      displayLarge: GoogleFonts.orbitron(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
      headlineMedium: GoogleFonts.exo2(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        color: AppColors.textPrimary,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        color: AppColors.textSecondary,
      ),
    ),
    
    // AppBar
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: GoogleFonts.orbitron(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.neonCyan,
      ),
    ),
    
    // Cards with Glassmorphism
    cardTheme: CardTheme(
      color: AppColors.glassWhite,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.glassBorder),
      ),
    ),
    
    // Elevated Buttons with Glow
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.neonCyan,
        foregroundColor: AppColors.background,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: GoogleFonts.exo2(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    
    // Input Fields
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceLight,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.neonCyan, width: 2),
      ),
      labelStyle: TextStyle(color: AppColors.textSecondary),
    ),
    
    // Bottom Navigation
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: AppColors.surface,
      selectedItemColor: AppColors.neonCyan,
      unselectedItemColor: AppColors.textMuted,
      type: BottomNavigationBarType.fixed,
    ),
  );
}
```

### Glassmorphic Card Widget

```dart
// frontend/lib/widgets/common/glassmorphic_card.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';

class GlassmorphicCard extends StatelessWidget {
  final Widget child;
  final double blur;
  final double borderRadius;
  final EdgeInsets padding;
  final Color? glowColor;
  
  const GlassmorphicCard({
    super.key,
    required this.child,
    this.blur = 10,
    this.borderRadius = 16,
    this.padding = const EdgeInsets.all(16),
    this.glowColor,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: glowColor != null
            ? [
                BoxShadow(
                  color: glowColor!.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: AppColors.glassWhite,
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
```

---

## 🔗 WebSocket & Threading Architecture

### Video Streaming Flow (Physio & Guardian)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         VIDEO STREAMING ARCHITECTURE                         │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  Flutter App (frontend/)                  FastAPI Server (backend/)          │
│  ┌────────────────────┐                   ┌─────────────────────────────┐   │
│  │ CameraStreamWidget │                   │     WebSocket Handler       │   │
│  │ or LiveFeedWidget  │                   │     (async, non-blocking)   │   │
│  │                    │                   │                             │   │
│  │ ┌────────────────┐ │   WebSocket       │ ┌─────────────────────────┐ │   │
│  │ │ Camera/Video   │ │ ════════════════► │ │   Frame Receiver        │ │   │
│  │ │ Frame Capture  │ │   (binary frames) │ │   (validates, queues)   │ │   │
│  │ └────────────────┘ │                   │ └───────────┬─────────────┘ │   │
│  │                    │                   │             │               │   │
│  │                    │                   │             ▼               │   │
│  │                    │                   │ ┌─────────────────────────┐ │   │
│  │                    │                   │ │   ThreadPoolExecutor    │ │   │
│  │                    │                   │ │   (CPU-bound tasks)     │ │   │
│  │                    │                   │ │                         │ │   │
│  │                    │                   │ │ ┌─────────────────────┐ │ │   │
│  │ ┌────────────────┐ │                   │ │ │ Worker Thread 1     │ │ │   │
│  │ │ PoseOverlay    │ │   (pose results)  │ │ │ MediaPipe Pose      │ │ │   │
│  │ │ Widget         │ │ ◄════════════════ │ │ │ Estimation          │ │ │   │
│  │ │ (draws skeleton│ │                   │ │ └─────────────────────┘ │ │   │
│  │ └────────────────┘ │                   │ │                         │ │   │
│  │                    │                   │ │ ┌─────────────────────┐ │ │   │
│  │ ┌────────────────┐ │                   │ │ │ Worker Thread 2     │ │ │   │
│  │ │ GaitMetrics or │ │   (metrics JSON)  │ │ │ Gait/Fall Analysis  │ │ │   │
│  │ │ AlertCard      │ │ ◄════════════════ │ │ │ (TF/sklearn)        │ │ │   │
│  │ └────────────────┘ │                   │ │ └─────────────────────┘ │ │   │
│  │                    │                   │ │                         │ │   │
│  │ ┌────────────────┐ │                   │ │ ┌─────────────────────┐ │ │   │
│  │ │ FallAlertModal │ │   (FALL_ALERT)    │ │ │ Worker Thread 3     │ │ │   │
│  │ │ (emergency)    │ │ ◄════════════════ │ │ │ Fall Detection LSTM │ │ │   │
│  │ └────────────────┘ │                   │ │ └─────────────────────┘ │ │   │
│  │                    │                   │ └─────────────────────────┘ │   │
│  └────────────────────┘                   └─────────────────────────────┘   │
│                                                                              │
│  ⚠️ CRITICAL: Video processing runs in worker threads to prevent           │
│     blocking the main FastAPI async event loop                               │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 👥 Team Ownership Matrix

| Path | Owner | Description |
|------|-------|-------------|
| `/backend/physio_service/` | Neelaka | Physiotherapy & mobility analysis |
| `/backend/nutrition_service/` | Kulasekara | Dietary management & meal planning |
| `/backend/guardian_service/` | Madhushani | Real-time safety monitoring |
| `/backend/core/` | All | Shared utilities, WebSocket, threading |
| `/frontend/lib/screens/physio/` | Neelaka | Physio Flutter screens |
| `/frontend/lib/screens/nutrition/` | Kulasekara | Nutrition Flutter screens |
| `/frontend/lib/screens/guardian/` | Madhushani | Guardian Flutter screens |
| `/frontend/lib/widgets/physio/` | Neelaka | Physio widgets (camera, pose overlay) |
| `/frontend/lib/widgets/nutrition/` | Kulasekara | Nutrition widgets (scanner, charts) |
| `/frontend/lib/widgets/guardian/` | Madhushani | Guardian widgets (live feed, alerts) |
| `/frontend/lib/core/` | All | Shared Flutter services, theme, constants |
| `/frontend/lib/widgets/common/` | All | Shared dark theme widgets |

---

## 📱 Quick Start Commands

```bash
# Clone and setup
git clone https://github.com/your-repo/SmartCarePlus.git
cd SmartCarePlus

# Backend setup
cd backend
python -m venv venv
.\venv\Scripts\activate  # Windows
pip install -r requirements.txt
uvicorn main:app --reload --port 8000

# Frontend setup (new terminal)
cd frontend
flutter pub get
flutter run
```
