package main

import "C"

import (
	"context"
	"encoding/json"

	box "github.com/sagernet/sing-box"
	_ "github.com/sagernet/sing-box/include"
	"github.com/sagernet/sing-box/option"
)

var instance *box.Box
var ctx context.Context
var cancel context.CancelFunc

//export start
func start(configContent *C.char, tunFd C.int) *C.char {
	configJson := C.GoString(configContent)

	// 解析配置
	var options option.Options
	if err := json.Unmarshal([]byte(configJson), &options); err != nil {
		return C.CString("Config Parse Error: " + err.Error())
	}

	// 如果传入了有效的 VPN FD，注入到 tun inbound 中
	if tunFd > 0 {
		for _, inbound := range options.Inbounds {
			if inbound.Type == "tun" {
				if tunOptions, ok := inbound.Options.(*option.TunInboundOptions); ok {
					tunOptions.FileDescriptor = int(tunFd)
				}
			}
		}
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
