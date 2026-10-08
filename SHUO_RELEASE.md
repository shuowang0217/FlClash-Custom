# FlClash SHUO Custom — 智能优选 v1.0.0

定制者：shuowang0217；基于 [FlClash](https://github.com/chen08209/FlClash)（GPL-3.0）。**这是独立的社区定制版本，不是上游官方发布。**

应用 v1.0.0+10000，智能优选功能 v1.0.0。Windows 有独立安装器 AppId、应用显示名和 FlClash-SHUO.exe；Android 包名 com.shuowang.flclash.custom（debug 自动追加 .dev）。版本检查指向本 Fork 的 GitHub Releases，而非上游版本。
shuo-version.json 提供最新和最低支持功能版本：v1.0.0 后的新版本检测到低于最低版本时停止自动优选并提示升级；离线时允许原有代理功能。早期测试版不含此检查，无法被追溯约束。
Android 的正式签名必须使用永久保存的私有 release keystore，后续版本必须用同一密钥签名；无签名时只能提供 debug 测试 APK，不得冒充正式版。
Windows 可能与原版共享内核辅助服务/系统代理/TUN，因此不要同时运行两个客户端。备份旧配置后再安装，独立应用不会自动迁移配置。

## v1.0.0 当前质量说明

签名恢复自测、智能优选专项测试与 Windows/Android 正式包的云端构建均已通过。上游完整 Dart 测试目前仍有旧界面布局及规范测试不通过；本版按用户自用版发布，不宣称完整 CI 全绿。后续需持续补齐 UI 测试和兼容性验证。
