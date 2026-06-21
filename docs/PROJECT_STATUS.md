# 语境单词本项目状态

最后更新：2026-06-21

## 当前发布状态

- 正式 Android applicationId 已由 `com.example.context_words` 修改为 `io.github.xianxian51.contextwords`。
- App 显示名称保持“语境单词本”。
- 数据库名称保持 `context_words.db`，数据库版本保持 v5；本轮没有修改 schema、删除表或清空数据。
- DeepSeek API Key 仍由本地设置保存，未写入源码或备份。
- 发布前安全检查已通过，未发现真实密钥、签名文件或用户备份。
- `flutter analyze` 已通过，66 项测试全部成功。
- 使用正式包名构建 Debug APK 成功，APK 清单确认应用名仍为“语境单词本”。
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
- `flutter test`：通过，66 项测试全部成功。
- `flutter build apk --debug`：成功。
- APK：`build/app/outputs/flutter-apk/app-debug.apk`
- SHA-256：`ae63bd5633eb8bdd8da9423ba197cbfb09d7fa4003a557aaa16469c8c12cc765`
- GitHub Release 附件摘要与本地 SHA-256 一致。

## 已知问题

- Debug APK 仅供测试，Release APK 尚未配置正式签名。
- 从旧测试包名迁移需要手动导出/导入备份。
- DeepSeek 功能需要用户自行填写 API Key。
- App 内 GitHub Releases 更新检测尚未实现；当前通过仓库 Release 页面手动下载新版。
- 当前代码实际使用 `deepseek-chat`，尚未接入 README 中标记为规划项的 V4 模式。
