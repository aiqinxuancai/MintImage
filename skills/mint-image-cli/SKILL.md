---
name: mint-image-cli
description: >-
  使用 MintImage CLI（mint-image / mint-image.exe）通过命令行生成或编辑图像，支持文生图、图生图、透明 PNG 标注引导、批量并行、GIF 动画与 SVG 矢量图，以及列出并选择 MintImage 桌面端已保存的 API 配置。当用户需要通过命令行或 MintImage CLI 调用 AI 生图/改图、临时切换模型或配置、批量出图、或解析其 JSON 输出与错误码时使用此 skill。
---

# MintImage CLI

使用 `mint-image`（Windows 为 `mint-image.exe`，macOS 为 `mint-image`）在无 GUI 模式下执行 AI 生图与改图。CLI 不启动 Flutter 界面、不写入应用历史数据库、也不修改桌面端已保存配置，所有任务完成后立即退出。

## 1. 定位或获取 CLI 入口

按以下优先级确定可执行命令（下文统一以 `mint-image` 代称）：

1. **系统 PATH**：检查是否已可直接运行 `mint-image`（PowerShell：`Get-Command mint-image`；macOS：`command -v mint-image`）。
2. **本地已解压的桌面发行包 / 默认安装目录**：
   - Windows：用户已解压目录或 `%LOCALAPPDATA%\MintImage\cli\bin\mint-image.exe`
   - macOS：用户已解压目录或 `~/.local/share/mint-image/cli/bin/mint-image`
   - **必须保留完整 `cli/` 目录结构**（依赖同级 `cli/lib/` 中的原生库，不要只单独复制可执行文件）。
3. **当前源码仓库内**：
   - 优先使用已构建产物：`build/cli/bundle/bin/mint-image.exe`（Windows）或 `build/cli/bundle/bin/mint-image`（macOS）。
   - 未构建时可在项目根目录直接运行 `dart run bin/mint_image.dart ...`，或执行 `dart run tool/build_cli.dart` 构建。
4. **本地未找到时，从 GitHub Releases 下载**：
   - 发布页：`https://github.com/aiqinxuancai/MintImage/releases`
   - CLI 随完整桌面压缩包一起分发（无独立单文件 exe），解压后使用包内的 `cli/bin/mint-image.exe`（Windows）或 `cli/bin/mint-image`（macOS），并保留 `cli/lib/`：
     - Windows x64：`https://github.com/aiqinxuancai/MintImage/releases/latest/download/MintImage-windows-x64.zip`
     - macOS Apple Silicon (arm64)：`https://github.com/aiqinxuancai/MintImage/releases/latest/download/MintImage-macos-arm64.zip`（其他 macOS 架构请从源码运行 `dart run tool/build_cli.dart`）

```powershell
# Windows PowerShell：下载最新 Release 并解压到 %LOCALAPPDATA%\MintImage
$dest = Join-Path $env:LOCALAPPDATA 'MintImage'
$zip  = Join-Path $env:TEMP 'MintImage-windows-x64.zip'
Invoke-WebRequest -Uri 'https://github.com/aiqinxuancai/MintImage/releases/latest/download/MintImage-windows-x64.zip' -OutFile $zip
Expand-Archive -Path $zip -DestinationPath $dest -Force
Remove-Item $zip -Force
& (Join-Path $dest 'cli\bin\mint-image.exe') --help
```

```bash
# macOS (Apple Silicon)：下载最新 Release 并解压到 ~/.local/share/mint-image
DEST="$HOME/.local/share/mint-image"
ZIP="/tmp/MintImage-macos-arm64.zip"
mkdir -p "$DEST"
curl -fL "https://github.com/aiqinxuancai/MintImage/releases/latest/download/MintImage-macos-arm64.zip" -o "$ZIP"
unzip -o "$ZIP" -d "$DEST"
rm -f "$ZIP"
chmod +x "$DEST/cli/bin/mint-image"
xattr -dr com.apple.quarantine "$DEST/cli" 2>/dev/null || true
"$DEST/cli/bin/mint-image" --help
```

