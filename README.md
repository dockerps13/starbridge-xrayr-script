# XrayR-script

Installer and management script for dockerps13/starbridge-xrayr.

一键安装命令：

```bash
bash <(curl -Ls https://raw.githubusercontent.com/dockerps13/starbridge-xrayr-script/master/install.sh)
```

普通用户只需要这一条命令。它会自动安装或更新 XrayR、识别 CPU 架构、应用安全网络优化、写入 systemd limits，并在安装完成后输出当前 BBR、qdisc、XrayR 版本和 XrayR 状态。

默认安装版本：

```text
XrayR v0.9.5
```

默认安装来源：

```text
https://github.com/dockerps13/starbridge-xrayr/releases/tag/v0.9.5
```

默认下载包：

```text
https://github.com/dockerps13/starbridge-xrayr/releases/download/v0.9.5/XrayR-linux-64.zip
```

安装脚本会按 CPU 架构自动选择对应的 `XrayR-*.zip` 包，并校验 sha256。

linux-amd64 sha256：

```text
00abc31d798d2fb16cf6ed9e8d5d2f94a6ad7772455090d9791c6e84c138a826
```

安装目录：

```text
/usr/local/XrayR
```

配置目录：

```text
/etc/XrayR
```

systemd 服务：

```text
/etc/systemd/system/XrayR.service
```

默认网络优化：

```text
安装/更新时会自动应用安全网络优化：系统原生 BBR、fq、高并发 sysctl 参数和 systemd limits。
如果机器已经是 bbrplus，会保留当前 bbrplus。
默认不会安装 BBRPlus，不会更换内核，不会自动重启服务器。
不会覆盖 /etc/XrayR/config.yml。
修改 /etc/sysctl.conf 前会自动备份，并清理重复的 bbr/bbrplus/default_qdisc 等网络参数。
```

手动只应用网络优化：

```bash
bash <(curl -Ls https://raw.githubusercontent.com/dockerps13/starbridge-xrayr-script/master/install.sh) optimize
```

高级 BBRPlus 选项：

```bash
bash <(curl -Ls https://raw.githubusercontent.com/dockerps13/starbridge-xrayr-script/master/install.sh) --enable-bbrplus
```

BBRPlus 可能更换内核、需要重启服务器，并导致线上节点断开；脚本只在交互确认后执行。

支持命令：

```bash
XrayR install
XrayR update
XrayR uninstall
XrayR version
```

当前 release 包：

| Machine | Release asset |
|---|---|
| x86_64 / amd64 | XrayR-linux-64.zip |
| i386 / i686 / 386 | XrayR-linux-32.zip |
| arm64 / aarch64 | XrayR-linux-arm64-v8a.zip |
| armv7 | XrayR-linux-arm32-v7a.zip |
| armv6 | XrayR-linux-arm32-v6.zip |
| mips | XrayR-linux-mips-softfloat.zip |
| mipsle | XrayR-linux-mipsle-softfloat.zip |
| mips64 | XrayR-linux-mips64.zip |
| mips64le | XrayR-linux-mips64le.zip |
| s390x | XrayR-linux-s390x.zip |
| ppc64le | XrayR-linux-ppc64le.zip |

新仓库 release 里也保留了 `starbridge-xrayr-linux-amd64-v0.9.5-e85c6e6.tar.gz`，用于手动下载；一键安装脚本默认使用兼容旧习惯的 `XrayR-*.zip` 包名。

安装完成后可以验证：

```bash
/usr/local/XrayR/XrayR -version
```

期望输出：

```text
XrayR 0.9.4
```
