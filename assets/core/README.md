# Sing-box 核心文件目录

## 说明

此目录用于存放 Sing-box 核心可执行文件，应用首次启动时会自动提取到用户数据目录。

## 如何获取核心文件

### Windows
1. 访问 [Sing-box Releases](https://github.com/SagerNet/sing-box/releases)
2. 下载 `sing-box-<version>-windows-amd64.zip`
3. 解压后将 `sing-box.exe` 放到此目录

### macOS
1. 下载 `sing-box-<version>-darwin-amd64.zip`
2. 解压后将 `sing-box` 放到此目录

### Linux
1. 下载 `sing-box-<version>-linux-amd64.zip`
2. 解压后将 `sing-box` 放到此目录

## 注意事项

- **Android/iOS 不需要此文件**（核心会编译进 App）
- 如果此目录为空，应用会尝试从 OSS 下载核心
- 建议在发布前放入对应平台的核心文件，确保用户首次安装即可使用

## 当前状态

目前此目录为空。请按照上述步骤下载并放置核心文件。
