# 🤖 RealityKit — AR Demo with SwiftUI

A SwiftUI AR app that places an animated 3D robot model in the real world using RealityKit and ARKit — with plane detection and tap-to-place interaction.

---

## 🤔 What this is

This project uses RealityKit and ARKit to place a USDZ 3D model (a robot) onto detected real-world surfaces. An `ARViewContainer` bridges `ARView` into SwiftUI via `UIViewRepresentable`, handling session configuration, plane detection, and entity placement. It's a clean, minimal starting point for any AR feature in an iOS app.

## ✅ Why you'd use it

- **Minimal RealityKit + SwiftUI bridge** — `ARViewContainer` is the cleanest pattern for embedding `ARView` in SwiftUI
- **USDZ model included** — `robot.usdz` is ready to run, no external assets needed
- **Plane detection + tap-to-place** — the two interactions every AR app needs, already wired up
- **Solid foundation** — extend with gestures, animations, physics, or multiple entities

## 📺 Watch on YouTube

[![Watch on YouTube](https://img.shields.io/badge/YouTube-Watch%20the%20Tutorial-red?style=for-the-badge&logo=youtube)](https://youtu.be/gq88Lw3KMJ8)

> This project was built for the [NoahDoesCoding YouTube channel](https://www.youtube.com/@NoahDoesCoding97). Subscribe for weekly SwiftUI tutorials.

---

## 🚀 Getting Started

### 1. Clone the Repo
```bash
git clone https://github.com/NDCSwift/RealityKitDemo.git
cd RealityKitDemo
```

### 2. Open in Xcode
Double-click `ARKitDemo.xcodeproj`.

### 3. Set Your Development Team
**TARGET → Signing & Capabilities → Team**

### 4. Update the Bundle Identifier
Change `com.example.MyApp` to a unique identifier.

### 5. Run on a Physical Device
ARKit requires a real iPhone or iPad — it does not work in the Simulator.

---

## 🛠️ Notes

- Add `NSCameraUsageDescription` to `Info.plist`
- ARKit requires an A9 chip or later
- If you see a code signing error, check that Team and Bundle ID are set

## 📦 Requirements

- Xcode 15+
- iOS 17+
- Real device with ARKit support (iPhone 6s or later)

📺 [Watch the guide on YouTube](https://youtu.be/gq88Lw3KMJ8)
