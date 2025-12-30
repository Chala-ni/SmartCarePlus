# SMARTCARE+ Frontend Development Guide

> Flutter application for the SMARTCARE+ elderly care ecosystem

---

## ⚠️ CRITICAL: Running on Physical Device

### DO NOT USE EMULATOR - Use Physical Device via USB

The SMARTCARE+ app requires camera access and real-time video processing for:
- **Physio Service**: Gait analysis and pose detection
- **Nutrition Service**: Food recognition via camera
- **Guardian Service**: Fall detection monitoring

Emulators do not provide reliable camera/sensor access. **Always test on a physical Android device.**

---

## 🔌 Backend Connection Setup

### Step 1: Start the Backend Server

```powershell
cd d:\SmartCarePlus\backend
d:\SmartCarePlus\.venv\Scripts\python.exe -m uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

### Step 2: Enable ADB Port Forwarding

**REQUIRED** for device to communicate with localhost backend:

```bash
adb reverse tcp:8000 tcp:8000
```

This forwards port 8000 from your device to your computer's localhost:8000.

### Step 3: Verify Connection

On your device, the app will connect to `http://localhost:8000` which will be forwarded to your PC's backend.

---

## 📱 Build & Run Commands

### Debug Build (Development)

```bash
cd frontend
flutter run
```

### Release Build

```bash
flutter build apk --release
```

### Clean Build (if issues occur)

```bash
flutter clean
cd android
./gradlew clean
cd ..
flutter pub get
flutter run
```

---

## 🛠️ Build Configuration Notes

### NDK Version Lock
- **Version**: `27.0.12077973`
- **Reason**: Specific version installed locally; do not let Gradle auto-download

### MinSDK Requirement
- **minSdkVersion**: `24`
- **Reason**: Required for CameraX and ML Kit plugins

### Drive Split Fix (C:/D:)
The following settings in `gradle.properties` prevent build failures when SDK is on C: and project is on D:

```properties
kotlin.incremental=false
kotlin.incremental.useClasspathSnapshot=false
```

---

## 📦 Dependencies

### Firebase Services
- `firebase_core` - Core Firebase initialization
- `firebase_auth` - User authentication
- `cloud_firestore` - Database
- `firebase_messaging` - Push notifications

### UI/UX
- `flutter_riverpod` - State management
- `google_fonts` - Typography
- `fl_chart` - Charts and graphs
- `shimmer` - Loading effects

### Camera/ML
- `camera` - Camera access
- `google_mlkit_pose_detection` - Pose estimation

### Networking
- `dio` - HTTP client
- `web_socket_channel` - WebSocket connections

---

## 🎨 Theme

The app uses a **Dark Futuristic** theme with:
- Background: `#0A0E17`
- Primary (Neon Cyan): `#00F5FF`
- Secondary (Neon Purple): `#BF00FF`
- Glassmorphism effects on cards

---

## 👥 Team Ownership

| Feature | Owner | Screens |
|---------|-------|---------|
| Physio Service | Neelaka | `lib/screens/physio/` |
| Nutrition Service | Kulasekara | `lib/screens/nutrition/` |
| Guardian Service | Madhushani | `lib/screens/guardian/` |

---

## 🐛 Common Issues

### "SDK location not found"
Create `frontend/android/local.properties`:
```properties
sdk.dir=C:\\Users\\<YOUR_USER>\\AppData\\Local\\Android\\Sdk
flutter.sdk=C:\\flutter
```

### "NDK not found"
Ensure NDK `27.0.12077973` is installed via Android Studio SDK Manager.

### "Connection refused on device"
Run `adb reverse tcp:8000 tcp:8000` after connecting your device.

### Gradle build fails with "Unable to make field private"
Clean and rebuild:
```bash
flutter clean
flutter pub get
```
