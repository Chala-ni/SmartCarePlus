# SMARTCARE+ 

> AI-Powered Elderly Care Ecosystem

A comprehensive mobile health platform for elderly care, featuring physiotherapy analysis, nutrition tracking, and real-time guardian monitoring.

---

## 📋 Table of Contents

1. [Prerequisites](#-prerequisites)
2. [Flutter Installation](#-flutter-installation-detailed)
3. [Android SDK & NDK Setup](#-android-sdk--ndk-setup-critical)
4. [ADB Configuration](#-adb-configuration)
5. [Project Structure](#-project-structure)
6. [Backend Setup](#-backend-setup)
7. [Frontend Setup](#-frontend-setup)
8. [Physical Device Setup](#-physical-device-setup-android)
9. [Running the Application](#-running-the-application)
10. [API Endpoints](#-api-endpoints)
11. [Troubleshooting](#-troubleshooting)
12. [Team](#-team)

---

## 🛠️ Prerequisites

### Required Software

| Software | Version | Download |
|----------|---------|----------|
| **Python** | 3.10 - 3.12 | [python.org](https://www.python.org/downloads/) |
| **Flutter** | 3.16+ (3.24 recommended) | [flutter.dev](https://flutter.dev/docs/get-started/install) |
| **Android Studio** | Ladybug or later | [developer.android.com](https://developer.android.com/studio) |
| **Git** | Latest | [git-scm.com](https://git-scm.com/) |
| **VS Code** | Latest (recommended) | [code.visualstudio.com](https://code.visualstudio.com/) |
| **Java JDK** | 17 | Included with Android Studio |

### Verify Installations

```powershell
# Check Python
python --version
# Expected: Python 3.10.x - 3.12.x

# Check Flutter
flutter --version
# Expected: Flutter 3.16.x or higher

# Check Flutter Doctor (fix any issues shown)
flutter doctor -v

# Check ADB (from Android SDK)
adb --version

# Check Java
java -version
# Expected: openjdk version "17.x.x"
```

---

## 📦 Flutter Installation (Detailed)

### Step 1: Download Flutter SDK

1. Go to [Flutter Downloads](https://docs.flutter.dev/get-started/install/windows)
2. Download the latest stable release (zip file)
3. Extract to a folder (recommended: `C:\flutter`)

> ⚠️ **Important:** Do NOT install Flutter in `C:\Program Files\` (permission issues)

### Step 2: Add Flutter to PATH

```powershell
# Option 1: Temporary (current session only)
$env:Path += ";C:\flutter\bin"

# Option 2: Permanent (recommended)
# 1. Open System Properties → Environment Variables
# 2. Under "User variables", find "Path"
# 3. Add: C:\flutter\bin
# 4. Click OK and restart terminal
```

### Step 3: Verify Flutter Installation

```powershell
# Check Flutter is accessible
flutter --version

# Run Flutter Doctor to check all dependencies
flutter doctor -v
```

### Step 4: Install VS Code Extensions

1. Open VS Code
2. Go to Extensions (Ctrl+Shift+X)
3. Install:
   - **Flutter** (by Dart Code)
   - **Dart** (by Dart Code)

---

## 🔧 Android SDK & NDK Setup (CRITICAL)

> ⚠️ **THIS PROJECT REQUIRES SPECIFIC NDK VERSION: `27.0.12077973`**
> 
> Using a different NDK version will cause build failures!

### Step 1: Install Android Studio

1. Download from [developer.android.com/studio](https://developer.android.com/studio)
2. Run installer with default options
3. Complete the setup wizard (downloads Android SDK)

### Step 2: Open SDK Manager

1. Open Android Studio
2. Go to **Tools → SDK Manager** (or click "More Actions" → "SDK Manager" on welcome screen)

### Step 3: Install SDK Platforms

In **SDK Platforms** tab, check:
- ✅ Android 14.0 ("UpsideDownCake") - API Level 34
- ✅ Android 13.0 ("Tiramisu") - API Level 33

### Step 4: Install SDK Tools (CRITICAL)

In **SDK Tools** tab:

1. Check ✅ **Show Package Details** (bottom right)
2. Install these EXACT versions:

| Tool | Version | Status |
|------|---------|--------|
| **Android SDK Build-Tools** | 34.0.0 | ✅ Required |
| **NDK (Side by side)** | **27.0.12077973** | ⚠️ EXACT VERSION REQUIRED |
| **Android SDK Command-line Tools** | latest | ✅ Required |
| **Android SDK Platform-Tools** | latest | ✅ Required |
| **Android Emulator** | latest | Optional |

### Step 5: Install NDK 27.0.12077973

```powershell
# If SDK Manager doesn't show this version, install via command line:
# First, find your SDK path (usually C:\Users\<USER>\AppData\Local\Android\sdk)

# Install specific NDK version
sdkmanager "ndk;27.0.12077973"

# Verify installation
dir "$env:LOCALAPPDATA\Android\sdk\ndk"
# Should show: 27.0.12077973
```

### Step 6: Configure Environment Variables

Add these to your System Environment Variables:

```powershell
# Check current Android SDK location
echo $env:LOCALAPPDATA\Android\sdk

# Add to Environment Variables:
# Variable: ANDROID_HOME
# Value: C:\Users\<YOUR_USERNAME>\AppData\Local\Android\sdk

# Variable: ANDROID_SDK_ROOT  
# Value: C:\Users\<YOUR_USERNAME>\AppData\Local\Android\sdk

# Add to PATH:
# %ANDROID_HOME%\platform-tools
# %ANDROID_HOME%\tools
# %ANDROID_HOME%\tools\bin
```

### Step 7: Accept Android Licenses

```powershell
flutter doctor --android-licenses
# Press 'y' to accept all licenses
```

### Step 8: Verify Setup

```powershell
flutter doctor -v
```

Expected output:
```
[✓] Flutter (Channel stable, 3.x.x)
[✓] Android toolchain - develop for Android devices (Android SDK version 34.0.0)
[✓] Android Studio (version 202x.x)
```

---

## 📱 ADB Configuration

ADB (Android Debug Bridge) is essential for deploying apps to physical devices.

### Verify ADB Installation

```powershell
# Check ADB is installed
adb version

# Expected output:
# Android Debug Bridge version 1.0.41
# Version 34.0.x
```

### If ADB Not Found

```powershell
# Add platform-tools to PATH
$env:Path += ";$env:LOCALAPPDATA\Android\sdk\platform-tools"

# Or add permanently via System Environment Variables:
# Add to PATH: C:\Users\<USER>\AppData\Local\Android\sdk\platform-tools
```

### Enable USB Debugging on Android Device

1. Go to **Settings → About Phone**
2. Tap **Build Number** 7 times (enables Developer Options)
3. Go back to **Settings → System → Developer Options**
4. Enable:
   - ✅ **USB Debugging**
   - ✅ **Install via USB** (if available)
   - ✅ **USB debugging (Security settings)** (on some phones)

### Connect Device and Verify

```powershell
# Connect phone via USB cable

# List connected devices
adb devices

# Expected output:
# List of devices attached
# XXXXXXXX    device

# If shows "unauthorized", check phone for authorization popup
```

### ADB Useful Commands

```powershell
# Kill and restart ADB server (fixes most issues)
adb kill-server
adb start-server

# Port forwarding (for localhost connections)
adb reverse tcp:8000 tcp:8000

# List all port forwards
adb reverse --list

# Remove all port forwards
adb reverse --remove-all

# Check device logs
adb logcat

# Install APK manually
adb install path\to\app.apk

# Check connected device details
adb shell getprop ro.product.model
```

### Wireless ADB (Optional)

```powershell
# First connect via USB, then:
adb tcpip 5555

# Disconnect USB, then connect wirelessly:
adb connect <PHONE_IP>:5555

# Find phone IP: Settings → Wi-Fi → Connected network → IP address
```

---

## 🔑 SHA-1 Key Generation (Required for Firebase & Google Sign-In)

Firebase Authentication (especially Google Sign-In) requires SHA-1 fingerprint of your signing key.

### Generate Debug SHA-1 Key

#### Option 1: Using Gradle (Recommended)

```powershell
cd D:\SmartCarePlus\frontend\android

# Run signing report
.\gradlew signingReport
```

Look for output like:
```
> Task :app:signingReport
Variant: debug
Config: debug
Store: C:\Users\<USER>\.android\debug.keystore
Alias: AndroidDebugKey
MD5: XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX
SHA1: XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX  <-- Copy this
SHA-256: XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX
```

#### Option 2: Using keytool Command

```powershell
# Find keytool (from Java/Android Studio)
# Usually at: C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe

# Generate SHA-1 for debug keystore
& "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -list -v -keystore "$env:USERPROFILE\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
```

### Add SHA-1 to Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select project: **smartcare-plus-c9617**
3. Click **⚙️ Project Settings** (gear icon)
4. Scroll down to **Your apps** section
5. Find your Android app (`com.smartcare.plus`)
6. Click **Add fingerprint**
7. Paste your SHA-1 fingerprint
8. Click **Save**

### Download Updated google-services.json

After adding SHA-1:

1. In Firebase Console → Project Settings → Your apps
2. Click **Download google-services.json**
3. Replace the file in: `frontend/android/app/google-services.json`

```powershell
# Verify the file is in correct location
Test-Path "D:\SmartCarePlus\frontend\android\app\google-services.json"
# Should return: True
```

### Generate Release SHA-1 (For Production)

For release builds, you need a release keystore:

```powershell
# Create a release keystore (one-time setup)
& "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -genkey -v -keystore D:\SmartCarePlus\frontend\android\app\release-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias smartcare-release

# Get SHA-1 from release keystore
& "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -list -v -keystore D:\SmartCarePlus\frontend\android\app\release-keystore.jks -alias smartcare-release
```

> ⚠️ **Important:** Keep your release keystore secure and backed up. If lost, you cannot update your app on Play Store!

### Common SHA-1 Issues

**"Google Sign-In failed" or "Error 10"**
- SHA-1 not added to Firebase
- Wrong package name in Firebase
- `google-services.json` is outdated

**"keytool not found"**
```powershell
# Add Java to PATH
$env:Path += ";C:\Program Files\Android\Android Studio\jbr\bin"
```

**"keystore was tampered with, or password was incorrect"**
- Default debug keystore password is: `android`
- If corrupted, delete and let Android Studio recreate it:
```powershell
Remove-Item "$env:USERPROFILE\.android\debug.keystore"
# Then run flutter build or Android Studio - it will recreate
```

---

## 🏗️ Project Structure

```
SmartCarePlus/
├── backend/                    # FastAPI Python Backend
│   ├── main.py                 # Main entry point
│   ├── requirements.txt        # Python dependencies
│   ├── service-account.json    # Firebase credentials (required)
│   ├── core/                   # Shared utilities, auth, database
│   ├── physio_service/         # Physiotherapy module
│   ├── nutrition_service/      # Nutrition module
│   ├── guardian_service/       # Guardian monitoring module
│   ├── ml_models/              # Trained AI models
│   │   └── guardian/           # Video classification model
│   └── media/                  # Video files for demo
│       └── simulation_footage/ # Demo videos (guardian, physio)
├── frontend/                   # Flutter Mobile App
│   ├── lib/                    # Dart source code
│   │   ├── core/               # Services, config, theme
│   │   ├── providers/          # Riverpod state management
│   │   ├── screens/            # UI screens
│   │   └── widgets/            # Reusable widgets
│   ├── android/                # Android-specific files
│   │   ├── app/build.gradle    # NDK version configured here
│   │   └── app/google-services.json  # Firebase config
│   ├── pubspec.yaml            # Flutter dependencies
│   └── assets/                 # Images, fonts, animations
├── docs/                       # Documentation
└── google-services.json        # Firebase config (copy to android/app/)
```

---

## 🐍 Backend Setup

### Step 1: Navigate to Backend Directory

```powershell
cd D:\SmartCarePlus\backend
```

### Step 2: Create Virtual Environment

```powershell
# Create virtual environment
python -m venv venv

# Activate virtual environment (Windows PowerShell)
.\venv\Scripts\Activate.ps1

# If you get an execution policy error, run this first:
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Step 3: Install Dependencies

```powershell
# Make sure venv is activated (you should see (venv) in terminal)
pip install -r requirements.txt
```

### Step 4: Verify Firebase Credentials

Make sure `service-account.json` exists in the backend folder:
```powershell
# Check if file exists
Test-Path "service-account.json"
# Should return: True
```

### Step 5: Start Backend Server

```powershell
# Start with auto-reload (development mode)
# IMPORTANT: Use --host 0.0.0.0 to allow physical device connections
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

✅ **Success indicator:** You should see:
```
INFO:     Uvicorn running on http://0.0.0.0:8000
INFO:     Started reloader process
```

### Step 6: Test Backend

Open a new terminal and run:
```powershell
# Health check
Invoke-RestMethod -Uri "http://localhost:8000/health" -Method GET

# List available videos
Invoke-RestMethod -Uri "http://localhost:8000/api/guardian/videos" -Method GET | ConvertTo-Json

# Test meal plan generation
$body = @{
    elderly_id = "elderly_001"
    preferences = @{
        dietary_restrictions = @()
        cuisine_preferences = @("sri_lankan")
        budget_level = "medium"
    }
    days = 1
} | ConvertTo-Json -Depth 3

Invoke-RestMethod -Uri "http://localhost:8000/api/nutrition/meal-plan/generate" -Method POST -Body $body -ContentType "application/json" | ConvertTo-Json -Depth 10
```

---

## 📱 Frontend Setup

### Step 1: Navigate to Frontend Directory

```powershell
cd D:\SmartCarePlus\frontend
```

### Step 2: Get Flutter Dependencies

```powershell
flutter pub get
```

### Step 3: ⚠️ IMPORTANT - Configure Server IP Address

For **physical Android devices**, you MUST update the server IP address:

**File to edit:** `frontend/lib/core/services/api_service.dart`

```dart
// Find this line (around line 27):
static const String _serverIp = '10.154.55.250';

// Change it to YOUR laptop's IP address
```

**How to find your laptop's IP:**
```powershell
# Run this command
Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -like "*Wi-Fi*" -or $_.InterfaceAlias -like "*Ethernet*" } | Select-Object IPAddress, InterfaceAlias

# Look for your Wi-Fi or Ethernet adapter IP (usually starts with 192.168.x.x or 10.x.x.x)
```

**Also update WebSocket service (if using real-time features):**

**File:** `frontend/lib/core/services/websocket_service.dart`

```dart
// Find this line (around line 118):
static const String _baseUrl = 'ws://localhost:8000';

// Change to:
static const String _baseUrl = 'ws://YOUR_IP_HERE:8000';
```

### Step 4: Verify google-services.json

Make sure Firebase config exists:
```powershell
Test-Path "android/app/google-services.json"
# Should return: True
```

---

## 📲 Physical Device Setup (Android)

### Option A: USB Connection with ADB Reverse (Recommended)

This allows the app to use `localhost` to connect to your laptop.

#### Step 1: Enable Developer Options on Phone

1. Go to **Settings → About Phone**
2. Tap **Build Number** 7 times
3. Go back to **Settings → Developer Options**
4. Enable **USB Debugging**

#### Step 2: Connect Phone via USB

```powershell
# Check if device is detected
adb devices

# You should see your device listed:
# List of devices attached
# XXXXXX    device
```

#### Step 3: Setup ADB Reverse Port Forwarding

```powershell
# This forwards phone's localhost:8000 to laptop's localhost:8000
adb reverse tcp:8000 tcp:8000

# Verify
adb reverse --list
```

⚠️ **Note:** ADB reverse does NOT work for video streaming (ExoPlayer). For full functionality, use Option B.

### Option B: Same Network with Direct IP

#### Step 1: Connect to Same Network

- Connect both laptop and phone to the **same Wi-Fi network**
- OR create a **mobile hotspot** on your phone and connect laptop to it

#### Step 2: Get Laptop IP Address

```powershell
Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -like "*Wi-Fi*" } | Select-Object IPAddress
```

#### Step 3: Update IP in Flutter Code

Edit `frontend/lib/core/services/api_service.dart`:

```dart
static const String _serverIp = 'YOUR_LAPTOP_IP';  // e.g., '192.168.1.100'
```

#### Step 4: Start Backend with Host Binding

```powershell
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

#### Step 5: Test Connection from Phone

Open phone browser and go to: `http://YOUR_LAPTOP_IP:8000/health`

You should see: `{"status": "healthy", ...}`

---

## 🚀 Running the Application

### Terminal 1: Start Backend

```powershell
cd D:\SmartCarePlus\backend
.\venv\Scripts\Activate.ps1
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

### Terminal 2: ADB Reverse (if using USB)

```powershell
adb reverse tcp:8000 tcp:8000
```

### Terminal 3: Run Flutter App

```powershell
cd D:\SmartCarePlus\frontend

# List connected devices
flutter devices

# Run on connected device
flutter run

# Or run on specific device
flutter run -d <device_id>
```

### Quick Start Script (All-in-One)

Create a file `start_dev.ps1` in the project root:

```powershell
# Start backend in new window
Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd D:\SmartCarePlus\backend; .\venv\Scripts\Activate.ps1; uvicorn main:app --reload --host 0.0.0.0 --port 8000"

# Wait for backend to start
Start-Sleep -Seconds 3

# Setup ADB reverse
adb reverse tcp:8000 tcp:8000

# Run Flutter
cd D:\SmartCarePlus\frontend
flutter run
```

---

## 🔌 API Endpoints

### Health Check
```
GET /health
```

### Physio Service (`/api/physio`)
| Endpoint | Method | Description |
|----------|--------|-------------|
| `/exercises` | GET | List all exercises |
| `/analyze-exercise` | POST | Analyze exercise video |
| `/compare-local-videos` | GET | Compare two exercise videos |
| `/session/start` | POST | Start physio session |
| `/progress/{user_id}` | GET | Get user progress |

### Nutrition Service (`/api/nutrition`)
| Endpoint | Method | Description |
|----------|--------|-------------|
| `/meal-plan/generate` | POST | Generate meal plan |
| `/meal-plan/{elderly_id}` | GET | Get meal plan |
| `/meals/log` | POST | Log a meal |
| `/meals/{elderly_id}` | GET | Get logged meals |
| `/foods/search` | GET | Search foods |

### Guardian Service (`/api/guardian`)
| Endpoint | Method | Description |
|----------|--------|-------------|
| `/videos` | GET | List demo videos |
| `/video/{video_id}` | GET | Stream video |
| `/classify-video/{video_id}` | POST | Classify video (fall detection) |
| `/fall-risk/{elderly_id}` | GET | Get fall risk assessment |
| `/analyze-gait` | POST | Analyze gait |
| `/tug-test` | POST | TUG test analysis |

### User Service (`/api/users`)
| Endpoint | Method | Description |
|----------|--------|-------------|
| `/profile` | GET/POST | User profile |
| `/elderly-profile` | GET/POST | Elderly profile |
| `/relationships` | GET/POST | Guardian-elderly relationships |

---

## 🔧 Troubleshooting

### Build Issues (NDK/SDK)

**Error: "NDK not configured" or "NDK version mismatch"**
```powershell
# This project requires NDK version 27.0.12077973

# Check installed NDK versions
dir "$env:LOCALAPPDATA\Android\sdk\ndk"

# Install correct version via SDK Manager or command line:
sdkmanager "ndk;27.0.12077973"
```

**Error: "Could not determine the dependencies of task ':app:compileDebugJavaWithJavac'"**
```powershell
# Clean and rebuild
cd D:\SmartCarePlus\frontend
flutter clean
flutter pub get
flutter run
```

**Error: "Gradle build failed" or "Could not resolve all dependencies"**
```powershell
# Clear Gradle cache
Remove-Item -Recurse -Force "$env:USERPROFILE\.gradle\caches" -ErrorAction SilentlyContinue
cd D:\SmartCarePlus\frontend\android
.\gradlew clean
cd ..
flutter run
```

**Error: "JAVA_HOME is not set"**
```powershell
# Set JAVA_HOME to Android Studio's JDK
$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"
# Add to system environment variables for permanent fix
```

### Backend Issues

**Error: "ModuleNotFoundError"**
```powershell
# Make sure venv is activated
.\venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

**Error: "Firebase credentials not found"**
```powershell
# Check file exists
Test-Path "D:\SmartCarePlus\backend\service-account.json"
# If missing, get it from Firebase Console → Project Settings → Service Accounts
```

**Error: "Address already in use"**
```powershell
# Find and kill process using port 8000
Get-NetTCPConnection -LocalPort 8000 | Select-Object OwningProcess
Stop-Process -Id <PID>
```

**Warning: "MediaPipe not available"**
```powershell
# This is OK - system falls back to mock pose detection
# To install MediaPipe (optional):
pip install mediapipe
```

**Warning: "TensorFlow not available"**
```powershell
# This is OK - system falls back to rule-based classification
# To install TensorFlow (optional, ~500MB):
pip install tensorflow
```

### Frontend Issues

**Error: "Connection refused"**
1. Check backend is running: `Invoke-RestMethod http://localhost:8000/health`
2. Check IP address is correct in `api_service.dart`
3. Run `adb reverse tcp:8000 tcp:8000`

**Error: "flutter doctor" issues**
```powershell
flutter doctor --verbose
# Follow the instructions to fix each issue
```

**Error: "Minimum supported Gradle version is X.X"**
```powershell
# Update Gradle wrapper
cd D:\SmartCarePlus\frontend\android
.\gradlew wrapper --gradle-version=8.4
```

**Videos not playing on physical device**
- Use Option B (direct IP) instead of ADB reverse
- Check firewall isn't blocking port 8000
- Try: `flutter run --release` (sometimes debug mode has issues)

### ADB Issues

**Device not showing in `adb devices`**
```powershell
# Restart ADB server
adb kill-server
adb start-server
adb devices
```

**Device shows as "unauthorized"**
1. Disconnect USB
2. On phone: Settings → Developer Options → Revoke USB debugging authorizations
3. Reconnect USB
4. Accept the popup on phone

**ADB reverse not working**
- Make sure USB debugging is enabled
- Try unplugging and replugging device
- Check device is authorized (look for popup on phone)
- Some devices don't support adb reverse - use direct IP instead

### Flutter Run Issues

**App installs but crashes immediately**
```powershell
# Check logcat for errors
adb logcat | Select-String "flutter|smartcare" -CaseSensitive:$false

# Common fix: clean rebuild
flutter clean
flutter pub get
flutter run
```

**"Error: ADB exited with exit code 1"**
```powershell
# Uninstall old version of app from device first
adb uninstall com.smartcare.plus
flutter run
```

---

## 🔥 Firebase Setup (Reference)

Firebase is already configured. If you need to reconfigure:

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select project: `smartcare-plus-c9617`
3. For Android: Download `google-services.json` → place in `frontend/android/app/`
4. For Backend: Download service account key → place as `backend/service-account.json`

---

## 👥 Team

| Member | Service | Focus |
|--------|---------|-------|
| **Neelaka** | Physio | Gait analysis, TUG test, exercises |
| **Kulasekara** | Nutrition | Food recognition, meal planning |
| **Madhushani** | Guardian | Fall detection, live monitoring |

---

## 🎨 Theme

**Dark Futuristic** with Glassmorphism and Neon Accents

---

## 📅 Timeline

**1 Month** (GenAI Accelerated with Copilot Pro+)

---

## ⚠️ Important Notes

1. **This is a university demo** - Do NOT deploy to production
2. **NDK Version**: Must use exactly `27.0.12077973` - other versions will fail
3. Always use `--host 0.0.0.0` when running backend for physical devices
4. Update IP address in Flutter code when changing networks
5. Keep `service-account.json` secure - never commit to public repos
6. If TensorFlow/MediaPipe fail to install, the system uses fallback classifiers

---

## 🔄 Quick Reference Commands

```powershell
# === BACKEND ===
cd D:\SmartCarePlus\backend
.\venv\Scripts\Activate.ps1
uvicorn main:app --reload --host 0.0.0.0 --port 8000

# === ADB ===
adb devices                           # List devices
adb reverse tcp:8000 tcp:8000         # Port forward
adb logcat -c && adb logcat           # Clear and view logs

# === FLUTTER ===
cd D:\SmartCarePlus\frontend
flutter clean                         # Clean build
flutter pub get                       # Get dependencies
flutter run                           # Run app
flutter run -d <device_id>            # Run on specific device
flutter run --release                 # Run release build

# === FIND YOUR IP ===
Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -like "*Wi-Fi*" }
```

---

*University Project - SMARTCARE+*
