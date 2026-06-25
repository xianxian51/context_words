# 语境单词本 Context Words

语境单词本是一款使用 Flutter 开发的 Android 英语学习 App。它围绕“三遍语境记忆法”组织每日学习：通过两篇语境阅读接触和强化目标词，再用单词列表完成复习。应用采用本地优先设计，学习计划、词库、阅读记录和星标数据默认保存在设备上的 SQLite 数据库中。

> 当前仓库面向个人学习和测试使用。Debug APK 只适合测试，正式分发前需要配置稳定的 Android Release 签名。

正式 Android applicationId 为 `io.github.xianxian51.contextwords`。

## 核心功能

- 内置大学英语六级词库
- 每日自动学习计划与随机抽词
- “再来一组”追加学习批次
- DeepSeek AI 生成语境阅读短文
- 学习型逐句全文翻译，支持原句、译文和目标词语境提示
- 阅读、释义和例句中的任意英文单词点查
- 今日单词与晚间复习
- Android 系统 TTS 单词发音
- 重点词册（星标）
- 自定义单词本
- 易混词组与 AI 辨析
- 英语助手聊天，支持 Markdown 回复、复制和失败重试
- 学习数据 JSON 备份与合并恢复
- GitHub Releases 更新检查，可手动检查或在启动时提醒

## 技术栈

- Flutter / Dart
- SQLite（`sqflite`）
- DeepSeek OpenAI-compatible API（`dio`）
- `flutter_tts`
- `shared_preferences`
- GitHub Releases

## DeepSeek API Key

App **不内置任何 DeepSeek API Key**。使用 AI 功能前，需要在 App 的“设置”页面填写自己的 DeepSeek API Key。

- API Key 仅保存在当前设备的本地设置中。
- API Key 不会写入 Dart 源码或内置资源。
- 数据备份不会导出 API Key。
- `.gitignore` 会排除常见密钥、环境文件和本地备份文件。

请勿把个人 API Key 提交到 GitHub、Issue、日志或截图中。

## 模型说明

所有 AI 功能通过一个集中设置选择模型，并统一读取该设置：

- `deepseek-v4-pro`：默认高质量模式，适合翻译、辨析和问答。
- `deepseek-v4-flash`：快速省钱模式，适合希望缩短等待或控制费用的场景。

模型选择保存在本机 `shared_preferences` 中。英语助手只在用户点击发送后调用 API，聊天请求最多携带最近 10 轮上下文。

## 本地运行

准备好 Flutter 与 Android 开发环境后：

```bash
flutter pub get
flutter run
```

运行检查：

```bash
flutter analyze
flutter test
```

## 打包 APK

构建 Debug APK：

```bash
flutter build apk --debug
```

默认输出路径：

```text
build/app/outputs/flutter-apk/app-debug.apk
```

Debug APK 只适合测试。正式发布需要配置独立、长期保管的 Android Release keystore，并确保 keystore、`key.properties`、APK 和 AAB 不进入源码仓库。

## GitHub Releases 更新机制

App 通过 GitHub Releases 提供安装包和版本信息：

1. App 检查仓库的 latest release。
2. 有新版本时提示用户下载。
3. App 不做静默自动安装。
4. 用户下载后需要自行确认安装。

设置页可关闭启动检查，也可随时手动检查。检查失败不会影响学习；App 不会静默下载或安装新版。

## v0.1.3 测试版

`v0.1.3` 将自动阅读生成改为顺序请求，避免两篇短文并发调用 DeepSeek 导致卡住；DeepSeek 超时、API Key、余额、频率限制和服务繁忙会显示更具体的中文提示。使用 `deepseek-v4-pro` 时若响应较慢，App 会提示可在设置中切换到 `deepseek-v4-flash` 快速模式。

全文翻译改为学习型逐句翻译：优先展示英文原句、中文译文和目标词语境提示；已缓存翻译不会重复消耗 token。TTS 设置页新增“下载/安装英语语音包”入口，缺少 `en-US` / `en-GB` 时可直接打开系统 TTS 语音数据安装或设置页面。

当前 Release 附件仍是 Debug APK，仅供体验和测试。

## v0.1.2 测试版

`v0.1.2` 优化系统 TTS 语言选择，默认优先美式 `en-US`，可选英式 `en-GB` 或跟随系统。设备只有泛英语 `en` 时会明确提示安装具体语音包。当前 Release 附件仍是 Debug APK，仅供体验和测试。

## 数据保留

- 旧测试包名为 `com.example.context_words`，正式包名为 `io.github.xianxian51.contextwords`。Android 会把它们视为两个不同 App，旧版数据不会自动继承到正式版。
- 从旧测试版迁移时，请先在旧版“设置 → 数据管理”中导出学习数据，安装正式包名版本后再在新版导入。
- 后续使用相同正式 applicationId 和相同签名证书覆盖安装更高版本 APK，一般会保留 App 私有数据。
- 卸载旧版 App 会删除系统管理的本地数据。
- 更换包名或签名证书后，Android 可能将新版视为另一个 App，无法直接覆盖安装。
- 更新前建议在“设置 → 数据管理”中导出学习数据。

## 词库来源与 License

内置 CET-6 词库由开源数据清洗、匹配后生成：

- 释义来源：[skywind3000/ECDICT](https://github.com/skywind3000/ECDICT)，MIT License。
- CET 词表来源：[JavaProgrammerLB/cet-word-list](https://github.com/JavaProgrammerLB/cet-word-list)，MIT License。
- 原始项目的许可证文本保存在 `assets/wordbooks/ECDICT_LICENSE.txt` 和 `assets/wordbooks/CET_WORD_LIST_LICENSE.txt`。
- 生成后的离线词库位于 `assets/wordbooks/cet6.json`。

## 隐私说明

- 学习数据默认保存在本地 SQLite 数据库。
- DeepSeek 功能会将用户主动提交的单词、短文或查询内容发送至 DeepSeek API。
- App 不提供自建账号系统、云同步或自有业务服务器。
- App 不出售用户数据。
- 使用 DeepSeek API 时还应阅读并遵守 DeepSeek 的服务条款和隐私政策。

## 截图

TODO: screenshots

## License

本项目采用 [MIT License](LICENSE)。第三方词库数据同时受其各自许可证约束，详见 `assets/wordbooks/`。
