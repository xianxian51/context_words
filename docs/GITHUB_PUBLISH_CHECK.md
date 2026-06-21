# GitHub 发布环境检查报告

> 历史审计：本报告记录 2026-06-21 11:03 的发布前状态，已由 [GITHUB_READY_CHECK.md](GITHUB_READY_CHECK.md) 取代。请以新报告和 `PROJECT_STATUS.md` 为准。

## 1. 检查时间

- 时间：2026-06-21 11:03:34 CST（Asia/Shanghai）
- 项目：`context_words` / 语境单词本
- 检查目录：`/Users/zrz/Documents/Codex/2026-06-15/flutter-app-context-words-agent-skills/context_words`
- 本轮仅执行环境、权限、安全、构建和发布条件检查；未提交、推送、创建仓库、创建 Release 或上传 APK。

## 2. Git 环境状态

- Git：可用
- 版本：`git version 2.54.0`
- 全局用户名：未配置
- 全局邮箱：未配置

结论：Git 命令可用，但首次提交前需要配置提交身份。

## 3. GitHub CLI 状态

- `gh`：未安装，终端返回 `command not found: gh`
- `gh auth status`：无法执行
- `gh api user`：按要求未继续执行
- GitHub API 访问与账号权限：未验证

需要先安装 GitHub CLI，然后由用户主动执行：

```bash
gh auth login
```

本轮未自动安装或登录。

## 4. GitHub 登录状态

当前无法判断是否已登录，因为 `gh` 未安装。GitHub 登录和 token scope 均未验证。

## 5. 当前 Git 仓库状态

- `context_words` 目录不是 Git 仓库。
- 上一级工作目录也不是 Git 仓库。
- 当前分支：不存在。
- 未提交更改：无法通过 Git 判断。
- 当前 remote：不存在。

## 6. 当前 Remote 状态

没有 Git 仓库，因此没有 `origin` 或其他 remote。后续建议仓库名：`context_words`。

## 7. 敏感信息检查结果

未发现真实 DeepSeek API Key、GitHub token、密码、签名密钥或用户学习数据备份。

已区分的正常命中：

- `lib/core/services/settings_service.dart` 中的 `deepseek_api_key` 是 SharedPreferences 键名，不是密钥内容。
- 测试中的 `test-key`、`secret-key-must-stay-out-of-the-prompt`、`must-not-be-exported` 是测试占位值，不是真实凭据。
- DeepSeek 请求代码通过运行时参数设置 `Authorization`，没有硬编码个人 API Key。
- 备份测试确认导出 JSON 不包含 `deepseek_api_key` 或其值。

文件检查：

- 未发现 `*.jks`、`*.keystore`、`key.properties`。
- 未发现 `context_words_backup_*.json` 用户备份文件。
- 未发现 `.aab`。
- 发现两个 Debug APK，均位于 `build/` 生成目录，没有放在源码目录根部。
- 发现 iOS/macOS 的 `flutter_native_integration.env`，均位于 Flutter `ephemeral` 生成目录，并由平台 `.gitignore` 规则排除。
- `android/local.properties` 包含本机 SDK 路径，但由 `android/.gitignore` 的 `/local.properties` 排除。

## 8. `.gitignore` 检查结果

当前规则已覆盖：

- `/build/`
- `.dart_tool/`
- `.DS_Store`
- Android 的 `.gradle`、`local.properties`、`key.properties`、`*.jks`、`*.keystore`
- iOS/macOS 的 Flutter `ephemeral` 目录

根 `.gitignore` 仍缺少以下显式规则：

- `.gradle/`
- `android/.gradle/`
- `android/key.properties`
- `*.jks`
- `*.keystore`
- `local.properties`
- `.env`
- `backups/`
- `context_words_backup_*.json`
- `*.apk`
- `*.aab`

部分项目已被子目录规则或 `/build/` 间接覆盖，但根规则不足以防止文件被误放到其他目录后提交。发布前建议补齐；本轮未自动修改。

## 9. README / LICENSE 检查结果

- `README.md`：存在，但仍是 Flutter 默认模板。
- README 项目用途：未完整说明。
- README DeepSeek API Key 配置：未说明。
- README 不内置个人 API Key：未说明。
- 项目根 `LICENSE`：缺失。
- 项目内 `docs/PROJECT_STATUS.md`：缺失。
- 项目内 `docs/USER_GUIDE.md`：缺失。
- 现有 `PROJECT_STATUS.md` 与 `USER_GUIDE.md` 位于项目上一级目录；如果只把 `context_words` 初始化为仓库，它们不会被包含。
- `assets/wordbooks/ECDICT_LICENSE.txt`：存在，MIT License。
- `assets/wordbooks/CET_WORD_LIST_LICENSE.txt`：存在，MIT License。
- `assets/wordbooks/cet6.json`：存在并由 `pubspec.yaml` 的 `assets/wordbooks/` 注册。

结论：词库授权文件已保留，但项目自身的开源许可证和发布说明尚未就绪。

## 10. Flutter Analyze 结果

- `flutter pub get`：通过。
- `flutter analyze`：通过，`No issues found!`。
- 依赖解析提示 12 个包存在受当前约束限制的新版本，不影响本次构建。

## 11. Flutter Test 结果

- `flutter test`：通过。
- 共 66 项测试通过。
- 覆盖数据库迁移保留旧数据、备份合并恢复、不导出 DeepSeek API Key 等关键安全行为。

## 12. APK 构建结果

- 命令：`flutter build apk --debug`
- 结果：成功。
- APK：`build/app/outputs/flutter-apk/app-debug.apk`
- 大小：约 151 MB。
- SHA-256：`2e45af3ae39b9589e65b6d8b9a13d685855668060af34d897c6ebe244f00561c`

