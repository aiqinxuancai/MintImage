# MintImage CLI

MintImage 完整桌面包附带的命令行功能，适合 Agent、脚本和自动化工具调用。支持 Windows x64 和 macOS arm64；也可以在其他 macOS 架构上从源码构建。命令行生图不会启动 Flutter UI、应用历史数据库、桌面通知或后台服务；所有任务完成或失败后退出进程。

## 获取与运行

下载完整桌面包 `MintImage-windows-x64.zip` 或 `MintImage-macos-arm64.zip`，保留解压后的文件结构。CLI 位于包内的 `cli/` 目录：

```text
cli/
  bin/mint-image.exe    # Windows；macOS 对应 bin/mint-image
  lib/                 # 构建工具生成的原生依赖
  README.md
```

不单独发布 CLI 包，也不提供自动释放缓存的单文件封装。图形界面和命令行均随完整应用包分发。Agent 直接调用 `cli/bin` 中的控制台入口；将该目录加入 PATH 后可使用 `mint-image` 命令。下文示例默认从 `cli/` 目录运行。运行发布包无需安装 Dart 或 Flutter。

从源码开发或构建（在项目根目录）：

```bash
flutter pub get
dart run bin/mint_image.dart --help
dart run tool/build_cli.dart
```

内部构建产物为 `build/cli/bundle/bin/mint-image.exe`（Windows）或 `build/cli/bundle/bin/mint-image`（macOS）。发布流程将整个 `build/cli/bundle/` 复制到完整桌面包的 `cli/` 目录。在目标操作系统和 CPU 架构上构建，默认使用当前架构。

## 文生图与并行

默认直接读取当前系统用户在 MintImage 中保存的生图配置，不需要重复填写密钥、Base URL 或模型名。不传 `--profile` 时使用桌面端当前选中的配置；API 协议、流式开关和全局请求超时也会继承。每次调用重新读取已保存设置，不要求桌面端正在运行。CLI 只读配置，不改写桌面端的选择、历史或其他设置。

PowerShell：

```powershell
.\bin\mint-image.exe generate --prompt "薄荷绿背景上的一只猫" --count 4 --parallel 2 --output-dir .\images
$LASTEXITCODE
```

macOS：

```bash
./bin/mint-image generate --prompt '薄荷绿背景上的一只猫' --count 4 --parallel 2 --output-dir ./images
echo $?
```

`--count 4 --parallel 2` 会提交 4 个独立请求，每个请求一张图片，最多同时运行 2 个任务。某个任务失败后，其他任务继续执行。任务的超时从该任务开始执行时计算，包括生成、异步轮询和图片下载所用的网络时间。可以同时启动多个 CLI 进程，使用各自的提示词和参数。

`--output-dir` 默认 `./mint-image-output`，自动生成包含随机运行 ID 的文件名，支持多个进程共用目录。自动文件名的扩展名按实际返回的 PNG/JPEG/WebP 格式决定。

单张图也可通过 `--output ./cat.png` 指定文件路径。它只支持 `--count 1`，不能同时使用 `--output-dir`。文件已存在时会报错，多个进程争用同一路径时也不会覆盖已有内容。指定路径的扩展名必须匹配 `--format`，服务端实际返回其他格式时会报告错误。

## 选择与列出 MintImage 配置

列出已保存的生图配置，不输出 API Key，也不调用网络接口：

```bash
./bin/mint-image profiles
```

输出一份 JSON，包含配置来源、当前选中 ID 和公开配置字段：

