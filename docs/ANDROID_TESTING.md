# Android 端功能验证清单

## ✅ 编译后应该能正常使用

### 已实现的核心功能

#### 1. **VPN Service (TUN 模式)** ✅
- ✅ `SluxVpnService.kt` - Android VPN 服务
- ✅ `MainActivity.kt` - VPN 权限请求
- ✅ `VpnManager.dart` - Dart-Kotlin 通信
- ✅ `AndroidManifest.xml` - VPN 权限和服务注册

**预期行为**:
```
用户点击连接
↓
[首次] 弹出 VPN 权限请求
↓
用户授权
↓
显示 "VPN 连接已激活" 通知
↓
创建 TUN 设备 (10.0.0.2/24)
↓
全局流量接管成功
```

#### 2. **FFI 集成** ✅
- ✅ `libbox.dart` - FFI 绑定
- ✅ `MobileSingboxService` - 移动端服务
- ✅ `libbox.so` - 通过 GitHub Actions 编译

**预期行为**:
```
VPN 启动后
↓
获取 TUN FD
↓
调用 LibBox.start(config)
↓
Sing-box 核心启动
↓
流量开始代理
```

#### 3. **V2Board 集成** ✅
- ✅ 登录/注册
- ✅ 订阅管理
- ✅ 节点列表
- ✅ 流量统计
- ✅ 用户中心全功能

## 🧪 测试步骤

### 第一次启动

1. **安装 APK**
   ```bash
   adb install app-release.apk
   ```

2. **打开应用**
   - 应该看到登录界面
   - UI 应该正常显示

3. **登录**
   - 输入 V2Board 订阅地址
   - 输入邮箱和密码
   - 点击登录
   - 应该成功进入主界面

4. **查看节点列表**
   - 进入 "Proxies" 页面
   - 应该显示订阅的节点列表
   - 可以选择节点

5. **首次连接**
   - 点击 "连接" 按钮
   - **关键**: 应该弹出 VPN 权限请求
   - 点击 "确定" 授权
   - 应该显示 "VPN 连接已激活" 通知
   - 状态栏应该显示 VPN 图标 🔑

6. **验证连接**
   - 打开浏览器访问 `https://ip.sb`
   - IP 应该是代理节点的 IP
   - 流量统计应该开始增加

7. **断开连接**
   - 点击 "断开" 按钮
   - VPN 通知应该消失
   - 状态栏 VPN 图标应该消失

### 后续使用

1. **再次连接**
   - 不应该再弹出权限请求
   - 直接连接成功

2. **切换节点**
   - 选择其他节点
   - 断开 → 重新连接
   - 应该使用新节点

3. **流量统计**
   - 进入 "流量明细"
   - 应该显示使用记录

4. **用户中心**
   - 订单管理 ✅
   - 工单系统 ✅
   - 余额充值 ✅
   - 邀请管理 ✅

## ⚠️ 可能遇到的问题

### 问题 1: VPN 权限被拒绝
**现象**: 点击连接后提示 "Failed to start VPN service"

**原因**: 用户拒绝了 VPN 权限

**解决**:
1. 进入系统设置 → 应用 → Slux
2. 权限 → VPN → 允许
3. 重新打开应用

### 问题 2: libbox.so 加载失败
**现象**: 应用崩溃，日志显示 "DynamicLibrary.open('libbox.so') failed"

**原因**: GitHub Actions 编译的 libbox.so 不存在或架构不匹配

**解决**:
1. 检查 APK 内是否包含 `lib/arm64-v8a/libbox.so`
2. 确认设备架构与编译的架构匹配
3. 重新触发 GitHub Actions 构建

### 问题 3: 配置生成错误
**现象**: 连接时提示 "Config Parse Error"

**原因**: Sing-box 配置格式不正确

**解决**:
1. 检查 `ConfigGenerator` 生成的配置
2. 确认节点信息完整
3. 查看日志中的详细错误信息

### 问题 4: 连接成功但无法上网
**现象**: VPN 已连接，但浏览器无法访问网站

**可能原因**:
1. DNS 设置问题
2. 路由表配置问题
3. 节点本身不可用

**解决**:
1. 检查 VPN 配置中的 DNS (应该是 1.1.1.1 和 8.8.8.8)
2. 检查路由表 (应该是 0.0.0.0/0)
3. 尝试切换其他节点

## 📊 预期性能

| 指标 | 预期值 |
|------|--------|
| 启动时间 | 2-3 秒 |
| VPN 连接时间 | 1-2 秒 |
| 节点切换时间 | 2-3 秒 |
| 内存占用 | 80-150 MB |
| 电池消耗 | 中等 (VPN 服务) |

## 🔍 调试方法

### 查看日志

```bash
# 实时查看应用日志
adb logcat | grep -i "slux\|singbox\|vpn"

# 查看 Flutter 日志
adb logcat | grep -i "flutter"

# 查看崩溃日志
adb logcat | grep -E "FATAL|AndroidRuntime"
```

### 检查 VPN 状态

```bash
# 查看 VPN 接口
adb shell ip addr show tun0

# 查看路由表
adb shell ip route

# 查看 DNS
adb shell getprop | grep dns
```

## ✅ 功能完整性检查

编译成功后，以下功能应该全部可用：

- [x] 登录/注册
- [x] 订阅管理
- [x] 节点列表显示
- [x] 节点选择
- [x] VPN 权限请求
- [x] VPN 连接/断开
- [x] 全局流量代理
- [x] 流量统计
- [x] 订单管理
- [x] 工单系统
- [x] 余额充值
- [x] 邀请管理
- [x] 用户信息编辑
- [x] 自动续费设置

## 🎯 总结

**理论上编译成功后应该能正常使用**，因为：

1. ✅ 所有必要的 Kotlin 代码已实现
2. ✅ VPN Service 完整配置
3. ✅ FFI 绑定正确
4. ✅ Dart 逻辑完整
5. ✅ 权限配置正确
6. ✅ GitHub Actions 会编译 libbox.so

**但建议**:
1. 先在模拟器或测试机上测试
2. 检查日志确认没有运行时错误
3. 验证 VPN 连接和流量代理
4. 测试所有核心功能

**如果遇到问题**:
1. 查看 `adb logcat` 日志
2. 检查 GitHub Actions 构建产物
3. 确认 libbox.so 正确打包

---

**最后更新**: 2026-01-10 01:40
