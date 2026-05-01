# EasyEats (FridgeBridge)

Kitchen inventory + recipe matching app built with **Flutter**.

## What’s in this repo
- **`fridgebridge/`**: Flutter app (UI + client logic)
- **`backend/`**: Backend service (if you’re running the API locally)

## Features
- Track ingredients in your “fridge” inventory
- Add ingredients with quantity + optional metadata
- Recipe discovery/matching based on what you have

## Getting started

### Prereqs
- **Flutter SDK** installed (`flutter --version`)
- A working platform toolchain for what you’re running:
  - iOS/macOS: Xcode
  - Android: Android Studio + SDK

### Run the Flutter app

```bash
cd fridgebridge
flutter pub get
flutter run
```

Common alternatives:

```bash
flutter run -d chrome
flutter run -d macos
flutter run -d android
```

## Backend (optional)
This repo includes a **FastAPI** backend in `backend/` that uses MongoDB (local or Atlas).

### Configure MongoDB
- **Option A (local MongoDB)**: run MongoDB on `mongodb://localhost:27017` (this is the default).
- **Option B (MongoDB Atlas)**: set a working connection string.

Create `backend/.env` (don’t commit it). You can start from `backend/env.example`.

Required env vars:
- `MONGODB_URI`
- `DATABASE_NAME` (defaults to `fridgebridge`)

### Run the backend

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

If you see `500` errors and the backend log mentions `authentication failed`, your `MONGODB_URI` credentials are wrong (or your Atlas user/IP allowlist needs updating).

## Project notes
- This is a class project repo; build outputs and generated files are ignored via `.gitignore`.

## Links
- MongoDB Atlas: `https://cloud.mongodb.com/v2/6982afdde41c90644063ed40#/overview`
