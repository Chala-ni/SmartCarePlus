# SMARTCARE+ 

> AI-Powered Elderly Care Ecosystem

A comprehensive mobile health platform for elderly care, featuring physiotherapy analysis, nutrition tracking, and real-time guardian monitoring.

## 🎨 Theme

**Dark Futuristic** with Glassmorphism and Neon Accents

## 🏗️ Architecture

```
SmartCarePlus/
├── backend/          # FastAPI Python Backend
│   ├── physio_service/     # Neelaka - Physiotherapy
│   ├── nutrition_service/  # Kulasekara - Nutrition
│   └── guardian_service/   # Madhushani - Guardian
├── frontend/         # Flutter Mobile App
├── docs/             # Documentation
└── scripts/          # Utility scripts
```

## 🚀 Quick Start

### Backend
```bash
cd backend
python -m venv venv
.\venv\Scripts\activate  # Windows
pip install -r requirements.txt
uvicorn main:app --reload --port 8000
```

### Frontend
```bash
cd frontend
flutter pub get
flutter run
```

**Note on Deployment (University Demo):** This is a university demo—do **NOT** deploy backend or frontend services to Cloud Run or other production platforms. Run the backend and frontend locally (see Quick Start) or use Firebase emulators for database and auth during development.

## 👥 Team

| Member | Service | Focus |
|--------|---------|-------|
| Neelaka | Physio | Gait analysis, TUG test, exercises |
| Kulasekara | Nutrition | Food recognition, meal planning |
| Madhushani | Guardian | Fall detection, live monitoring |

## 📅 Timeline

**1 Month** (GenAI Accelerated with Copilot Pro+)

---

*University Project - SMARTCARE+*
