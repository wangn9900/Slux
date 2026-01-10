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

	// 1. Unmarshal to generic map to manipulate JSON fields directly
	var rawConfig map[string]interface{}
	if err := json.Unmarshal([]byte(configJson), &rawConfig); err != nil {
		return C.CString("JSON Map Parse Error: " + err.Error())
	}

	// 2. Inject TUN File Descriptor
	if tunFd > 0 {
		if inbounds, ok := rawConfig["inbounds"].([]interface{}); ok {
			for i, ib := range inbounds {
				if inbound, ok := ib.(map[string]interface{}); ok {
					if t, ok := inbound["type"].(string); ok && t == "tun" {
						// Inject fields recognized by sing-box JSON decoder
						inbound["file_descriptor"] = int(tunFd)
						inbound["auto_route"] = false
						inbound["interface_name"] = ""
						// Save changes
						inbounds[i] = inbound
					}
				}
			}
			// Save updated inbounds list
			rawConfig["inbounds"] = inbounds
		}
	}

	// 3. Marshal back to bytes
	newBytes, err := json.Marshal(rawConfig)
	if err != nil {
		return C.CString("JSON Remarshal Error: " + err.Error())
	}

	// 4. Unmarshal to Typed Options
	var options option.Options
	if err := json.Unmarshal(newBytes, &options); err != nil {
		return C.CString("Final Config Parse Error: " + err.Error())
	}

	// 5. Create Box
	ctx, cancel = context.WithCancel(context.Background())
	var createErr error
	instance, createErr = box.New(box.Options{
		Context: ctx,
		Options: options,
	})
	if createErr != nil {
		return C.CString("Create Box Error: " + createErr.Error())
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