构建警告：`file_picker`、`flutter_tts`、`share_plus` 当前仍应用 Kotlin Gradle Plugin；未来 Flutter 版本可能要求迁移 Built-in Kotlin。该警告不影响本次 Debug APK，但升级 Flutter 前需要复核插件兼容性。

## 13. APK 路径

绝对路径：

`/Users/zrz/Documents/Codex/2026-06-15/flutter-app-context-words-agent-skills/context_words/build/app/outputs/flutter-apk/app-debug.apk`

APK 位于被忽略的 `build/` 目录，不应加入源码仓库 main 分支。后续可作为测试版 GitHub Release 附件，但本轮未上传。

## 14. Android Application ID

- applicationId：`com.example.context_words`
- namespace：`com.example.context_words`
- App 名称：`语境单词本`
- INTERNET 权限：主 Manifest 已声明。

包名当前稳定，不能在未规划数据迁移和升级路径时随意修改。

## 15. Version Name / Version Code

- `versionName`：`1.0.3`
- `versionCode`：`4`
- 来源：`pubspec.yaml` 的 `version: 1.0.3+4`

建议首次 GitHub Release 标签为 `v0.1.0`，但标签与 APK 内部版本当前并不一致。发布前应决定版本命名策略；本轮未修改。

## 16. 数据库与迁移安全检查

- 数据库名称：`context_words.db`
- 数据库版本：`5`
- `onUpgrade` 使用 `CREATE TABLE`、`ALTER TABLE ADD COLUMN`、表重命名和数据复制。
- 生产代码未发现 `DROP TABLE` 或 `deleteDatabase`。
- `deleteDatabase` 仅出现在测试清理代码中。
- v2 到 v3 的迁移会保留 `reading_passages_v2_backup` 和 `study_logs_v2_backup` 备份表；这不会清空数据，但会保留冗余表。
- v4 到 v5 迁移先检查列是否存在，再添加翻译字段。
- 自动化测试确认旧阅读内容、学习状态和新增字段在迁移后仍可查询。

覆盖安装理论上会保留 SQLite、SharedPreferences 和其他 App 私有数据，但必须同时满足：

1. applicationId 不变；
2. 新旧 APK 使用同一签名证书；
3. 新 APK 的 versionCode 不低于已安装版本；
4. 用户不先卸载旧 App。

当前 Release 构建配置仍使用 debug 签名。相同 Mac 上同一 debug keystore 构建的 Debug APK通常可以覆盖更新；如果换机器、换 debug keystore，或改用新的正式签名证书，可能无法直接覆盖现有 Debug 安装。切换正式签名前应先导出学习数据并规划迁移。

## 17. GitHub Release 发布条件

- 使用 `gh` 创建仓库：当前不可以，`gh` 未安装且未登录。
- 使用 `gh` 创建 Release：当前不可以，`gh` 未安装且未登录。
- Remote：不存在。
- 建议仓库名：`context_words`。
- 建议首次 Release：`v0.1.0`。
- Debug APK：可用于内部测试版或 prerelease，不建议作为正式生产包。
- Release APK：正式发布需要独立、长期保管的 release keystore。
- 当前正式签名：未配置；`release` 构建仍引用 debug signing config。
- Keystore 排除：`android/.gitignore` 已排除 Android 目录下的 `*.jks`、`*.keystore` 和 `key.properties`，但建议在根 `.gitignore` 再显式覆盖。

## 18. 是否可以安全上传 GitHub

当前结论：**尚不具备安全上传条件**。

代码未发现真实敏感信息，Flutter 验证和 Debug APK 构建均通过；阻塞项是发布基础设施和开源材料不完整，而不是 App 功能或构建失败。

缺少条件：

1. 安装 GitHub CLI 并由用户执行 `gh auth login`。
2. 配置 Git 全局用户名和邮箱。
3. 初始化 Git 仓库并确定仓库根目录。
4. 创建完整项目 README，说明用途、安装、DeepSeek API Key 由用户本地填写且不内置个人密钥。
5. 为项目选择并添加根 `LICENSE`。
6. 补齐根 `.gitignore` 的敏感文件、备份和 APK/AAB 规则。
7. 将需要发布的 `PROJECT_STATUS.md`、`USER_GUIDE.md` 纳入选定仓库根目录。
8. 正式发布前配置稳定的 release signing；仅测试分发可继续使用 Debug APK。
9. 确认 GitHub Release 标签与 App 内部版本号的对应策略。

## 19. 下一步建议

建议先人工完成文档、许可证和忽略规则，再执行以下命令。以下命令仅供后续参考，本轮没有执行：

```bash
brew install gh
gh auth login

git config --global user.name "你的 Git 用户名"
git config --global user.email "你的 Git 邮箱"

cd /Users/zrz/Documents/Codex/2026-06-15/flutter-app-context-words-agent-skills/context_words
git init
git branch -M main
git status --short
```

确认敏感扫描、README、LICENSE、`.gitignore` 和仓库根目录无误后，再考虑：

```bash
git add .
git status --short
git commit -m "Initial release"
gh repo create context_words --public --source=. --remote=origin
git push -u origin main
```

测试版 Release 可在用户明确授权后使用 `v0.1.0` 和 Debug APK；正式 Release 应先配置长期稳定的 release 签名并构建 Release APK。

## 20. 审计边界

- 因 `gh` 未安装，未验证 GitHub 账号、组织权限、仓库创建权限、Release 权限或 API 连通性。
- 因当前不是 Git 仓库，无法判断哪些文件会被 Git 跟踪，也无法使用 `git status --short` 审计待提交清单。
- 本轮没有修改 App 功能、DeepSeek 模型、代码逻辑、Android 包名、数据库或签名配置。
