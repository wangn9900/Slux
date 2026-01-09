# Android 端编译状态报告

## ✅ 已完成的工作

### 1. Dart 代码层 (100% 完成)
- ✅ **FFI 绑定**: `lib/core/ffi/libbox.dart` 已实现
- ✅ **服务抽象**: `lib/services/singbox_service.dart` 定义了 `ISingboxService` 接口
- ✅ **桌面实现**: `DesktopSingboxService` (使用 `Process.start`)
- ✅ **移动实现**: `MobileSingboxService` (使用 FFI 调用 `libbox.so`)
- ✅ **依赖配置**: `pubspec.yaml` 已添加 `ffi: ^2.1.0`

### 2. Android 配置 (100% 完成)
- ✅ **权限配置**: `AndroidManifest.xml` 已添加：
  - `INTERNET` - 网络访问
  - `ACCESS_NETWORK_STATE` - 网络状态
  - `BIND_VPN_SERVICE` - VPN 服务（TUN 模式必需）
  - `FOREGROUND_SERVICE` - 前台服务
  - `FOREGROUND_SERVICE_SPECIAL_USE` - 特殊用途前台服务
- ✅ **Gradle 配置**: `build.gradle.kts` NDK 版本已配置
- ✅ **包名**: `com.slux.slux`

### 3. 文档 (100% 完成)
- ✅ `docs/ANDROID_FFI_GUIDE.md` - 详细的 FFI 集成指南
- ✅ `docs/BUILD.md` - 构建文档
- ✅ `docs/OSS_CONFIG.md` - OSS 配置说明

## ⚠️ 待完成的工作

### 1. Native Library (关键！)
**状态**: ❌ 缺失

**需要做的事情**:
1. 编译 `libbox.so` (参考 `docs/ANDROID_FFI_GUIDE.md`)
2. 放置到以下目录：
   ```
   android/app/src/main/jniLibs/
   ├── arm64-v8a/libbox.so      (主流 64 位设备)
   ├── armeabi-v7a/libbox.so    (老旧 32 位设备)
   ├── x86_64/libbox.so         (模拟器)
   └── x86/libbox.so            (老旧模拟器)
   ```

**编译方式**:
- **本地编译**: 参考 `docs/ANDROID_FFI_GUIDE.md` 第 2.3 节
- **GitHub Actions**: 推荐使用 CI/CD 自动编译（见下文）

### 2. VPN Service (可选，取决于使用模式)
**状态**: ❌ 未实现

**两种运行模式**:

#### 模式 A: 全局代理 (TUN 模式) - 推荐
- **需要**: 实现 Android `VpnService`
- **优点**: 接管所有应用流量，用户体验最佳
- **实现**: 需要编写 Kotlin 代码创建 TUN 设备并传递 FD 给 Sing-box

#### 模式 B: 手动代理 (Socks/HTTP 模式) - 简单
- **需要**: 无需 VpnService
- **缺点**: 用户需要手动设置 Wi-Fi 代理
- **配置**: Sing-box 使用 `mixed` inbound 监听本地端口

**当前代码支持**: 模式 B（无需额外开发）

## 📋 GitHub Actions 编译建议

创建 `.github/workflows/build-android.yml`:

```yaml
name: Build Android

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  build-libbox:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Go
        uses: actions/setup-go@v5
        with:
          go-version: '1.22'
      
      - name: Setup Android NDK
        uses: nttld/setup-ndk@v1
        with:
          ndk-version: r25c
      
      - name: Build libbox.so for arm64-v8a
        run: |
          cd core/mobile  # 你的 Go wrapper 目录
          export ANDROID_NDK_HOME=$ANDROID_NDK
          CC=$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android29-clang \
          CGO_ENABLED=1 GOOS=android GOARCH=arm64 \
          go build -buildmode=c-shared -o libbox.so main.go
          
      - name: Copy to jniLibs
        run: |
          mkdir -p android/app/src/main/jniLibs/arm64-v8a
          cp core/mobile/libbox.so android/app/src/main/jniLibs/arm64-v8a/
      
      - name: Build Flutter APK
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.27.1'
      - run: flutter pub get
      - run: flutter build apk --release
      
      - name: Upload APK
        uses: actions/upload-artifact@v4
        with:
          name: slux-android
          path: build/app/outputs/flutter-apk/app-release.apk
```

## 🧪 本地测试步骤

### 方案 1: 使用模拟器 (推荐)
```bash
# 1. 启动 Android 模拟器
flutter emulators --launch <emulator_id>

# 2. 运行应用
flutter run -d <device_id>
```

### 方案 2: 真机调试
```bash
# 1. 启用 USB 调试
# 2. 连接设备
adb devices

# 3. 运行
flutter run
```

## ⚠️ 当前限制

1. **无法直接运行**: 缺少 `libbox.so`，应用会在调用 `LibBox.start()` 时崩溃
2. **编译会成功**: Dart 代码层面没有问题，APK 可以正常打包
3. **运行时错误**: 启动代理时会报 `DynamicLibrary.open('libbox.so')` 失败

## ✅ 验证清单

在提交到 GitHub Actions 之前，请确认：

- [ ] `pubspec.yaml` 包含 `ffi: ^2.1.0` ✅ (已完成)
- [ ] `AndroidManifest.xml` 包含必要权限 ✅ (已完成)
- [ ] `lib/services/singbox_service.dart` 正确导入 `libbox.dart` ✅ (已完成)
- [ ] Go wrapper 代码已准备 (`core/mobile/main.go`) ❌ (需要创建)
- [ ] `jniLibs` 目录存在且包含 `.so` 文件 ❌ (需要编译)
- [ ] GitHub Actions workflow 已配置 ❌ (可选)

## 📝 总结

**Dart 代码层面**: ✅ 100% 就绪，可以直接编译 APK

**Native 层面**: ❌ 需要提供 `libbox.so`

**推荐路径**:
1. 先在本地编译一个 `libbox.so` 测试基本功能
2. 验证 FFI 调用正常后，再配置 GitHub Actions 自动化编译
3. 如果需要 TUN 模式，后续再实现 VpnService

**当前可以做的**:
- ✅ 编译 APK（会成功）
- ✅ 安装到设备（会成功）
- ❌ 启动代理（会崩溃，因为缺少 .so）

---
*最后更新: 2026-01-10*
