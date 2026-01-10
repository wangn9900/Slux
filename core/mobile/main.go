package main

import "C"

import (
	"context"
	"encoding/json"
	"runtime/debug"
	"time"

	box "github.com/sagernet/sing-box"
	"github.com/sagernet/sing-box/include"
	"github.com/sagernet/sing-box/option"
)

var (
	instance *box.Box
	ctx      context.Context
	cancel   context.CancelFunc
)

func init() {
	// 调整 GC 频率，避免在移动设备上过于频繁的 GC 导致丢包或卡顿
	debug.SetGCPercent(20)
}

//export start
func start(configContent *C.char, tunFd C.int) *C.char {
	// 防止重复启动
	if instance != nil {
		stop()
	}

	configJson := C.GoString(configContent)

	// 1. 初始化 Context (包含所有 Registry)
	// Sing-box 的 include 包会在 init() 时注册所有标准功能
	ctx, cancel = context.WithCancel(include.Context(context.Background()))

	// 2. 解析 JSON 到 map 以便进行 fd 注入
	var rawConfig map[string]interface{}
	if err := json.Unmarshal([]byte(configJson), &rawConfig); err != nil {
		return C.CString("JSON Parse Error: " + err.Error())
	}

	// 3. 注入 Android TUN 文件描述符
	if tunFd > 0 {
		if inbounds, ok := rawConfig["inbounds"].([]interface{}); ok {
			for i, ib := range inbounds {
				if inbound, ok := ib.(map[string]interface{}); ok {
					if t, ok := inbound["type"].(string); ok && t == "tun" {
						inbound["file_descriptor"] = int(tunFd)
						// 禁用 auto_route，因为 Android VpnService 已经处理了路由
						inbound["auto_route"] = false
						inbound["interface_name"] = ""
						// inbound["platform"] = map[string]interface{}{"http_proxy": map[string]interface{}{"enabled": false}}
						inbounds[i] = inbound
					}
				}
			}
			rawConfig["inbounds"] = inbounds
		}
	}

	// 4. 重新序列化
	finalBytes, err := json.Marshal(rawConfig)
	if err != nil {
		return C.CString("JSON Marshal Error: " + err.Error())
	}

	// 5. 解析为 Typed Options (Context-Aware)
	var options option.Options
	// 使用 UnmarshalJSONContext 确保 DNS Transport 等能正确推断
	if err := options.UnmarshalJSONContext(ctx, finalBytes); err != nil {
		return C.CString("Context Unmarshal Error: " + err.Error())
	}

	// 强制 Console 输出日志
	if options.Log == nil {
		options.Log = &option.LogOptions{}
	}
	options.Log.Output = "console"

	// 6. 创建 Sing-box 实例
	var createErr error
	instance, createErr = box.New(box.Options{
		Context: ctx,
		Options: options,
	})
	if createErr != nil {
		return C.CString("Box Create Error: " + createErr.Error())
	}

	// 7. 启动
	if err := instance.Start(); err != nil {
		instance.Close()
		instance = nil
		return C.CString("Box Start Error: " + err.Error())
	}

	// 给一点时间让日志输出
	time.Sleep(100 * time.Millisecond)

	return nil
}

//export stop
func stop() {
	if cancel != nil {
		cancel()
		cancel = nil
	}
	if instance != nil {
		instance.Close()
		instance = nil
	}
	// 强制释放内存
	debug.FreeOSMemory()
}

func main() {}
