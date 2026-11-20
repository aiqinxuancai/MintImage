# mint-image 使用说明

本目录中的 `mint-image.exe`（Windows）或 `mint-image`（macOS）是 MintImage 的命令行生图入口，适合 Agent、脚本和自动化工具调用。它不启动图形界面，所有任务完成或失败后立即退出。完整参考文档见上级目录的 `README.md`。

> 请保留发布包的目录结构：本目录的程序依赖 `cli/lib/` 中的原生库，不要只单独复制可执行文件。可以把本目录加入 PATH，然后直接使用 `mint-image` 命令。

以下示例都在本目录（`cli/bin`）中运行。Windows PowerShell 使用 `.\mint-image.exe`，macOS 终端使用 `./mint-image`。

## 1. 准备配置

先在 MintImage 桌面端保存生图配置（Base URL、API Key、模型）。CLI 默认读取桌面端**当前选中**的配置，不需要重复填写密钥；桌面端无需正在运行，CLI 也不会修改任何已保存设置。

```bash
./mint-image profiles        # 列出已保存的配置（不输出密钥）
```

## 2. 常用示例

文生图（默认保存到 `./mint-image-output`）：

```powershell
.\mint-image.exe generate --prompt "薄荷绿背景上的一只猫"
```

```bash
./mint-image generate --prompt '薄荷绿背景上的一只猫'
```

指定单张输出文件与尺寸、质量（文件已存在时报错，不会覆盖）：

```bash
./mint-image generate --prompt '水彩风格的山间小屋' --size 1536x1024 --quality high --output ./house.png
```

批量并行：提交 4 个独立请求，最多同时运行 2 个：

```bash
./mint-image generate --prompt '极简风格图标' --count 4 --parallel 2 --output-dir ./images
```

图生图：提供 `--image` 即调用编辑接口，可重复传多张参考图：

```bash
./mint-image generate --prompt '改成水彩画，保留原构图' --image ./ref1.png --image ./ref2.png
```

长提示词：从 UTF-8 文件或标准输入读取：

```bash
./mint-image generate --prompt-file ./prompt.txt
cat prompt.txt | ./mint-image generate --prompt-file -
```

## 3. 临时切换模型（仅本次有效）

`--model`（简写 `-m`）只替换本次请求使用的模型名。Base URL、API Key、API 协议、流式开关等仍沿用所选配置，桌面端保存的配置不会被修改，下一次调用会恢复使用配置中的模型。

```bash
# 使用当前配置的地址和密钥，但这次改用其他模型
./mint-image generate --model gpt-image-2 --prompt '薄荷色的猫'

# 使用指定配置的地址和密钥，并临时改用其他模型
./mint-image generate --profile '我的生图配置' -m 其他模型名 --prompt '薄荷色的猫'
```

也可以通过环境变量 `MINT_IMAGE_MODEL` 设置，命令行参数优先。模型是否可用由 API 服务商决定。

## 4. 选择配置与独立连接参数

```bash
./mint-image generate --profile '我的生图配置' --prompt '...'   # 按名称或 ID 选择配置
```

不读取桌面端配置，完全使用环境变量或参数：

```bash
export MINT_IMAGE_API_KEY='你的密钥'
export MINT_IMAGE_BASE_URL='https://api.openai.com'
./mint-image generate --no-app-config --model gpt-image-2 --prompt '薄荷色的猫'
```

PowerShell 中设置环境变量：`$env:MINT_IMAGE_API_KEY = '你的密钥'`。

配置优先级：**命令行参数 > `MINT_IMAGE_*` 环境变量 > MintImage 已保存配置 > 默认值**。

## 5. 参数速查

| 参数 | 说明 |
| --- | --- |
| `--prompt` / `-p` | 提示词；与 `--prompt-file` 二选一 |
| `--prompt-file` | UTF-8 提示词文件，`-` 表示 stdin |
| `--image` | 参考图路径，可重复；提供后使用图生图 |
| `--profile` | 已保存配置的名称或 ID；默认使用当前配置 |
| `--model` / `-m` | 仅本次请求使用的模型名，不改变 Base URL 和 Key |
| `--base-url` / `--api-key` | 覆盖本次使用的 API 地址 / 密钥 |
| `--api-mode` | `images`、`images_async`、`responses`；默认继承配置 |
| `--size` | `1024x1024`（默认）、其他 `宽x高` 或 `auto` |
| `--quality` | `auto`（默认）、`low`、`medium`、`high`、`xhigh`、`max` |
| `--format` | `png`（默认）、`jpeg`、`webp`、`gif`、`svg` |
| `--count` / `--parallel` | 独立请求数 / 同时执行数，默认均为 1 |
| `--output` / `-o` | 单张图片目标文件，仅适用于 `--count 1` |
| `--output-dir` | 输出目录，默认 `./mint-image-output` |
| `--timeout` | 每个任务的网络总超时秒数，默认继承配置或 600 |
| `--stream` / `--no-stream` | 流式开关；默认继承配置 |
| `--no-app-config` | 不读取桌面端配置 |
| `--settings-file` | 指定配置文件路径 |

GIF/SVG、复杂度、标注图等更多参数请运行 `./mint-image --help`，或查看上级目录的 `README.md`。

## 6. 输出与退出码

- `stdout` 只输出一份 JSON；每个任务的 `files` 为已保存图片的绝对路径。
- `stderr` 每个失败任务输出一行 JSON 错误，密钥会脱敏。

```json
{"ok":true,"requested":1,"succeeded":1,"failed":0,"results":[{"index":1,"ok":true,"files":["/absolute/path/mint-id-1-1.png"],"elapsed_ms":18200}]}
```

| 退出码 | 含义 |
| --- | --- |
| `0` | 全部成功，或显示帮助 |
| `1` | 接口、网络、超时、下载或保存失败（含批量部分失败） |
| `2` | 参数错误、配置不存在或损坏、输入文件无效 |
