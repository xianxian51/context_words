# 语境单词本项目状态

最后更新：2026-06-25

## v0.1.3 AI 稳定性、学习翻译与 TTS 设置入口

- 版本号更新为 `0.1.3+7`，发布目标为 `v0.1.3` prerelease；`v0.1.2` Release 已存在且不覆盖。
- DeepSeek 默认超时调整为 connect `15s`、receive `60s`、send `15s`。
- 自动准备和“再来一组”沿用顺序补齐阅读：先第 1 篇，再第 2 篇；同一计划、批次、轮次已有阅读时不重复请求。
- 新增生成锁 `isGeneratingPassage`，配合 `isPreparingToday` 避免重复触发 DeepSeek 请求。
- DeepSeek 错误提示细化为 API Key 无效、余额不足、请求太频繁、服务繁忙、网络失败和响应超时；`deepseek-v4-pro` 超时时提示可切换 `deepseek-v4-flash`。
- 全文翻译升级为学习型逐句翻译，返回并缓存 `sentence_pairs` 和 `key_word_notes`。
- 数据库升级到 v6，仅通过 `ALTER TABLE ADD COLUMN` 为 `reading_passages` 和 `collection_passages` 增加 `sentence_pairs_json`、`key_word_notes_json`，不 drop table、不清空数据。
- 翻译 UI 优先显示“原句 / 译文 / 目标词提示”，旧 `translation_cn` 仍可 fallback 显示。
- 设置页新增“下载/安装英语语音包”按钮，通过 Android `ACTION_INSTALL_TTS_DATA` 打开系统 TTS 语音数据安装页，失败时回退系统设置。
- AndroidManifest 已保留 `android.intent.action.TTS_SERVICE` queries。
- `flutter pub get`：通过。
- `flutter analyze`：通过，`No issues found!`。
- `flutter test`：通过，88 项测试全部成功。
- `flutter build apk --debug`：成功；仅有插件未来迁移 Built-in Kotlin 的兼容性预警，不影响当前 APK。
- APK：`build/app/outputs/flutter-apk/app-debug.apk`
- APK SHA-256：`c89d2922106a816eb2f8b66830d146e2b41c72cad8d35d8ebdadf43d92ea8837`
- APK 清单：applicationId `io.github.xianxian51.contextwords`，versionName `0.1.3`，versionCode `7`。

## v0.1.2 TTS 优化

- 版本号更新为 `0.1.2+6`，本轮只修改 TTS 语言选择、设置和诊断提示。
- 默认使用美式 `en-US`，保留英式 `en-GB` 和跟随系统选项。
- `en_US`、`en-US-*` 等美式变体优先于其他地区英语；泛英语 `en` 只作最后降级。
- 设置页会显示实际语言和语音包缺失警告，测试单词改为 `academic`。
- 发音偏好保存在本地设置并包含在非敏感备份中；数据库 schema、DeepSeek 和学习流程未变更。
- `flutter analyze` 通过，83 项测试全部成功，Debug APK 构建成功。

## 当前发布状态

- 正式 Android applicationId 已由 `com.example.context_words` 修改为 `io.github.xianxian51.contextwords`。
- App 显示名称保持“语境单词本”。
- 数据库名称保持 `context_words.db`，数据库版本为 v6；本轮只安全新增学习翻译缓存字段，没有删除表或清空数据。
- DeepSeek API Key 仍由本地设置保存，未写入源码或备份。
- 发布前安全检查已通过，未发现真实密钥、签名文件或用户备份。
- App 版本已更新为 `0.1.3+7`，发布目标为 `v0.1.3` prerelease。
- DeepSeek 模型集中管理，默认 `deepseek-v4-pro`，保留 `deepseek-v4-flash`。
- 新增英语助手、Markdown AI 回复和 GitHub Releases 更新检测。
- 全文翻译继续保存到本地并复用缓存，不会因打开页面重复消耗 token。
- 每日自动准备、再来一组自动补阅读、精简首页、词库搜索、易混词分页及集合短文均已保留并覆盖测试。
- 公开 GitHub 仓库已创建并推送 `main`。
- `v0.1.2` 测试版 Release 已存在，附件为 `app-debug.apk`；本轮不覆盖旧 Release。
- GitHub 仓库：https://github.com/xianxian51/context_words
- Release：https://github.com/xianxian51/context_words/releases

## 包名迁移

旧测试包名与正式包名属于两个不同 Android App，本地数据不会自动继承。用户应在旧版导出学习数据，在正式包名版本中导入；确认迁移成功前不要卸载旧测试版。

后续只要保持 `io.github.xianxian51.contextwords`、相同签名证书和递增 versionCode，覆盖安装通常会保留本地数据。

## 验证结果

- `flutter pub get`：通过。
- `flutter analyze`：通过，`No issues found!`。
- `flutter test`：通过，88 项测试全部成功。
- `flutter build apk --debug`：成功；仅有插件未来迁移 Built-in Kotlin 的兼容性预警，不影响当前 APK。
- APK：`build/app/outputs/flutter-apk/app-debug.apk`
- APK SHA-256：`c89d2922106a816eb2f8b66830d146e2b41c72cad8d35d8ebdadf43d92ea8837`
- APK 清单：applicationId `io.github.xianxian51.contextwords`，versionName `0.1.3`，versionCode `7`。

## 已知问题

- Debug APK 仅供测试，Release APK 尚未配置正式签名。
- 从旧测试包名迁移需要手动导出/导入备份。
- DeepSeek 功能需要用户自行填写 API Key。
- Debug APK 不能作为正式生产包，且长期覆盖升级仍需要稳定的 Release 签名。
- GitHub API、DeepSeek API 和系统 TTS 的可用性仍取决于设备网络与系统配置。
- 启动更新检查包含 prerelease 列表查询，用户可在设置页关闭。

## v0.1.1 变更

- AI 模型选择保存到本地设置，所有 DeepSeek 调用统一使用所选模型。
- 英语助手最多发送最近 10 轮上下文，不会自动发起请求。
- 易混词辨析和助手回复使用 `flutter_markdown_plus` 渲染，链接不会自动打开。
- 更新检测读取本机版本并校验 GitHub 仓库链接，只负责提示和跳转。
- 数据库仍为 `context_words.db` v5，本轮没有 drop table、清库或 schema 变更。