- 下载并解压后运行 `--help` 验证退出码为 `0`；后续调用直接复用该目录，无需重复下载。
- 若当前环境无法联网或访问 GitHub 失败，请告知用户前往 `https://github.com/aiqinxuancai/MintImage/releases` 手动下载对应平台压缩包并解压后提供 `cli/bin/` 路径。

## 2. 标准执行流程

### 第一步：查看可用配置（可选，零费用、不联网）

CLI 默认自动读取当前系统用户在 MintImage 桌面端保存并选中的生图配置（继承 Base URL、API Key、模型、API 协议、流式开关、思考等级、安全标识、尺寸提示词开关与全局超时），无需重复传递密钥。

```bash
mint-image profiles
```

- 返回 JSON 中的 `profiles[]` 仅包含公开字段（`id`、`name`、`base_url`、`model`、`api_mode`、`stream`、`is_active`、`has_api_key`），**绝不输出 API Key**。
- 检查目标配置的 `has_api_key` 为 `true`；若要切换非当前配置，使用 `--profile "<名称或ID>"`（存在同名配置时必须使用 `id`）。
- 若未配置桌面端或需要完全隔离，使用 `--no-app-config` 并通过环境变量提供 `MINT_IMAGE_API_KEY`、`MINT_IMAGE_BASE_URL`、`MINT_IMAGE_MODEL`（尽量避免在命令行明文传递 `--api-key`）。
- 配置优先级：**命令行参数 > `MINT_IMAGE_*` 环境变量 > MintImage 已保存配置 > 默认值**。

### 第二步：执行生图 / 改图任务

#### 文生图（自动命名到目录）

```powershell
# PowerShell
.\cli\bin\mint-image.exe generate --prompt "薄荷绿背景上的一只猫" --output-dir .\images
```

```bash
# macOS / bash
./cli/bin/mint-image generate --prompt '薄荷绿背景上的一只猫' --output-dir ./images
```

#### 单张精确路径、尺寸与质量

```bash
mint-image generate \
  --prompt '水彩风格的山间小屋' \
  --size 1536x1024 \
  --quality high \
  --format png \
  --output ./house.png
```

- `--output` 仅用于 `--count 1`，不能与 `--output-dir` 同用，目标文件已存在时直接报错（不覆盖），且扩展名必须匹配 `--format`（`jpeg` 允许 `.jpg` 或 `.jpeg`）。

#### 批量并行

```bash
mint-image generate --prompt '极简风格图标' --count 4 --parallel 2 --output-dir ./images
```

- `--count N` 会提交 `N` 个独立请求（每次请求 `n=1`），最多同时运行 `min(parallel, count)` 个任务。
- `--output-dir` 默认为 `./mint-image-output`，文件名包含随机 UUID，多个 CLI 进程可安全共用同一目录。

#### 图生图（多参考图）

```bash
mint-image generate \
  --prompt '改成水彩画，保留原构图' \
  --image './reference one.png' \
  --image ./reference-two.png \
  --output ./edited.png
```

- 提供至少一个 `--image` 即自动调用图生图接口；可重复传递多个 `--image`（不按逗号分割，路径含空格或逗号时用引号包围）。

#### 长提示词 / 多行提示词

```bash
# 从 UTF-8 文件读取（自动去除 UTF-8 BOM）
mint-image generate --prompt-file ./prompt.txt --output-dir ./images

# 从 stdin 读取（传入后务必关闭 stdin）
cat prompt.txt | mint-image generate --prompt-file - --output-dir ./images
```

#### 临时切换模型或配置（仅本次生效）

```bash
# 沿用指定（或当前）配置的 Base URL、Key 与协议，仅替换本次模型
mint-image generate --profile '我的生图配置' -m gpt-image-2.6-sunburst --prompt '薄荷色的猫'
```

#### GPT Image 2.6 高级输出（GIF / SVG / 标注引导）

