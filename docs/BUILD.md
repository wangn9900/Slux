# 构建指南

## 快速开始

### 方式一：使用自动化脚本（推荐）

```powershell
# 自动下载核心并构建（Debug 模式）
.\scripts\build.ps1

# 构建 Release 版本
.\scripts\build.ps1 -Release

# 跳过核心下载（如果已有核心文件）
.\scripts\build.ps1 -SkipDownload
```

### 方式二：手动步骤

```powershell
# 1. 下载核心
.\scripts\download_core.ps1

# 2. 获取依赖
flutter pub get

# 3. 构建
flutter build windows --release
```

### 方式三：仅运行（开发模式）

```powershell
# 下载核心
.\scripts\download_core.ps1

# 运行
flutter run -d windows
```

---

## 脚本说明

### download_core.ps1

自动从 GitHub 下载最新的 Sing-box 核心文件到 `assets/core/` 目录。

**参数：**
- `-Version <版本号>`: 指定版本（默认 latest）
- `-Platform <平台>`: 指定平台（windows/macos/linux，默认 windows）

**示例：**
```powershell
# 下载最新版本（Windows）
.\scripts\download_core.ps1

# 下载指定版本
.\scripts\download_core.ps1 -Version "1.8.0"

# 下载 macOS 版本
.\scripts\download_core.ps1 -Platform macos
```

### build.ps1

自动化构建脚本，集成核心下载、依赖获取和应用构建。

**参数：**
- `-Platform <平台>`: 目标平台（windows/macos/linux，默认 windows）
- `-Release`: 构建 Release 版本（默认 Debug）
- `-SkipDownload`: 跳过核心下载

**示例：**
```powershell
# Debug 构建
.\scripts\build.ps1

# Release 构建
.\scripts\build.ps1 -Release

# 跳过下载，直接构建
.\scripts\build.ps1 -SkipDownload -Release
```

---

## 构建输出

### Windows
- **Debug**: `build\windows\x64\runner\Debug\slux.exe`
- **Release**: `build\windows\x64\runner\Release\slux.exe`

### macOS
- **Debug**: `build\macos\Build\Products\Debug\Slux.app`
- **Release**: `build\macos\Build\Products\Release\Slux.app`

### Linux
- **Debug**: `build\linux\x64\debug\bundle\slux`
- **Release**: `build\linux\x64\release\bundle\slux`

---

## 常见问题

### Q: 下载核心失败怎么办？

**A:** 如果自动下载失败（网络问题），可以手动下载：

1. 访问 [Sing-box Releases](https://github.com/SagerNet/sing-box/releases)
2. 下载对应平台的 ZIP 文件
3. 解压后将 `sing-box.exe`（或 `sing-box`）放到 `assets\core\` 目录
4. 运行 `.\scripts\build.ps1 -SkipDownload`

### Q: 如何更新核心版本？

**A:** 删除 `assets\core\` 中的旧文件，重新运行 `.\scripts\download_core.ps1`

### Q: 构建时提示找不到核心文件？

**A:** 确保 `assets\core\` 目录中有 `sing-box.exe`（Windows）或 `sing-box`（macOS/Linux）

### Q: 如何在 CI/CD 中使用？

**A:** 在 CI 脚本中添加：

```yaml
# GitHub Actions 示例
- name: Download Sing-box Core
  run: |
    pwsh -File scripts/download_core.ps1 -Platform windows
    
- name: Build Application
  run: |
    flutter build windows --release
```

---

## 开发工作流

### 日常开发
```powershell
# 首次运行：下载核心
.\scripts\download_core.ps1

# 后续开发：直接运行
flutter run -d windows
```

### 发布构建
```powershell
# 一键构建 Release 版本
.\scripts\build.ps1 -Release

# 或分步执行
.\scripts\download_core.ps1
flutter build windows --release
```

---

## 注意事项

1. **网络要求**：下载脚本需要访问 GitHub，如遇网络问题可使用代理或手动下载
2. **权限要求**：PowerShell 脚本可能需要执行权限，运行 `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`
3. **平台差异**：
   - Windows: 生成 `.exe` 文件
   - macOS: 生成 `.app` 包
   - Linux: 生成可执行文件
4. **核心更新**：建议定期更新 Sing-box 核心以获得最新特性和安全修复
