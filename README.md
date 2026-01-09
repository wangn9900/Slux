# Slux

基于 Flutter 的跨平台 V2Board 客户端，集成 Sing-box 核心。

## ✨ 特性

- 🖥️ **跨平台支持**: Windows、Android、macOS、iOS
- 🎨 **现代化 UI**: Material Design 3 设计语言
- 🔐 **V2Board 集成**: 完整的用户中心功能
- 🚀 **Sing-box 核心**: 高性能代理核心
- 📊 **流量统计**: 实时流量监控和历史记录
- 💳 **订阅管理**: 订单、工单、充值、邀请管理
- 🌐 **多节点支持**: 自动选择最优节点

## 📦 下载

### Windows
从 [Releases](https://github.com/wangn9900/Slux/releases) 下载最新版本

### Android
- 从 [Releases](https://github.com/wangn9900/Slux/releases) 下载 APK
- 或通过 GitHub Actions 自动构建

## 🛠️ 构建

### 前置要求

- Flutter 3.27.1+
- Dart 3.8.1+
- (Android) Android SDK & NDK
- (Windows) Visual Studio 2022

### Windows

```bash
# 1. 克隆仓库
git clone https://github.com/wangn9900/Slux.git
cd Slux

# 2. 安装依赖
flutter pub get

# 3. 下载 Sing-box 核心
./scripts/download_core.ps1

# 4. 运行
flutter run -d windows

# 5. 构建发布版
flutter build windows --release
```

### Android

**方式 1: GitHub Actions（推荐）**

1. Fork 本仓库
2. 推送代码到 `main` 分支
3. GitHub Actions 会自动编译 `libbox.so` 并构建 APK
4. 从 Actions 页面下载构建产物

**方式 2: 本地构建**

参考 [docs/ANDROID_FFI_GUIDE.md](docs/ANDROID_FFI_GUIDE.md)

```bash
# 1. 编译 libbox.so (需要 Go 和 Android NDK)
# 参考 docs/ANDROID_FFI_GUIDE.md

# 2. 构建 APK
flutter build apk --release
```

## 📖 文档

- [构建指南](docs/BUILD.md)
- [Android FFI 集成](docs/ANDROID_FFI_GUIDE.md)
- [Android 编译状态](docs/ANDROID_STATUS.md)
- [OSS 配置说明](docs/OSS_CONFIG.md)

## 🔧 配置

### V2Board API

在登录界面输入您的 V2Board 订阅地址即可。

### OSS 配置（可选）

如果您需要自定义核心更新源，请参考 [docs/OSS_CONFIG.md](docs/OSS_CONFIG.md)

## 🎯 功能清单

### 已实现

- ✅ V2Board 登录/注册
- ✅ 订阅管理
- ✅ 节点列表与切换
- ✅ 流量统计
- ✅ 订单管理
- ✅ 工单系统
- ✅ 余额充值
- ✅ 邀请管理
- ✅ 用户信息编辑
- ✅ 自动续费设置
- ✅ Windows 核心自动更新
- ✅ Android FFI 支持

### 开发中

- 🚧 iOS 支持
- 🚧 macOS 支持
- 🚧 VPN Service (Android TUN 模式)
- 🚧 系统代理设置

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## 📄 许可证

本项目仅供学习交流使用。

## 🙏 致谢

- [Flutter](https://flutter.dev/)
- [Sing-box](https://github.com/SagerNet/sing-box)
- [V2Board](https://github.com/v2board/v2board)
- [FlClash](https://github.com/chen08209/FlClash) - UI 设计参考

## ⚠️ 免责声明

本项目仅供学习和研究使用，请勿用于非法用途。使用本软件所产生的一切后果由使用者自行承担，与开发者无关。

---

**Star ⭐ 本项目以支持开发！**
