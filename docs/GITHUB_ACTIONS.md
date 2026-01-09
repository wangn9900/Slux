# GitHub Actions 构建指南

## 🚀 独立平台构建

现在每个平台都有独立的 GitHub Actions workflow，您可以单独触发构建，不会浪费时间在其他平台上。

## 📦 可用的构建 Workflows

### 1. **Build Android** 🤖
- **文件**: `.github/workflows/build-android.yml`
- **触发条件**:
  - 推送到 `main` 分支且修改了 `lib/`, `android/`, `pubspec.yaml`
  - 手动触发
- **构建内容**:
  - 编译 `libbox.so` (arm64-v8a, armeabi-v7a, x86_64)
  - 构建 Android APK
- **产物**:
  - `slux-android-apk` - APK 文件
  - `libbox-libraries` - 原生库文件

### 2. **Build Windows** 🪟
- **文件**: `.github/workflows/build-windows.yml`
- **触发条件**:
  - 推送到 `main` 分支且修改了 `lib/`, `windows/`, `pubspec.yaml`
  - 手动触发
- **构建内容**:
  - 下载 Sing-box 核心
  - 构建 Windows EXE
- **产物**:
  - `slux-windows-x64` - ZIP 压缩包

### 3. **Build iOS** 🍎
- **文件**: `.github/workflows/build-ios.yml`
- **触发条件**:
  - 推送到 `main` 分支且修改了 `lib/`, `ios/`, `pubspec.yaml`
  - 手动触发
- **构建内容**:
  - 构建未签名的 iOS IPA
- **产物**:
  - `slux-ios-unsigned` - 未签名 IPA

### 4. **Build macOS** 🖥️
- **文件**: `.github/workflows/build-macos.yml`
- **触发条件**:
  - 推送到 `main` 分支且修改了 `lib/`, `macos/`, `pubspec.yaml`
  - 手动触发
- **构建内容**:
  - 构建 macOS App
- **产物**:
  - `slux-macos` - ZIP 压缩包

## 🎯 手动触发构建

### 方式 1: GitHub 网页界面

1. 访问 https://github.com/wangn9900/Slux/actions
2. 选择您想要构建的平台（例如 "Build Android"）
3. 点击右侧的 "Run workflow" 按钮
4. 选择分支（通常是 `main`）
5. 点击绿色的 "Run workflow" 按钮

### 方式 2: GitHub CLI

```bash
# 构建 Android
gh workflow run build-android.yml

# 构建 Windows
gh workflow run build-windows.yml

# 构建 iOS
gh workflow run build-ios.yml

# 构建 macOS
gh workflow run build-macos.yml
```

## 📥 下载构建产物

### 从 GitHub Actions 页面

1. 访问 https://github.com/wangn9900/Slux/actions
2. 点击最新的成功构建（绿色勾号）
3. 滚动到页面底部的 "Artifacts" 部分
4. 点击对应的产物名称下载

### 使用 GitHub CLI

```bash
# 列出最新的构建产物
gh run list --workflow=build-android.yml --limit=1

# 下载产物
gh run download <run-id>
```

## ⚡ 构建时间估算

| 平台 | 预计时间 | 说明 |
|------|---------|------|
| Android | 10-15 分钟 | 包含 Go 编译和多架构 libbox.so |
| Windows | 5-8 分钟 | 包含核心下载 |
| iOS | 8-12 分钟 | 未签名构建 |
| macOS | 8-12 分钟 | 标准构建 |

## 🔧 常见问题

### Q: 为什么要分离构建？
**A**: 避免每次修改代码都要等待所有平台编译完成。例如只修改 Android 代码时，不需要等待 Windows/iOS/macOS 构建。

### Q: 如何只构建 Android？
**A**: 
1. 手动触发 "Build Android" workflow
2. 或者只修改 `android/` 目录下的文件并推送

### Q: 构建失败怎么办？
**A**: 
1. 查看 Actions 页面的错误日志
2. 检查是否是依赖问题（NDK、Flutter 版本等）
3. 重新触发构建

### Q: 如何同时构建所有平台？
**A**: 手动触发所有 4 个 workflows，它们会并行执行。

## 📝 修改记录

### 2026-01-10
- ✅ 分离四个平台的构建 workflows
- ✅ 修复 Android NDK 编译器路径问题
- ✅ 添加 CXX 编译器支持
- ✅ 优化触发条件，只在相关文件变更时构建

## 🎉 快速开始

**只想构建 Android APK？**

```bash
# 1. 访问 Actions 页面
https://github.com/wangn9900/Slux/actions

# 2. 点击 "Build Android"
# 3. 点击 "Run workflow"
# 4. 等待 10-15 分钟
# 5. 下载 APK
```

就这么简单！🚀
