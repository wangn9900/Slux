package main

import "C"

import (
	"runtime/debug"
	"time"

	"github.com/sagernet/sing-box/experimental/libbox"
)

var (
	instance *libbox.Service
)

func init() {
	debug.SetGCPercent(20)
}

// 简单的 PlatformInterface 实现
type SluxPlatform struct {
	tunFd int
}

func (p *SluxPlatform) UsePlatformAutoDetectInterfaceControl() bool {
	return false
}

func (p *SluxPlatform) AutoDetectInterfaceControl(fd int) error {
	return nil
}

func (p *SluxPlatform) OpenTun(options *libbox.TunOptions) (int, error) {
	// 核心逻辑：当 Sing-box 请求 TUN 时，返回我们从 Android 拿到的 FD
	return p.tunFd, nil
}

func (p *SluxPlatform) WriteLog(message string) {
	// 这里可以桥接日志到 Java，或者直接打印到 Stdout (logcat)
	println(message)
}

func (p *SluxPlatform) UseProcFS() bool {
	return false // Android 通常没有完整的 ProcFS 访问权限
}

func (p *SluxPlatform) FindConnectionOwner(ipProtocol int, srcAddress string, srcPort int, destAddress string, destPort int) (int, error) {
	return 0, nil // 可选实现
}

func (p *SluxPlatform) PackageNameByUid(uid int) (string, error) {
	return "", nil
}

func (p *SluxPlatform) UidByPackageName(packageName string) (int, error) {
	return 0, nil
}

//export start
func start(configContent *C.char, tunFd C.int) *C.char {
	if instance != nil {
		instance.Close()
		instance = nil
	}

	configJson := C.GoString(configContent)

	// 创建 Platform 实现，注入 FD
	platform := &SluxPlatform{
		tunFd: int(tunFd),
	}

	// 使用 libbox 启动。libbox 会自动处理 Context, Registry, DNS 等所有事情！
	// 注意：NewService 后需要调用 Start
	service, err := libbox.NewService(configJson, platform)
	if err != nil {
		return C.CString("Libbox NewService Error: " + err.Error())
	}

	if err := service.Start(); err != nil {
		service.Close()
		return C.CString("Libbox Start Error: " + err.Error())
	}

	instance = service

	// 给点时间初始化
	time.Sleep(100 * time.Millisecond)

	return nil
}

//export stop
func stop() {
	if instance != nil {
		instance.Close()
		instance = nil
	}
	debug.FreeOSMemory()
}

//export debug_version
func debug_version() *C.char {
	return C.CString("Sing-box 1.12.15 Libbox Native Mode")
}

func main() {}
