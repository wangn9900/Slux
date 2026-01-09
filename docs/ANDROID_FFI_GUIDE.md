# Android Sing-box FFI 集成指南

本文档详细说明如何为 Slux Android 客户端集成 Sing-box 核心。由于移动端无法像 Windows 那样直接调用 EXE 文件，我们需要将 Sing-box 编译为共享库 (`.so`) 并通过 Dart FFI 进行调用。

## 1. 原理概述

- **Windows**: `Dart` -> `Process.start('sing-box.exe')`
- **Android**: `Dart` -> `FFI` -> `libbox.so` (Go build) -> `Sing-box Core`

在 Android 上，除了启动核心外，还需要处理 **VPN Service**。Android 系统要求所有流量接管必须通过 `VpnService` API 创建一个虚拟网卡 (TUN)，并将该文件描述符 (FD) 传递给 Sing-box，或者由 Sing-box 自己管理（需 Root，非 Root 必须用 VpnService）。

## 2. 编译 libbox.so

你需要编写一个 Go wrapper 来导出 C 兼容的函数。

### 2.1 准备 Go 环境
确保安装了 Go 1.21+ 和 Android NDK。

### 2.2 创建 Go Wrapper (`core/mobile/main.go`)

```go
package main

import "C"
import (
	"context"
	"os"
	
	box "github.com/sagernet/sing-box"
	"github.com/sagernet/sing-box/option"
)

var instance *box.Box
var ctx context.Context
var cancel context.CancelFunc

//export start
func start(configContent *C.char) *C.char {
	configJson := C.GoString(configContent)
	
	// 解析配置
	options, err := option.UnmarshalJSON([]byte(configJson))
	if err != nil {
		return C.CString("Config Parse Error: " + err.Error())
	}

	// 创建 Box 实例
	ctx, cancel = context.WithCancel(context.Background())
	instance, err = box.New(box.Options{
		Context: ctx,
		Options: options,
	})
	if err != nil {
		return C.CString("Create Box Error: " + err.Error())
	}

	// 启动
	if err := instance.Start(); err != nil {
		return C.CString("Start Error: " + err.Error())
	}

	return nil // Success
}

//export stop
func stop() {
	if cancel != nil {
		cancel()
	}
	if instance != nil {
		instance.Close()
		instance = nil
	}
}

// 必须包含 main 函数
func main() {}
```

### 2.3 编译命令
在 Go 项目目录下执行：

```bash
# 设置 NDK 环境 (示例)
export ANDROID_NDK_HOME=/path/to/android-sdk/ndk/25.x.xxxx

# 编译 arm64-v8a
CC=$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/darwin-x86_64/bin/aarch64-linux-android29-clang \
CGO_ENABLED=1 \
GOOS=android \
GOARCH=arm64 \
go build -buildmode=c-shared -o libbox.so main.go
```

## 3. 集成到 Flutter 项目

1. **放置 .so 文件**：
   将编译好的 `libbox.so` 复制到：
   `android/app/src/main/jniLibs/arm64-v8a/libbox.so`
   (如果是 armeabi-v7a 架构，则放在 `armeabi-v7a/` 下)

2. **Dart FFI 调用**：
   项目 `lib/core/ffi/libbox.dart` 已经定义了基本的调用接口。

3. **Android 权限配置** (`android/app/src/main/AndroidManifest.xml`)：
   ```xml
   <uses-permission android:name="android.permission.INTERNET" />
   <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
   <!-- 如果使用 VpnService -->
   <uses-permission android:name="android.permission.BIND_VPN_SERVICE" />
   ```

## 4. 关键难点：VPN Service

仅仅调用 `start` 启动 Sing-box 是不够的，因为没有流量会流向它。你需要建立 Android VpnService。

**推荐方案**：
使用 Flutter 插件 `flutter_vpn` 或编写原生 Kotlin 代码：
1. Kotlin 层启动 `VpnService`，调用 `Builder.establish()` 获取 `ParcelFileDescriptor` (TUN FD)。
2. 将这个 FD 传递给 Sing-box (这需要修改上面的 Go `start` 函数，增加一个 `fd int` 参数)。
3. 在 Sing-box 配置中，使用 `tun` inbound，并设置 `file_descriptor` 为传入的 FD（Sing-box 1.9+ 支持）。

**如果不使用 VpnService (仅代理模式)**：
如果只作为 HTTP/Socks5 代理运行，不接管系统流量：
1. 配置 Sing-box `mixed` inbound 监听本地端口（如 20808）。
2. Android 设置 Wi-Fi 代理指向 `127.0.0.1:20808`（需要用户手动设置或 Root）。

## 5. 开发建议

建议先在 Windows 模式下完善配置生成逻辑 (`ConfigGenerator`)，确保生成的 JSON 是 Sing-box 可用的。
Android 端的核心逻辑与 Windows 是一致的，只是启动方式和出站接口 (TUN) 不同。
