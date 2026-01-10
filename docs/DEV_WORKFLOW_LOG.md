# 开发工作流记录 (DEV_WORKFLOW_LOG)
> 最后更新时间: 2026-01-10

## 1. 登录界面重构 (Login UI Refactor)
- **目标**: 优化视觉体验，适应小窗口布局，去除滚动条。
- **改动**:
  - 窗口默认大小调整为 `750x580`。
  - 登录卡片采用单列紧凑布局。
  - Logo 缩小并集成至卡片内部 (56x56)。
  - 移除不必要的垂直间距，确保所有内容在无滚动条情况下完全展示。
  - 增加“记住账号”、“显示密码”功能。
  - 实现登录、注册、找回密码的完整流程切换。
  - 视觉优化：深色背景 + 白色卡片，提升层次感。

## 2. CI/CD 工作流调整
- **目标**: 节省构建资源，避免频繁自动触发。
- **改动**:
  - 修改 `.github/workflows/*.yml` (Android, iOS, Windows, macOS)。
  - 禁用 `push` 和 `pull_request` 的自动触发。
  - 仅保留 `workflow_dispatch` (手动触发)。
  - 优化 Android 构建图标生成步骤 (使用静态资源代替动态绘图，解决ImageMagick兼容性问题)。

## 3. 核心功能修复 (Core Fixes)
### 3.1 仪表盘生命周期修复
- **问题**: `DashboardScreen` 销毁时 (`dispose`) 异步回调触发 `setState` 导致 `_ElementLifecycle.defunct` 断言错误。
- **修复**: 
  - `_stopTrafficMonitor` 增加 `fromDispose` 标志。
  - `initState` 中的异步逻辑增加 `mounted` 检查。

### 3.2 流量数据显示修复
- **问题**: V2Board API 返回的流量数据有时为字符串，有时为整数，导致解析失败；API 数据更新滞后。
- **修复**:
  - `ProfilesScreen` 使用 `int.tryParse` 增强类型安全性。
  - **精准流量获取**: 新增 `fetchTrafficFromSubscriptionUrl` 方法，直接请求订阅链接头部 (`HEAD` 请求获取 `Subscription-Userinfo`)。
  - 数据合并策略：优先使用 Header 数据 > 订阅 API 数据 > 用户信息 API 数据。

### 3.3 代码误删恢复
- **问题**: 之前的批量替换操作意外删除了 `DashboardScreen` 中的 `_loadNodesFromV2Board` 等关键方法。
- **修复**: 已完整恢复相关方法，功能恢复正常。

## 4. UI 视觉微调
- **目标**: 统一深色模式视觉风格。
- **改动**:
  - `DashboardScreen` 的“上行/下行”状态卡片背景由白色改为深色半透明 (`Theme.surface.withOpacity(0.5)`)。
  - “规则/全局”切换按钮背景同步调整为深色半透明。
  - 选中状态使用高亮色，提升可读性。

## 5. 待办事项 (TODO)
- [ ] 验证注册流程的邮件发送功能稳定性。
- [ ] 进一步测试不同订阅源的流量头部格式兼容性。
- [ ] 检查桌面端在极小窗口下的响应式表现。

## 6. 明日计划 (2026-01-11)
### 6.1 静默订阅自动更新 (Silent Auto-Update)
- **核心逻辑**: 检测后端配置变更，实现客户端即时感知更新。
- **具体要求**:
  - **全量检测**: 监控节点名称、域名、IP地址等所有关键属性的变化。
  - **自动同步**: 
    - 客户端启动检测逻辑（可能是轮询 `checkServerUpdate` 或 Headers ETag 对比）。
    - 若发现变化：立即静默更新本地配置文件，不打扰用户。
    - 若无变化：保持现有配置。

### 6.2 广告拦截系统 (Ad Blocking)
- **核心功能**: 移植 Hiddify (hiddfly) 的广告拦截方案。
- **具体实施**:
  - **UI 入口**: 在设置页面增加“开启广告拦截”的 Toggle 开关。
  - **底层实现**: 
    - 集成广告拦截规则集 (Rule Sets, e.g., adguard, anti-ad)。
    - 配置 Sing-box 的 DNS 规则和路由规则，将广告域名指向 `reject` 或 `block`。