```json
{
  "ok": true,
  "settings_file": "/absolute/path/to/preferences.plist",
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

`has_api_key` 仅表示是否已填写密钥。没有保存配置时，命令成功返回空 `profiles` 数组和提示信息。不会输出提示词优化配置、WebDAV 密码或其他非生图设置。

按名称选择配置（名称包含空格时加引号）：

```bash
./bin/mint-image generate --profile '我的生图配置' --prompt '水彩风格的山间小屋'
```

也可传列表中的 ID：`--profile profile-id`。配置名称按完整名称精确匹配；存在同名配置时要求使用 ID，不会任意选择。指定配置不存在、文件不可读或格式损坏时返回 `config_error` 和退出码 `2`。

自动读取的位置：

| 系统 | 偏好文件 |
| --- | --- |
| Windows | `%APPDATA%\com.aiqin\MintImage\shared_preferences.json` |
| macOS | `~/Library/Containers/com.aiqin.mintImage/Data/Library/Preferences/com.aiqin.mintImage.plist`；兼容 `~/Library/Preferences/com.aiqin.mintImage.plist` |

特殊安装位置可以用 `--settings-file 路径` 或环境变量 `MINT_IMAGE_SETTINGS_FILE` 指定。支持 Windows 偏好 JSON、macOS 偏好 plist 或 `SettingsModel` 原始 JSON。该选项可用于 `generate` 和 `profiles`。

仍支持完全独立的连接参数，并可覆盖配置中的部分字段。优先级为：**命令行参数 > 对应环境变量 > MintImage 保存的配置 > 默认值**。例如，`--model other-model --no-stream` 只覆盖本次调用使用的模型和流式开关。需要完全忽略桌面端配置时使用 `--no-app-config`：

```bash
export MINT_IMAGE_API_KEY='你的密钥'
export MINT_IMAGE_BASE_URL='https://api.tryaigc.cn'
./bin/mint-image generate --no-app-config --model gpt-image-2 --prompt '薄荷色的猫'
```

`--no-app-config` 不能与 `--profile` 或 `--settings-file` 同时使用。图片尺寸、质量、输出格式继续使用 CLI 参数及默认值，不继承桌面端上一次生成的参数。

## 图生图与长提示词

提供 `--image` 会自动调用图生图接口；重复参数可传多张参考图。路径中含空格或逗号时用引号包围。

```bash
./bin/mint-image generate --prompt '改成水彩画，保留原构图' --image './reference one.png' --image ./reference-two.png --output ./edited.png
```

从 UTF-8 文件读取多行提示词（支持 BOM）：

```bash
./bin/mint-image generate --prompt-file ./prompt.txt --output-dir ./images
```

`--prompt-file -` 从标准输入读取 UTF-8 文本，直到 EOF。Agent 通过管道传入后应关闭 stdin。

```bash
cat prompt.txt | ./bin/mint-image generate --prompt-file -
```

## 配置参数

配置优先级为命令行、对应环境变量、MintImage 已保存配置、默认值。

| 参数 | 环境变量 | 默认值 / 说明 |
| --- | --- | --- |
| `--profile` | — | 已保存配置的名称或 ID；默认使用当前配置 |
| `--settings-file` | `MINT_IMAGE_SETTINGS_FILE` | 默认自动查找桌面端配置；也适用于 `profiles` 命令 |
| `--no-app-config` | — | 禁止自动读取已保存配置 |
| `--base-url` | `MINT_IMAGE_BASE_URL` | 继承配置；无配置时为 `https://api.openai.com`；可带 `/v1` |
| `--api-key` | `MINT_IMAGE_API_KEY` | 继承配置；可通过参数或环境变量覆盖 |
| `--model` | `MINT_IMAGE_MODEL` | 继承配置；无配置时使用应用现有的协议默认模型 |
| `--api-mode` | — | 继承配置，未配置时 `images`；可选 `responses` |
| `--prompt` / `-p` | — | 提示词；与 `--prompt-file` 二选一 |
| `--prompt-file` | — | UTF-8 文件，`-` 表示 stdin |
| `--image` | — | 参考图路径，可重复 |
| `--size` | — | `1024x1024`，也支持其他正整数 `宽x高` 或 `auto` |
| `--quality` | — | `auto`，可选 `low`、`medium`、`high` |
| `--format` | — | `png`，可选 `jpeg`、`webp` |
| `--count` | — | `1`，独立请求数，正整数 |
| `--parallel` | — | `1`，并发任务数，正整数；实际不超过 count |
| `--timeout` | — | 继承 MintImage 全局设置；无配置时 `600` 秒 |
| `--output` / `-o` | — | 单张图的目标文件，拒绝覆盖 |
| `--output-dir` | — | `./mint-image-output`，自动创建目录 |
| `--stream` / `--no-stream` | — | 继承配置；无配置时默认关闭 |
| `--help` / `-h` | — | 参数帮助 |

