# MintImage

跨平台 AI 图像生成客户端，支持 OpenAI 兼容 API。

## 功能

- **文生图 / 图生图** — 输入提示词生成图片，或上传参考图进行编辑
- **多尺寸预设** — 1K/2K/4K 档位 × 8 种比例，也支持自定义宽高或自动模式
- **批量生成** — 单次最多 16 张并发
- **多 API 配置** — 自由切换不同 endpoint / key / 模型
- **本地存储** — SQLite 持久化生成记录，离线可回顾
- **后台生成** — 支持后台任务 + 本地通知
- **全平台** — Windows · macOS · Android · iOS

## 截图

<!-- 在此放置截图 -->

## 快速开始

```bash
# 克隆
git clone https://github.com/aiqinxuancai/MintImage.git
cd MintImage

# 安装依赖
flutter pub get

# 运行
flutter run
```

首次启动后在设置页填写 Base URL、API Key 和模型名即可使用。

## 构建发布

推送 `v*` 格式的 tag 会自动触发 GitHub Actions 构建：

```bash
git tag v1.0.0
git push origin v1.0.0
```

产物：`MintImage-windows-x64.zip` · `app-release.apk` · `MintImage-macos-arm64.zip` · `MintImage-ios-nosign.zip`

## 技术栈

| 领域 | 选型 |
|------|------|
| 状态管理 | Riverpod |
| 网络 | Dio |
| 数据库 | Drift (SQLite) |
| 图片缓存 | CachedNetworkImage |
| 图片预览 | PhotoView |

## License

MIT
