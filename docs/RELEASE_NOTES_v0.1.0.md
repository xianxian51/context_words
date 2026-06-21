# Context Words v0.1.0

语境单词本 Context Words 首个公开测试版本。

## 主要功能

- 完整六级词库
- 每日自动学习计划与“再来一组”
- DeepSeek 生成阅读短文与全文翻译
- 任意英文单词点查
- TTS 发音
- 重点词册与自定义单词本
- 易混词组 AI 辨析
- DeepSeek 英语学习辅助能力
- 本地数据备份与合并恢复
- 通过 GitHub Releases 分发测试安装包

## 测试版说明

当前附件 `app-debug.apk` 使用 Debug 签名，仅用于测试体验，不适合正式生产发布。

正式 Android applicationId 为 `io.github.xianxian51.contextwords`。如果你已经安装旧测试包名 `com.example.context_words`，Android 不会自动继承旧版数据。请先在旧版“设置 → 数据管理”中导出学习数据，再在正式包名版本中导入。

DeepSeek 功能不内置 API Key，需要用户在 App 设置页填写自己的 Key。API Key 只保存在本机，不包含在备份或源码中。
