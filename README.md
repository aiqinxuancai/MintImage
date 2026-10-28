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

## 📦 自行构建

```bash
flutter pub get
flutter run            # 调试运行
flutter build windows  # 或 macos / apk
```

---

<div align="center">

该项目已在 [LINUX DO](https://linux.do/) 社区分享。

基于 [MIT](LICENSE) 协议开源。

</div>

