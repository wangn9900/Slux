package mobile

import (
	"github.com/sagernet/sing-box/experimental/libbox"
	_ "github.com/sagernet/sing-box/include"
)

// NewService is a wrapper for libbox.NewService.
// It ensures that the 'include' package is imported and linked, registering all Sing-box features.
// Use this method from Java/Kotlin instead of calling libbox.NewService directly.
func NewService(config string, platform libbox.PlatformInterface) (*libbox.Service, error) {
	return libbox.NewService(config, platform)
}
