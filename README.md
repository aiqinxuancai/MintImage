<div align="center">

<img src="icon/icon-windows-透明背景.png" width="120" alt="MintImage" />

# MintImage

**跨平台 AI 图像生成客户端**

输入一句提示词，让 AI 为你生成图片。兼容所有 OpenAI 格式的图像 API。

![Flutter](https://img.shields.io/badge/Flutter-02569B?logo=flutter&logoColor=white)
![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20macOS%20%7C%20Android-5A5A5A)
![License](https://img.shields.io/badge/license-MIT-3DA639)
[![Release](https://img.shields.io/github/v/release/aiqinxuancai/MintImage?color=FF7A59)](https://github.com/aiqinxuancai/MintImage/releases)

[下载安装包](https://github.com/aiqinxuancai/MintImage/releases)

</div>

---

## ✨ 功能

- **文生图** — 输入提示词，AI 为你生成图片
- **图生图** — 上传参考图，用文字描述修改方向
- **提示词优化** — 一键润色提示词，让描述更精准
- **长提示词编辑** — 拖动输入框上方横条调整高度，或全屏编辑，返回时保留草稿与光标
- **大图附件** — 支持选择、粘贴超过 25 MB 的参考图，实际上传上限由所用 API 决定
- **丰富尺寸** — 1K / 2K / 4K 多档位、8 种常用比例，或自定义任意宽高
- **批量生成** — 一次最多生成 16 张
- **命令行生图** — Windows / macOS 独立控制台程序，支持 Agent 调用、批量并行、JSON 结果和错误退出码，执行后退出进程
- **收藏夹** — 把满意的结果分类整理，随时回看
- **历史记录** — 所有生成结果本地保存，离线可查
- **多配置切换** — 同时管理多个 API 地址与密钥，一键切换

## 📸 截图

<img width="1266" height="713" alt="screenshot-1" src="https://github.com/user-attachments/assets/87b8b66f-17d4-4b41-a06a-e1f39936b95e" />

<img width="1266" height="713" alt="screenshot-2" src="https://github.com/user-attachments/assets/3d014dce-6c02-49b3-a5a6-55ace9591ef6" />

<img width="1266" height="713" alt="screenshot-3" src="https://github.com/user-attachments/assets/f72ea01f-1b53-41ff-94a8-981ebeddf87b" />

<img width="1266" height="713" alt="screenshot-4" src="https://github.com/user-attachments/assets/bc45353c-7e15-4564-b838-71aad375e832" />

## 🚀 快速开始

1. 从 [Releases](https://github.com/aiqinxuancai/MintImage/releases) 下载对应平台的安装包
2. 打开应用，进入设置页
3. 填写 API 地址、密钥和模型名
4. 回到主页，输入提示词，开始生成

使用 [RightAPI 画图接口](https://docs.rightapi.ai/docs/rc_draw/) 时，Base URL 填写 `https://rightapi.ai`，生图 API 选择 `Images API`，可先用 `gpt-image-2` 验证。客户端会提交异步任务并轮询结果，流式开关不影响此流程；旧配置中的 `www.rightapi.ai/draw` 会自动转换为当前地址。GPT Image 模型使用 `1024x1024` 等像素尺寸，图生图通过 `/v1/images/edits` 提交。模型权限和可用性以你的 key 所属分组为准。

使用 [TryAIGC](https://api.tryaigc.cn) 时，Base URL 填写 `https://api.tryaigc.cn`，生图 API 选择 `Images API`。已实测 `gpt-image-2` 在关闭流式请求时可以生成图片，建议保留默认的 600 秒超时；可用模型以你的 key 获取到的模型列表为准。

## 命令行与 Agent 调用

命令行功能随完整桌面包一起提供，不单独发布 CLI 包。解压 `MintImage-windows-x64.zip` 或 `MintImage-macos-arm64.zip` 后，图形界面正常启动；Agent 可调用包内的 `cli/bin/mint-image.exe`（Windows）或 `cli/bin/mint-image`（macOS）进行生图，无需安装 Flutter，也不会创建 UI。完整参数、图生图和错误协议见 [命令行文档](docs/CLI.md)。

Windows PowerShell 示例：

```powershell
.\cli\bin\mint-image.exe profiles
.\cli\bin\mint-image.exe generate --prompt "薄荷绿背景上的一只猫" --count 4 --parallel 2 --output-dir .\images
.\cli\bin\mint-image.exe generate --profile "我的生图配置" --prompt "水彩风格的山间小屋" --output .\cabin.png
$LASTEXITCODE
```

macOS 示例：

```bash
./cli/bin/mint-image profiles
./cli/bin/mint-image generate --prompt '薄荷绿背景上的一只猫' --count 4 --parallel 2 --output-dir ./images
./cli/bin/mint-image generate --profile '我的生图配置' --prompt '水彩风格的山间小屋' --output ./cabin.png
echo $?
```

CLI 默认读取当前用户在 MintImage 中保存并选中的生图配置，无需重复填写密钥、地址或模型；也会继承 API 协议、流式开关和请求超时。`--profile` 可按名称或 ID 选择，`profiles` 以 JSON 列出配置但不输出密钥。命令行参数、`MINT_IMAGE_*` 环境变量可以覆盖已保存配置，`--no-app-config` 可关闭自动读取。

`stdout` 返回一份 JSON，包含每个任务的状态和图片绝对路径；错误同时写入 `stderr`，保留 HTTP 状态码和接口原因。退出码 `0` 表示全部成功，`1` 表示运行失败或部分失败，`2` 表示参数、配置或输入错误。支持多个进程同时调用，自动生成的文件名不会互相覆盖。

## 📦 自行构建

```bash
flutter pub get
flutter run            # 调试运行
flutter build windows  # 或 macos / apk
dart run tool/build_cli.dart  # 在目标系统上构建 CLI：build/cli/bundle/
```

---

<div align="center">

该项目已在 [LINUX DO](https://linux.do/) 社区分享。

基于 [MIT](LICENSE) 协议开源。

</div>

