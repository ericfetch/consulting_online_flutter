# 客服移动工作台

默认连接 `https://consulting.sanain.com`，使用现有客服账号登录。

## 2026-09-29 同步

- 在线、忙碌、离线仅由客服手动修改。读取设置、重连和发送消息不会修改接待状态；新旧状态响应按更新时间合并。
- AI 结果跟随触发消息显示，可折叠；回复原文下显示中文，点击仅回填面向客户的原文。新消息不作废已有建议。
- 共用一个输入框，左侧 `@` 提供翻译、回复建议、分析入口。中文快捷回复由助手转换为符合客户语言及上下文的草稿。
- 每条消息显示发送时间并支持一键复制；译文、图片识别和语音转写对应到原消息，失败附件支持重试。
- 会话列表显示“已提交 / 已汇总”；聊天菜单支持资料填写链接、汇总资料及客户档案。客户档案支持编辑、附件保存、医生 PDF 导出，默认不包含客服备注。
- 管理端概览使用后端统一统计，页面可见时每 5 秒刷新；切换账号清理对应页面状态。

模型和媒体识别配置沿用服务端配置，不在安装包中保存模型密钥。PDF 内容和隐私规则由服务端导出接口统一控制。

## 客户跟踪（Android 2026092902 / iOS 下次云构建）

客户资料列表及会话中的客户档案已接入 PC 同一套跟踪接口：

- 12 个阶段从“待通知”到“已完结”，列表可按阶段、负责人筛选，并显示已通知和最近跟进时间。
- 通知、补充通知、失败重试由后端生成或复用医生 PDF 并发送飞书，手机不保存群密钥。只有服务器确认成功才进入待匹配医生；结果未确认时先核对群内消息。
- 更新阶段、调整负责人、单独加备注，保留操作者和时间；历史记录分页显示，通知中的 PDF 链接可撤销。
- 并发编辑校验版本；冲突保留备注草稿，按最新进度继续。相同操作重试沿用请求 ID，避免重复备注或通知。
- 页面可见时每 15 秒刷新，通知处理中每 3 秒刷新；退到后台暂停。资料编辑不再写入旧 `stage` 字段，跟进记录不进入医生 PDF。

沿用已部署的 `/api/customer-followup`，本次移动端同步不需要新后端迁移。iOS 使用 Codemagic `main` 分支的 `ios-testflight` 手动构建；Android 使用原签名覆盖安装，保留应用数据。

## iOS 云打包

Codemagic 的 `ios-testflight` 流程支持签名 IPA、独立递增 iOS 构建号及上传已有 TestFlight App。首次需连接 Apple API Key、分发证书和描述文件，见 [iOS 云打包配置](IOS_CLOUD_BUILD.md)。

## 检查与打包

```powershell
flutter analyze --no-pub
flutter test --no-pub
flutter build apk --release --target-platform android-arm64 --no-pub
```

此仓库禁止自动启动应用。安装时使用 `adb install -r` 保留现有数据，安装后由使用者手动打开。

若当前 Windows 环境出现 Java `Unable to establish loopback connection`，可为本次构建指定正常文件系统内的 IPC 临时目录：

```powershell
$taskJavaTemp = Join-Path (Get-Location) '../tmp/flutter-sync/java-tmp'
New-Item -ItemType Directory -Path $taskJavaTemp -Force | Out-Null
$env:JAVA_TOOL_OPTIONS = '-Djdk.net.unixdomain.tmpdir=' + (Resolve-Path $taskJavaTemp).Path
flutter build apk --release --target-platform android-arm64 --no-pub
```

当前 Android release 沿用项目既有的 debug 签名，适用于现有测试手机覆盖安装；正式商店发布需另行配置发布签名。
