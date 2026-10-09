# SHUO Android v1.0.2 启动闪退修复

## 原因与修复

安卓 v1.0.1 修复了 `MissingPluginException` 后，用户报告：应用能展示并接受免责声明，但在进入后台服务/内核初始化阶段闪退；再启动会显示“上次异常退出”，点击后再次闪退。

代码排查发现，SHUO 在 v1.0.0 独立包名时移除了 Firebase 配置，但 `GlobalState.kt` 仍旧调用 `FirebaseApp.initializeApp` 和 `FirebaseCrashlytics.getInstance`，`ServiceStateMachine.applySharedState()` 在核心配置阶段同步调用这个方法。未配置 FirebaseApp 时存在触发 `IllegalStateException` 并在后台协程中终止进程的风险。

Android v1.0.2 禁用原版 Firebase Crashlytics 初始化，移除 Android common 模块中不再需要的 Firebase 依赖。保留 Android 系统 `getHistoricalProcessExitReasons` 的崩溃恢复记录，核心代理与智能优选逻辑不变。

- Android 包名保持 `com.shuowang.flclash.custom`
- Android 应用版本升级 `1.0.2+10002`
- 智能优选功能版本继续保持 `1.0.0`
- 从原固定密钥文件恢复证书并校验 SHA-256，支持覆盖安装 v1.0.0/v1.0.1
- Windows v1.0.0 不受影响
- 回归测试校验原生代码不再引用未配置的 Firebase 初始化、通道名仍一致，Kotlin 测试和签名发行包构建通过后再发布
- 尚需用户在真实手机上验证，不能仅凭 CI 保证闪退已完全解决
