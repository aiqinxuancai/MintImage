# MintImage CLI 参数、配置与 JSON 协议参考

## 子命令

| 命令 | 说明 |
| --- | --- |
| `mint-image generate [选项]` | 执行文生图或图生图（也可省略 `generate` 直接传选项，推荐显式书写） |
| `mint-image profiles [选项]` | 以 JSON 列出桌面端已保存的生图配置（不输出密钥、不联网） |
| `mint-image --help` / `mint-image profiles --help` | 输出帮助文本并退出 `0`（无参运行同 `--help`） |

## 完整参数表

配置优先级：**命令行参数 > `MINT_IMAGE_*` 环境变量 > MintImage 已保存配置 > 默认值**。

| 参数 | 简写 | 环境变量 | 允许值 / 默认值 | 说明 |
| --- | --- | --- | --- | --- |
| `--profile` | — | — | 默认桌面端当前选中配置 | 按完整 ID（优先）或完整名称精确选择已保存配置；同名冲突时须用 ID |
| `--settings-file` | — | `MINT_IMAGE_SETTINGS_FILE` | 自动查找桌面端路径 | 显式指定配置文件；同时适用于 `generate` 和 `profiles` |
| `--app-config` / `--no-app-config` | — | — | 默认开启 | 禁用自动读取桌面配置；`--no-app-config` 不可与 `--profile` 或 `--settings-file` 同用 |
| `--base-url` | — | `MINT_IMAGE_BASE_URL` | 继承配置；无配置时 `https://api.openai.com` | 仅限 `http`/`https`，不可含凭据/查询参数/片段；末尾 `/` 与 `/v1` 自动规范化 |
| `--api-key` | — | `MINT_IMAGE_API_KEY` | 继承配置；必填 | 禁止含换行；强烈建议复用桌面配置或通过环境变量传入 |
| `--model` | `-m` | `MINT_IMAGE_MODEL` | 继承配置；无配置时 `images`/`images_async` 为 `gpt-image-2`，`responses` 为 `gpt-5.5` | 仅覆盖本次请求模型，不改写桌面配置 |
| `--api-mode` | — | — | `images`、`images_async`、`responses`；继承配置，默认 `images` | API 协议模式 |
| `--reasoning-effort` | — | — | `default`、`none`、`minimal`、`low`、`medium`、`high`、`xhigh`、`max` | 仅适用于 `responses`；省略时继承配置，`default` 使用模型默认值 |
| `--prompt` | `-p` | — | 与 `--prompt-file` 二选一 | 提示词文本 |
| `--prompt-file` | — | — | UTF-8 文件路径或 `-`（stdin） | 自动去除 UTF-8 BOM 并裁剪首尾空白 |
| `--image` | — | — | 可重复；不按逗号分割 | 参考图路径；提供后调用图生图；禁止为空文件或 `.svg` |
| `--size` | — | — | 正整数 `宽x高` 或 `auto`；默认 `1024x1024` | 目标像素尺寸（不继承桌面端上次设置） |
| `--quality` | — | — | `auto`（默认）、`low`、`medium`、`high`、`xhigh`、`max` | 画质档位（不继承桌面端上次设置） |
| `--format` | — | — | `png`（默认）、`jpeg`、`webp`、`gif`、`svg` | 输出格式（不继承桌面端上次设置） |
| `--complexity` | — | — | `low`、`medium`、`high`；默认不发送 | GPT Image 2.6 规划复杂度；仅 Images API |
| `--frame-count` | — | — | `2`–`64`，默认 `9` | GIF 帧数；仅适用于 `--format gif` |
| `--frame-duration-ms` | — | — | `20`–`2000`，默认 `200` | GIF 每帧毫秒数（服务端按 10 ms 取整）；仅适用于 `--format gif` |
| `--svg-model` | — | — | 默认不发送 | 自定义 SVG 绘制模型 ID；仅适用于 `--format svg` |
| `--svg-reasoning-effort` | — | — | `none`、`minimal`、`low`、`medium`、`high`、`xhigh`、`max` | SVG 推理强度；需同时指定 `--format svg` 与非空 `--svg-model` |
| `--markup` | — | — | 透明 PNG 路径 | 针对第一张 `--image` 的标注层；仅 Images API 图生图 |
| `--safety-identifier` | — | — | 最多 128 字符；继承配置 | 匿名安全标识（OpenRouter 映射至 `user` 字段） |
| `--count` | — | — | 正整数，默认 `1` | 独立生成任务数（每个任务固定 `n=1`） |
| `--parallel` | — | — | 正整数，默认 `1` | 最大并发任务数，实际并发为 `min(parallel, count)` |
| `--timeout` | — | — | 正整数秒；继承桌面端全局设置，默认 `600` | 单任务总超时（含生图、异步轮询与图片 URL 下载） |
| `--output` | `-o` | — | 文件路径 | 单张输出路径；仅 `--count 1`，禁与 `--output-dir` 同用，拒绝覆盖 |
| `--output-dir` | — | — | 目录路径，默认 `./mint-image-output` | 自动创建目录并做可写性探测，输出 `mint-<uuid>-<task>-<imgIdx>.<ext>` |
| `--stream` / `--no-stream` | — | — | 继承配置；无配置时关闭 | 流式开关（`images_async`、`gif`、`svg` 会自动关闭本次流式） |
| `--help` | `-h` | — | — | 显示帮助并退出 `0` |

