# API 协议差异、校验规则与本地构建验证

## 1. 四种 API 协议路径行为

| 模式 / 服务商 | 触发条件 | 文生图 / 图生图端点 | 关键行为 |
| --- | --- | --- | --- |
| `images` | `--api-mode images`（或配置继承） | `POST /v1/images/generations`（JSON）<br>`POST /v1/images/edits`（multipart，`image[]`） | 支持同步返回、流式 SSE；若服务端响应包含 `task_id` 会自动转入 `/v1/tasks/{task_id}` 轮询 |
| `images_async` | `--api-mode images_async`（如 RightAPI `https://api.site`） | `POST /v1/images/generations`（JSON，`async: true`）<br>`POST /v1/images/edits`（JSON，`async: true`，参考图转 data URL） | 强制非流式，通过 `/v1/tasks/{task_id}` 轮询结果 |
| `responses` | `--api-mode responses` | `POST /v1/responses`（JSON，使用 `image_generation` tool） | 支持 `--reasoning-effort`；继承桌面端 `includeSizeInPrompt` 开关（开启且 `--size` 非 `auto` 时向提示词追加像素尺寸与宽高比，但实际输出像素仍由服务端决定） |
| OpenRouter Images | 非 `responses` 且 `base_url` 主机为 `openrouter.ai` | 统一 `POST /api/v1/images`（JSON，图生图用 `input_references`） | 自动将 `--safety-identifier` 映射至 `user`、`--complexity` 映射至 `provider.options.openai.complexity`；**发请求前拒绝 `gif`、`--markup`、`--svg-model` 及超过 16 张参考图** |

> 提示：从旧配置迁移的 `rightapi.ai` 地址会自动识别为 `images_async`。

## 2. GIF / SVG / Markup 本地前置校验

CLI 在发起付费 API 请求前复用与桌面端一致的校验逻辑：

- **GIF（`--format gif`）**
  - 仅支持 Images API 文生图（禁止 `--image` 与 `--api-mode responses`）。
  - 自动关闭本次请求的流式模式（不改动已保存配置）。
  - `--frame-count` 范围 `2–64`（默认 `9`）；`--frame-duration-ms` 范围 `20–2000`（默认 `200`，服务端按 10 ms 取整）。
  - 若指定像素 `--size`，宽和高都必须是 **16 的正整数倍**；否则请使用 `--size auto`。
  - 原始动画字节原样落盘，不重编码；如使用中转服务，生成后建议解码确认实际帧数与帧延迟。
- **SVG（`--format svg`）**
  - 仅支持 Images API 文生图（禁止 `--image` 与 `--api-mode responses`），自动关闭本次流式。
  - `--count` 每次网络请求固定 `n: 1`，批量生成 SVG 不会违反单请求数量限制。
  - 仅在传入 `--svg-model` 时发送 `svg` 对象；`--svg-reasoning-effort` 不可脱离 `--svg-model` 单独使用。
  - 原样保存 SVG XML；不可将 `.svg` 作为 `--image` 参考图传入图生图。
- **标注引导编辑（`--markup <file.png>`）**
  - 仅支持 Images API（`images` / `images_async`）图生图，必须同时提供至少一个 `--image`，不支持 `responses` 与 OpenRouter。
  - 文件必须以 `.png` 结尾、大小不超过 **50 MB**、像素总数不超过 **16,777,216**（第一张参考图同样不得超过 16,777,216 像素）。
  - 必须是有效 PNG 且**至少包含一个透明像素**（`alpha < 1`）。
  - 像素宽高必须与**第一张参考图经 EXIF 方向校正后的尺寸完全一致**。
  - `images` 模式通过 multipart 字段 `markup` 上传；`images_async` 模式以 `markup.image_url` data URL 提交。

## 3. 安全与并发保证

- **密钥脱敏**：命令行 `--api-key`、`MINT_IMAGE_API_KEY`、配置文件中所有 profile 的 `apiKey` 以及任意 `Bearer <token>` 文本在错误输出和 `profiles` 输出中都会被替换为 `[REDACTED]`。
- **不向图片 CDN 泄露凭据**：服务端返回图片 URL 时，CLI 使用独立下载客户端抓取，不附带 API `Authorization` 请求头。
- **防覆盖与并发安全**：
  - 使用 `--output` 时采用原子独占创建（`exclusive: true`），不会覆盖已有文件，多进程争用同一路径时仅一个成功。
  - 使用 `--output-dir` 时每次运行生成独立 UUID 前缀，多进程可安全并行写入同一目录。
  - 写盘前先探测目录可写性，目录不可写时在发起付费请求前失败并返回 `io_error`。
- **只读配置**：CLI 从不修改桌面端配置文件、历史记录数据库或当前选中 profile。

## 4. 在源码仓库中构建与测试 CLI

在项目根目录执行：

```bash
# 安装依赖
flutter pub get

# 直接以 Dart 运行 CLI（免构建调试）
dart run bin/mint_image.dart --help

# 编译当前平台可执行包到 build/cli/bundle/
dart run tool/build_cli.dart
```

运行本地模拟测试（不消耗 API 额度）：

```bash
flutter test test/cli/cli_runner_test.dart test/cli/cli_settings_store_test.dart
```

验证编译后的真实二进制进程（stdin/stdout/stderr、并行与退出码）：

```powershell
# Windows PowerShell
$env:MINT_IMAGE_CLI_BINARY = (Resolve-Path build/cli/bundle/bin/mint-image.exe).Path
flutter test test/cli
```

```bash
# macOS
MINT_IMAGE_CLI_BINARY="$PWD/build/cli/bundle/bin/mint-image" flutter test test/cli
```
