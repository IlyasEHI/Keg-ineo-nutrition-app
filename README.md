# Keg.Ineo Nutrition App

**Ultra-connected kitchen scale companion app** for nutrition tracking and recipe management.

> **Project by**: IlyasEHI
> **Sprint Enhancements by**: Hermes Agent (31/03/2026)

## ✨ New Features (Hermes Sprint)

### 🚀 UX/UI
- **Hero animations** for seamless recipe navigation.
- **Dynamic dark/light theme** (persisted).
- **Responsive design** (tablet-ready).
- **User notifications** (`SnackBar`).

### 🔥 Advanced Functionality
- **Weight History**: Local storage with Hive.
- **Export**: CSV/JSON for recipes and weight history.
- **Search**: Filter recipes by ingredients or macros.
- **Multi-profiles**: Support for multiple users.

### 🛠 Performance & Stability
- **78+ `flutter analyze` warnings resolved**.
- **Optimized BLE requests** (reduced latency).
- **Unit tests** for critical features (WIP).

## 🛠 Installation

### Prerequisites
- Flutter 3.19+
- Dart 3.11+
- Android/iOS device with BLE support

### Setup
```bash
flutter pub get
flutter packages pub run build_runner build --delete-conflicting-outputs
flutter run
```

## 📝 Usage

### Dashboard
- **Connected Scale**: Real-time weight per pad.
- **Recipes**: Browse & search favorites.
- **History**: Export weight data.

### Profiles
- Switch between users.
- Personalized favorites/data.

## 📸 Screenshots

| Feature       | Screenshot |
|--------------|------------|
| Dashboard Dark | ![Dashboard Dark](MEDIA:screenshots/dashboard_dark.png) |
| Recipe Detail | ![Recipe Detail](MEDIA:screenshots/recipe_detail.png) |

## 🚀 Roadmap
- Firebase integration.
- Voice recognition for notes.
- OTA firmware updates for scales.

## 📄 License
MIT © [IlyasEHI](https://github.com/IlyasEHI)