## 桌面端配置文件自动查找路径

| 平台 | 自动读取路径 |
| --- | --- |
| Windows | `%APPDATA%\com.aiqin\MintImage\shared_preferences.json`（若 `APPDATA` 缺失则回退至 `%USERPROFILE%\AppData\Roaming\...`） |
| macOS | 按顺序查找：`~/Library/Containers/com.aiqin.mintImage/Data/Library/Preferences/com.aiqin.mintImage.plist`，其次 `~/Library/Preferences/com.aiqin.mintImage.plist` |

`--settings-file` / `MINT_IMAGE_SETTINGS_FILE` 支持三种格式：Windows `shared_preferences.json`、macOS `.plist`（仅在 macOS 上经 `/usr/bin/plutil` 转换）、或包含 `profiles` 数组的原始 `SettingsModel` JSON。

## JSON 输出协议

除 `--help` 外，`stdout` 仅输出一份完整 UTF-8 JSON。

### 1. `profiles` 成功输出

找到配置时：

```json
{
  "ok": true,
  "settings_file": "/absolute/path/to/shared_preferences.json",
  "active_profile_id": "profile-id",
  "request_timeout_seconds": 600,
  "profiles": [
    {
      "id": "profile-id",
      "name": "我的生图配置",
      "base_url": "https://api.tryaigc.cn",
      "model": "gpt-image-2",
      "api_mode": "images",
      "stream": false,
      "is_active": true,
      "has_api_key": true
    }
  ]
}
```

未找到已保存配置时（仍返回退出码 `0`）：

```json
{
  "ok": true,
  "settings_file": null,
  "active_profile_id": null,
  "profiles": [],
  "message": "未找到已保存的 MintImage 生图配置。"
}
```

### 2. `generate` 成功与部分失败输出（`stdout`）

`results` 始终按 `index`（从 `1` 开始）升序排列；`files` 为已完整写入磁盘的图片**绝对路径**。

全部成功（退出码 `0`）：

```json
{
  "ok": true,
  "requested": 2,
  "succeeded": 2,
  "failed": 0,
  "results": [
    {
      "index": 1,
      "ok": true,
      "files": ["/absolute/images/mint-uuid-1-1.png"],
      "elapsed_ms": 18200
    },
    {
      "index": 2,
      "ok": true,
      "files": ["/absolute/images/mint-uuid-2-1.png"],
      "elapsed_ms": 19100
    }
  ]
}
```

批量部分失败（退出码 `1`，保留所有已成功写入的文件）：

```json
{
  "ok": false,
  "requested": 2,
  "succeeded": 1,
  "failed": 1,
  "results": [
    {
      "index": 1,
      "ok": true,
      "files": ["/absolute/images/mint-uuid-1-1.png"],
      "elapsed_ms": 15400
    },
    {
      "index": 2,
      "ok": false,
      "files": [],
      "error": {
        "type": "api_error",
        "message": "HTTP 429：Quota exhausted",
        "http_status": 429
      },
      "elapsed_ms": 820
    }
  ]
}
```

### 3. 错误输出格式

- **单任务失败（`stderr`，每个失败任务一行 JSON，按完成顺序输出）**：
  ```json
  {"index":2,"error":{"type":"api_error","message":"HTTP 401：Invalid API key","http_status":401}}
  ```
- **整体错误（同时输出到 `stdout` 和 `stderr`，不提交任何生图请求）**：
  ```json
  {"ok":false,"error":{"type":"invalid_arguments","message":"缺少 API Key，请先在 MintImage 中保存生图配置，或设置 MINT_IMAGE_API_KEY / --api-key。"}}
  ```

`http_status` 仅在可获取 HTTP 状态码时出现。

## 错误类型枚举与退出码

| `error.type` | 退出码 | 常见原因 |
| --- | --- | --- |
| `invalid_arguments` | `2` | 未知参数、非法数值、互斥选项冲突、缺少 API Key、`--output` 已存在或扩展名与 `--format` 不符、协议/格式校验未通过 |
| `invalid_input` | `2` | `--prompt-file` / `--image` / `--markup` 不存在、不可读、为空文件或非有效 UTF-8 |
| `config_error` | `2` | `--profile` 不存在或重名、显式指定的 `--settings-file` 不存在/不可读/JSON 或 plist 损坏 |
| `api_error` | `1` | 服务端返回 HTTP 错误、HTTP 200 内嵌 error、SSE 错误事件、OpenRouter/markup 运行前校验错误 |
| `timeout` | `1` | 单任务超过 `--timeout`（包含生成、异步轮询或图片下载）或底层连接/读写超时 |
| `network_error` | `1` | Socket/DNS/TLS 等网络连接失败 |
| `download_error` | `1` | 服务端返回图片 URL 后下载该 URL 收到非 2xx 响应 |
| `invalid_response` | `1` | 响应缺少图片数据、Base64 无效、魔数校验非有效 PNG/JPEG/WebP/GIF/SVG、`--output` 实际返回格式不匹配或返回多图 |
| `io_error` | `1` | 输出目录创建/探测写入失败（在发起付费请求前触发）或最终保存文件写盘失败 |
| `internal_error` | `1` | 其他未归类内部异常 |
