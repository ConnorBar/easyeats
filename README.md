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
If your app is configured to talk to a local API, start the backend in `backend/` (exact steps depend on the backend stack in that folder).

## Project notes
- This is a class project repo; build outputs and generated files are ignored via `.gitignore`.

## Links
- MongoDB Atlas: `https://cloud.mongodb.com/v2/6982afdde41c90644063ed40#/overview`
