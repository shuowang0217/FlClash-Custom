# Android v1.0.1 紧急修复

正式版 v1.0.0 安卓 APK 有已知启动错误：`MissingPluginException(No implementation found for method init on channel com.shuowang.flclash.custom/service)`。

**根因**：Dart 在 1.0.0 改用 `com.shuowang.flclash.custom` 通道，而 Kotlin 原生插件仍注册 `com.follow.clash`。修复版统一 App、Service、Tile 三个原生 MethodChannel 注册命名空间，保留 Kotlin/Android 命名空间 `com.follow.clash`，不改变原有服务类路径。

- Android 版本：1.0.1+10001（**与 Windows v1.0.0 相互独立**）
- 功能版本：智能优选 v1.0.0，逻辑不变
- 包名：`com.shuowang.flclash.custom`，不变
- **签名**：恢复原来云端 AES-256-GCM 加密签名，证书 SHA-256 应与 v1.0.0 相同。不得重新生成密钥
- 使用者直接安装 v1.0.1 APK 覆盖 Android v1.0.0，不必卸载或清空配置
- 如代理内核启动出现错误，请导出日志；不要卸载以免丢失配置
- Windows v1.0.0 已经通过实际使用验证，本次不修改 Windows 功能或安装程序
