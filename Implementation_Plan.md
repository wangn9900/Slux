# Slux Project Implementation Plan (Flutter Edition)

## 1. Project Overview
**Slux** is a premium, cross-platform Sing-box client designed to deeply integrate with V2Board.
- **Core Strategy**: Utilize the official `sing-box` binary for core proxy functionality (Daemon mode).
- **Framework**: Flutter (Dart) for cross-platform UI (Windows focus first, extensible to Android/macOS/Linux).
- **Design Objective**: High-fidelity, dark-themed UI (Glassmorphism) similar to MOMclash.
- **Backend Integration**: Direct API integration with V2Board (User, Comm, Subscribe).

## 2. Technical Stack
- **UI**: Flutter with Material 3 (Customized), Google Fonts, Lucide Icons.
- **State Management**: Flutter Riverpod.
- **Routing**: GoRouter.
- **Network**: Dio (for V2Board API).
- **Core Interaction**: `dart:io` Process API (managing `sing-box` subprocess).
- **Storage**: Shared Preferences (Settings), Hive (optional for detailed logs/stats).
- **Windowing**: `window_manager` for hidden title bar and frameless design.

## 3. Architecture Phase
### Phase 1: Foundation (Current)
- [x] Dispose Electron project.
- [x] Initialize Flutter project.
- [ ] Setup dependencies (`riverpod`, `dio`, `window_manager`...).
- [ ] Implement `MainLayout` with custom Sidebar and Window Controls.

### Phase 2: Core Integration
- [ ] **Sing-box Service**:
    - Download/Check for `sing-box.exe` existence.
    - Start/Stop `sing-box` process with specific config.
    - Capture `stdout` for logs.
- [ ] **Config Gen**:
    - Convert internal functional models into Sing-box JSON Configuration.
    - Support VLESS, VMess, Trojan, Shadowsock protocols (from V2Board).

### Phase 3: V2Board Integration
- [ ] **Auth Flow**: Login with V2Board credentials.
- [ ] **Fetch Data**: Get User Info (Traffic), Server List.
- [ ] **Dashboard**: Show real-time traffic usage and subscription status.

### Phase 4: Polish
- [ ] **Latency Test**: `http` ping to nodes.
- [ ] **Tun Mode**: Helper for admin privileges on Windows.
- [ ] **System Tray**: Minimize to tray.

## 4. Directory Structure
(Root: `e:\GitHub\Slux`)
```
lib/
  main.dart           # Entry point
  core/
    singbox_service.dart
  data/
    api/              # V2Board API Client
  ui/
    theme/            # Colors & Styles
    layouts/          # Main App Shell
    screens/          # Dashboard, Proxies, Profiles, Settings
    widgets/          # Reusable components
pubspec.yaml          # Dependencies
windows/              # Windows native runner
android/              # Android native runner
client/               # [DEPRECATED] Old Electron folder, please delete manually.
```
