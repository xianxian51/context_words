# 语境单词本项目状态

最后更新：2026-06-21

## 当前发布状态

- 正式 Android applicationId 已由 `com.example.context_words` 修改为 `io.github.xianxian51.contextwords`。
- App 显示名称保持“语境单词本”。
- 数据库名称保持 `context_words.db`，数据库版本保持 v5；本轮没有修改 schema、删除表或清空数据。
- DeepSeek API Key 仍由本地设置保存，未写入源码或备份。
- 发布前安全检查已通过，未发现真实密钥、签名文件或用户备份。
- App 版本已更新为 `0.1.1+5`，发布目标为 `v0.1.1` prerelease。
- DeepSeek 模型集中管理，默认 `deepseek-v4-pro`，保留 `deepseek-v4-flash`。
- 新增英语助手、Markdown AI 回复和 GitHub Releases 更新检测。
- 全文翻译继续保存到本地并复用缓存，不会因打开页面重复消耗 token。
- 每日自动准备、再来一组自动补阅读、精简首页、词库搜索、易混词分页及集合短文均已保留并覆盖测试。
- 公开 GitHub 仓库已创建并推送 `main`。
- `v0.1.0` 测试版 Release 已创建，附件为 `app-debug.apk`。
- GitHub 仓库：https://github.com/xianxian51/context_words
- Release：https://github.com/xianxian51/context_words/releases/tag/v0.1.0

## 包名迁移

旧测试包名与正式包名属于两个不同 Android App，本地数据不会自动继承。用户应在旧版导出学习数据，在正式包名版本中导入；确认迁移成功前不要卸载旧测试版。

后续只要保持 `io.github.xianxian51.contextwords`、相同签名证书和递增 versionCode，覆盖安装通常会保留本地数据。

## 验证结果

- `flutter pub get`：通过。
- `flutter analyze`：通过，`No issues found!`。
- `flutter test`：通过，75 项测试全部成功。
- `flutter build apk --debug`：成功；仅有插件未来迁移 Built-in Kotlin 的兼容性预警，不影响当前 APK。
- APK：`build/app/outputs/flutter-apk/app-debug.apk`
- APK SHA-256：`85f43ef89c2b0e5d358ff21c8a21987f4a2414ba913c532865ed0851ad9cc058`
- APK 清单：applicationId `io.github.xianxian51.contextwords`，versionName `0.1.1`，versionCode `5`。

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