具体模型、像素尺寸、质量和格式的支持范围由 API 服务商决定。RightAPI 使用 `https://rightapi.ai` 和 Images 模式，复用桌面端的异步提交与任务轮询。TryAIGC 使用 `https://api.tryaigc.cn`，`gpt-image-2` 默认按非流式 Images 协议提交。Responses 模式可用 `--api-mode responses --model 你的模型` 指定服务商支持的模型。

## Agent 输出协议与错误

除 `--help` 外，`stdout` 只输出一份 UTF-8 JSON 文档。`profiles` 返回配置列表，`generate` 返回任务结果。任务按编号排列；`index` 从 1 开始。`files` 是已完整保存的图片绝对路径。不要依赖文件名格式来推断任务编号，使用返回的 JSON 字段。

全部成功示例：

```json
{
  "ok": true,
  "requested": 2,
  "succeeded": 2,
  "failed": 0,
  "results": [
    {"index": 1, "ok": true, "files": ["/absolute/images/mint-id-1-1.png"], "elapsed_ms": 18200},
    {"index": 2, "ok": true, "files": ["/absolute/images/mint-id-2-1.png"], "elapsed_ms": 19100}
  ]
}
```

任务错误同时出现在最终 JSON 和 `stderr`。`stderr` 每个失败任务一行 JSON，完成顺序可能与编号不同。HTTP 错误保留状态码和服务端原因，密钥会脱敏：

```json
{"index":1,"error":{"type":"api_error","message":"HTTP 401：Invalid API key","http_status":401}}
```

输入校验失败或无法创建输出目录等整体错误示例（同时写到 stdout、stderr）：

```json
{"ok":false,"error":{"type":"invalid_arguments","message":"缺少 API Key，请先在 MintImage 中保存生图配置，或设置 MINT_IMAGE_API_KEY / --api-key。"}}
```

错误类型包括 `invalid_arguments`、`invalid_input`、`config_error`、`api_error`、`timeout`、`network_error`、`download_error`、`invalid_response`、`io_error` 和 `internal_error`。图片为空、Base64 无效、下载失败或返回 HTML 页面都不会报告成功。`http_status` 只在可获取 HTTP 状态时出现。服务端自行结束的请求超时也可能属于 `api_error`，具体原因保留在 `message` 中。

| 退出码 | 含义 |
| --- | --- |
| `0` | 全部任务成功，或显示帮助 |
| `1` | 接口、网络、超时、下载、保存失败，或批量任务中至少一个失败 |
| `2` | 参数错误、配置不存在或损坏、输入文件无效 |

批量部分失败时保留已生成图片，并在 `results` 中逐项报告成功和失败；`ok` 为 `false`，`succeeded` 和 `failed` 给出统计。单个请求返回多张图时，结果的 `files` 包含所有已保存图片；若其中一张保存失败，该任务为失败，但仍返回之前已保存的路径。CLI 不自动重试生图请求，Agent 可根据具体错误决定后续操作。

## 开发验证

普通测试使用本地模拟接口，不消耗 API 额度：

```bash
flutter test test/cli/cli_runner_test.dart
flutter test test/cli/cli_settings_store_test.dart
```

同一组测试可以验证编译后的真实进程，包括 stdin/stdout/stderr、并行请求和退出码。构建后设置 `MINT_IMAGE_CLI_BINARY` 为可执行文件的绝对路径，再运行该测试。Windows 和 macOS 发布工作流都会验证包内的命令行入口。
