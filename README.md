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
