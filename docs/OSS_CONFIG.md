# OSS 配置文件说明

## api_config.json 格式

这是应用从 OSS 获取的核心配置文件，用于动态配置 V2Board API 地址和其他关键参数。

### 完整示例

```json
{
  "api_endpoints": [
    "https://panel1.example.com",
    "https://panel2.example.com",
    "https://123.45.67.89:8443"
  ],
  "backup_endpoints": [
    "https://backup1.example.com",
    "https://backup2.example.com"
  ],
  "core_version": "1.8.0",
  "notice": "系统维护通知：预计 2026-01-10 进行升级"
}
```

### 字段说明

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `api_endpoints` | `string[]` | ✅ | **主要 API 地址列表**。客户端会按顺序轮询，找到第一个可用的地址后使用。支持域名和 IP。 |
| `backup_endpoints` | `string[]` | ❌ | **备用 API 地址列表**。当主要地址全部失败时，才会尝试备用地址。 |
| `core_version` | `string` | ❌ | 当前推荐的 Sing-box 核心版本（用于显示，不影响功能）。 |
| `notice` | `string` | ❌ | 公告信息，可在应用中显示给用户。 |

### 兼容旧格式

为了向后兼容，也支持旧格式（单个 API 地址）：

```json
{
  "api_base_url": "https://panel.example.com"
}
```

客户端会自动将其转换为 `api_endpoints: ["https://panel.example.com"]`。

---

## version.json 格式

用于核心更新和资源文件管理。

### 完整示例

```json
{
  "version": "1.8.0",
  "min_app_version": "1.0.0",
  "update_message": "新版本包含性能优化和 Bug 修复",
  "files": [
    {
      "name": "sing-box-windows-amd64.zip",
      "path": "core/sing-box-windows-amd64.zip",
      "hash": "sha256:abc123...",
      "type": "core",
      "platform": "windows"
    },
    {
      "name": "sing-box-darwin-amd64.zip",
      "path": "core/sing-box-darwin-amd64.zip",
      "hash": "sha256:def456...",
      "type": "core",
      "platform": "macos"
    },
    {
      "name": "geosite.db",
      "path": "assets/geosite.db",
      "hash": "sha256:ghi789...",
      "type": "asset",
      "platform": "all"
    },
    {
      "name": "geoip.db",
      "path": "assets/geoip.db",
      "hash": "sha256:jkl012...",
      "type": "asset",
      "platform": "all"
    }
  ]
}
```

### 字段说明

| 字段 | 说明 |
|------|------|
| `version` | 核心版本号 |
| `min_app_version` | 最低支持的应用版本 |
| `update_message` | 更新说明 |
| `files[].name` | 文件名 |
| `files[].path` | OSS 上的相对路径 |
| `files[].hash` | 文件哈希（用于校验，暂未实现） |
| `files[].type` | 文件类型：`core`（核心）、`asset`（资源） |
| `files[].platform` | 平台：`windows`、`macos`、`android`、`ios`、`all` |

---

## OSS 目录结构建议

```
your-oss-bucket/slux/
├── api_config.json          # API 配置（最重要）
├── version.json             # 核心版本信息
├── core/
│   ├── sing-box-windows-amd64.zip
│   ├── sing-box-darwin-amd64.zip
│   ├── sing-box-linux-amd64.zip
│   └── wintun.dll           # Windows 专用
└── assets/
    ├── geosite.db
    └── geoip.db
```

---

## 工作流程

1. **应用启动** → 从 OSS 下载 `api_config.json`
2. **轮询 API 地址** → 测试 `api_endpoints` 中的每个地址，找到第一个可用的
3. **保存可用地址** → 写入 `SharedPreferences`，下次优先使用
4. **登录 V2Board** → 使用选定的 API 地址进行登录
5. **获取订阅** → 使用同一地址获取节点订阅
6. **核心更新** → 从 OSS 下载 `version.json`，按需更新核心文件

---

## 防封策略

1. **多域名部署**：在 `api_endpoints` 中配置多个不同的域名
2. **IP 直连**：在列表中加入 IP 地址（如 `https://123.45.67.89:8443`）
3. **备用地址**：在 `backup_endpoints` 中配置紧急备用地址
4. **动态更新**：定期更新 OSS 上的 `api_config.json`，无需发布新版本应用

---

## 安全建议

1. **HTTPS**：所有 API 地址必须使用 HTTPS
2. **OSS 访问控制**：确保 OSS 文件可公开读取（或使用签名 URL）
3. **CDN 加速**：为 OSS 配置 CDN，提高全球访问速度
4. **定期更新**：每周检查并更新 `api_config.json` 中的地址列表
