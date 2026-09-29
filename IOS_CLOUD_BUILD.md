# iOS 云打包与 TestFlight

已有项目：

- [Codemagic](https://codemagic.io/builds?app_id=6a7fb7902a6549e95461aba5)
- [App Store Connect](https://appstoreconnect.apple.com/apps/6808095729/testflight/ios)
- Apple App ID：`6808095729`
- Bundle ID：`com.consulting.consultingOnlineApp`，2026-09-29 已与 Apple 现有「Sana客服」App 核对一致。
- 原 TestFlight 最新构建：`1.0.0 (2)`；新构建自动递增编号。
- 新工作流：`ios-testflight`；原 `ios-build` 只生成未签名 `.app`。

## 一次性接入

1. App Store Connect → 用户和访问 → 集成 → App Store Connect API，创建供 Codemagic 使用的团队 API Key，选择 App Manager 权限。下载 `.p8`，记录 Key ID、Issuer ID。
2. Codemagic → Team settings → Team integrations → Developer Portal → Manage keys，添加上述密钥，引用名设为 `consulting-app-store`。私钥仅上传至该集成，不提交到仓库。
3. 本项目采用 Codemagic 官方 CLI 自动签名。在本应用的 `sana_ios_signing` 变量组中，将固定 RSA 签名私钥保存为加密变量 `CERTIFICATE_PRIVATE_KEY`；它与 Apple API 的 `.p8` 是不同用途的密钥。
4. 工作流初始化临时钥匙串，通过 `app-store-connect fetch-signing-files --type IOS_APP_STORE --create` 获取或创建匹配的分发证书及描述文件。后续构建复用同一私钥；不撤销已有证书，不需要原 Mac。
5. 将本 Flutter 目录的代码同步到 Codemagic 实际连接的仓库。当前 Git 远程 `flutter-github` 是独立 Flutter 仓库 `ericfetch/consulting_online_flutter`，该仓库根目录应直接包含 `codemagic.yaml`、`pubspec.yaml`、`ios/`、`lib/` 和 `scripts/`。不要把 PC/后端父仓库直接推送到这里。
6. Codemagic 选择最新分支 → Check for configuration file → Start new build → `ios-testflight`。

## 每次构建的行为

流程先核对 Apple App ID 与 Bundle ID，读取全部 iOS TestFlight 版本中的最新构建号并递增，再安装依赖、运行检查、应用签名、生成 `.ipa`、上传至 App Store Connect。

iOS 使用独立构建号，避免把 `pubspec.yaml` 的 Android 日期构建号直接传给 Apple。营销版本号仍取自 `pubspec.yaml`（当前为 `1.0.1`）。同一 App 不要同时启动两次发布构建，避免同时取得相同的下一构建号。读取 Apple 失败时会停止，不会回退到旧号。

云端固定 Flutter `3.38.10`、Xcode `26.2`、CocoaPods `1.16.2`，Android 工具链保持原配置。首次云端构建需验证现有依赖对该 iOS 工具链的兼容性。

上传完成后需等待 Apple 处理，才能在 TestFlight 选择构建并分发给测试组。工作流不提交 App Store 审核，也不自动提交外部测试 Beta Review；`submit_to_testflight: false` 控制的是后者，不会关闭 IPA 上传。测试组沿用现有设置。

## 费用约束

保持 Codemagic Personal Account 免费计划，使用 `mac_mini_m2`。2026-09-29 核对本月免费额度使用量为 `0 / 500` 分钟，未启用付费订阅。工作流单次上限 60 分钟；启动前检查免费余量，不开通付费团队、额外额度或订阅。Apple 的“团队 API 密钥”是权限类型名称，不代表 Codemagic 付费团队。

## 官方说明

- [Codemagic 签名与证书](https://docs.codemagic.io/yaml-code-signing/signing-ios/)
- [Codemagic 上传至 App Store Connect](https://docs.codemagic.io/yaml-publishing/app-store-connect/)
- [Codemagic 自动版本号](https://docs.codemagic.io/knowledge-codemagic/build-versioning/)
- [Apple 上传要求](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/)