```bash
# GIF 动画（Images API 文生图；宽高需为 16 的倍数或 auto）
mint-image generate --api-mode images --model gpt-image-2.6-flare \
  --prompt '一只招手的小猫，无缝循环' \
  --format gif --size auto --frame-count 9 --frame-duration-ms 200 \
  --output ./cat.gif

# SVG 矢量图（Images API 文生图；可选 --complexity / --svg-model / --svg-reasoning-effort）
mint-image generate --api-mode images --model gpt-image-2.6-sunburst \
  --prompt '薄荷叶标志，简洁矢量路径' \
  --format svg --complexity high \
  --output ./leaf.svg

# 透明 PNG 标注引导编辑（Images API 图生图；尺寸须与第一张参考图 EXIF 校正后一致）
mint-image generate --api-mode images \
  --prompt '将红圈区域改为薄荷绿陶瓷杯' \
  --image ./photo.jpg --markup ./markup.png \
  --output ./edited.png
```

### 第三步：解析结果与核验

除 `--help` 外，`stdout` 始终只输出**一份 UTF-8 JSON 文档**；`stderr` 对每个失败任务输出一行 JSON，整体错误同时写入 `stdout` 和 `stderr`。

#### 退出码处理

| 退出码 | 含义 | 处理建议 |
| --- | --- | --- |
| `0` | 全部任务成功（或显示帮助） | 解析 `stdout` 中的 `results[].files[]` |
| `1` | 运行失败（接口/网络/超时/下载/IO）或批量部分失败 | 读取 `results[]` 与 `stderr` 错误详情，已成功的图片已保留；**不要静默无限重试付费请求** |
| `2` | 参数错误、配置缺失/损坏/冲突、输入文件无效 | 请求尚未发出（未扣费）；按 `error.message` 修正参数后重跑 |

#### 必须执行的验证步骤

1. **核对 JSON 与文件路径**：解析 `stdout` JSON，检查 `ok`、`succeeded`、`failed` 及每个 `results[i].ok`；**始终使用 `results[i].files[]` 返回的绝对路径**，不要根据命名规则猜测文件路径。
2. **精确尺寸核验**：`--size` 仅表示请求目标尺寸，部分服务端（尤其是 Responses API）可能返回不同分辨率且仍返回 `ok: true`。若用户要求精确像素宽高，**必须读取实际生成图片的像素尺寸核对后再回报**。
3. **GIF 动画参数核验**：部分中转服务可能忽略 `frame_count` / `frame_duration_ms` 并返回默认 9 帧 / 200 ms。若任务对帧数或帧时长有严格要求，生成后应解码核对实际帧数与延迟。
4. **敏感信息保护**：CLI 会对错误输出中的密钥与 `Bearer` 令牌自动脱敏为 `[REDACTED]`；不要在回复或日志中暴露明文 API Key。

## 3. 关键约束速查（避免退出码 2）

- `--prompt` 与 `--prompt-file` 必须且只能提供一个，去空白后不能为空。
- `--no-app-config` 不能与 `--profile` 或 `--settings-file` 同时使用。
- `--size`、`--quality`、`--format` **不继承**桌面端上次生成选择，CLI 默认值固定为 `1024x1024`、`auto`、`png`。
- `--format gif` 和 `--format svg` 仅支持 Images API（`images` / `images_async`）文生图，禁止与 `--image` 或 `--api-mode responses` 组合，且会自动关闭本次流式。
- `--frame-count`（2–64）与 `--frame-duration-ms`（20–2000）仅适用于 `--format gif`。
- `--svg-reasoning-effort` 必须与 `--format svg` 和非空 `--svg-model` 同时使用。
- `--complexity` 和 `--markup` 仅适用于 Images API，禁止用于 `--api-mode responses`；`--reasoning-effort` 仅适用于 `--api-mode responses`。
- 禁止将 `.svg` 文件作为 `--image` 参考图。
- OpenRouter（`openrouter.ai`）不支持 `gif`、`--markup`、`--svg-model`，且参考图最多 16 张。

## 4. 深入参考

需要完整参数表、JSON 输出结构、错误类型枚举、协议差异或本地源码构建/测试命令时，按需阅读：

- [完整参数、环境变量与 JSON 协议参考](./references/cli-options.md)
- [API 协议差异、校验规则与本地构建验证](./references/protocol-and-constraints.md)
