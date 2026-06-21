# GitHub 开源发布检查

最后更新：2026-06-21

## 身份与仓库

- GitHub CLI：`gh 2.95.0`
- GitHub 用户：`xianxian51`
- Git 用户名：`xianxian51`
- Git 邮箱：`180631472+xianxian51@users.noreply.github.com`
- 本地分支：`main`
- Remote：`origin` → `https://github.com/xianxian51/context_words.git`
- 公开仓库：https://github.com/xianxian51/context_words

## Android 标识

- 正式 applicationId：`io.github.xianxian51.contextwords`
- namespace：`io.github.xianxian51.contextwords`
- MainActivity package：`io.github.xianxian51.contextwords`
- App 显示名称：`语境单词本`
- 数据库：`context_words.db`，schema v5

旧测试包名 `com.example.context_words` 与正式包名属于不同 Android App，本地数据不会自动继承。迁移时应在旧版导出学习数据，再在正式版导入。

## 开源与安全材料

- `README.md`：已完成
- `LICENSE`：MIT License
- `.gitignore`：已排除构建目录、APK/AAB、环境文件、Android 签名文件和用户备份
- CET-6 词库与两份第三方 MIT License：保留
- DeepSeek API Key：仅由用户在本地设置，不写入源码和备份

## 发布闸门

- 敏感信息扫描：通过，未发现真实密钥、签名文件或用户备份
- `flutter analyze`：通过，`No issues found!`
- `flutter test`：通过，66 项测试成功
- Debug APK：构建成功，APK 清单确认 package 为 `io.github.xianxian51.contextwords`、应用名为“语境单词本”
- 首次 Git commit：`0ebb2eb`（`Initial open-source release of Context Words`）
- GitHub 仓库：创建成功，`main` 已推送
- GitHub Release：`v0.1.0` prerelease 创建成功
- Release 地址：https://github.com/xianxian51/context_words/releases/tag/v0.1.0
- Release 附件：`app-debug.apk`，状态 `uploaded`

## Release 约束

- 标签：`v0.1.0`
- APK：`build/app/outputs/flutter-apk/app-debug.apk`
- APK SHA-256：`ae63bd5633eb8bdd8da9423ba197cbfb09d7fa4003a557aaa16469c8c12cc765`
- Debug APK 仅供测试，不适合正式生产发布
- Release APK 尚未配置长期稳定的正式签名
- APK 只能作为 GitHub Release 附件，不进入 main 分支
