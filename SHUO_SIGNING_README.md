# SHUO 固定签名，电脑无需安装任何工具

1. 打开 GitHub 仓库 Settings → Secrets and variables → Actions → Repository secrets → New repository secret。
2. 名称填写 SHUO_SIGNING_PASSWORD。值为至少 40 位随机字母、数字或 - 与 _ 组合的强密码。不要发到聊天、Issues 或工作流输入框。
3. 把密码备份到私人密码管理器，之后回复“已配置签名密码”。后续由仓库源码推送触发 GitHub Actions，一次性生成签名。

云端临时运行器使用 JDK 17 生成 PKCS12 签名证书，scrypt 派生密钥后用 AES-256-GCM 加密签名文件；只把加密数据 android/signing/shuo-release.jks.enc 提交到 GitHub。明文私钥绝不上传到 GitHub Artifact 或源码。
以后的正式 APK 使用同一加密文件和 GitHub Secret 解密签名。该文件和密码都必须永久保留，遗失任何一项均可能导致无法覆盖升级。

密码长度和随机性是安全关键：加密文件若可被访问，弱密码可能被猜出。请用强随机密码，并在安全地方留存。
