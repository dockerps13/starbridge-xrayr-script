# Starbridge XrayR Install

统一安装入口：

```bash
bash <(curl -Ls https://raw.githubusercontent.com/dockerps13/starbridge-xrayr-script/master/install.sh)
```

默认下载来源：

```text
https://github.com/dockerps13/starbridge-xrayr/releases/download/v0.9.4/XrayR-linux-64.zip
```

安装脚本会按 CPU 架构自动选择对应的 `XrayR-*.zip` 包，并校验 sha256。

linux-amd64 sha256：

```text
5403225a5e4f7b6d279c1fb43d0e0e9468dea5c57c52ab7cff81571aca43c11e
```

说明：

- 安装脚本默认从 `dockerps13/starbridge-xrayr` 下载 release。
- 安装脚本默认使用兼容旧习惯的 `XrayR-*.zip` 多架构包名。
- 安装前会校验 sha256。
- 不会覆盖已有 `/etc/XrayR/config.yml`。
- 默认会应用安全网络优化，但不会安装 BBRPlus、不会换内核、不会自动重启服务器。
