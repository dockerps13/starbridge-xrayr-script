#!/usr/bin/env bash

set -euo pipefail

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

OWNER="dockerps13"
REPO="starbridge-xrayr"
SCRIPT_REPO="starbridge-xrayr-script"
DEFAULT_VERSION="v0.9.4"
DEFAULT_COMMIT="0e810e0"
INSTALL_DIR="/usr/local/XrayR"
CONFIG_DIR="/etc/XrayR"
SERVICE_FILE="/etc/systemd/system/XrayR.service"
MANAGER_BIN="/usr/bin/XrayR"
MANAGER_BIN_LOWER="/usr/bin/xrayr"
SYSCTL_CONF="/etc/sysctl.conf"

log_info() {
    echo -e "${green}$*${plain}"
}

log_warn() {
    echo -e "${yellow}$*${plain}"
}

log_error() {
    echo -e "${red}$*${plain}" >&2
}

need_root() {
    if [[ ${EUID} -ne 0 ]]; then
        log_error "错误：必须使用 root 用户运行此脚本。"
        exit 1
    fi
}

normalize_version() {
    local version="${1:-$DEFAULT_VERSION}"
    if [[ -z "$version" ]]; then
        version="$DEFAULT_VERSION"
    fi
    if [[ "$version" != v* ]]; then
        version="v${version}"
    fi
    echo "$version"
}

detect_arch() {
    local machine
    machine="$(uname -m | tr '[:upper:]' '[:lower:]')"
    case "$machine" in
        x86_64|amd64)
            echo "XrayR-linux-64.zip"
            ;;
        i386|i686|386)
            echo "XrayR-linux-32.zip"
            ;;
        aarch64|arm64)
            echo "XrayR-linux-arm64-v8a.zip"
            ;;
        armv7l|armv7|armhf)
            echo "XrayR-linux-arm32-v7a.zip"
            ;;
        armv6l|armv6)
            echo "XrayR-linux-arm32-v6.zip"
            ;;
        mips)
            echo "XrayR-linux-mips-softfloat.zip"
            ;;
        mipsle)
            echo "XrayR-linux-mipsle-softfloat.zip"
            ;;
        mips64)
            echo "XrayR-linux-mips64.zip"
            ;;
        mips64le)
            echo "XrayR-linux-mips64le.zip"
            ;;
        s390x)
            echo "XrayR-linux-s390x.zip"
            ;;
        ppc64le)
            echo "XrayR-linux-ppc64le.zip"
            ;;
        *)
            log_error "不支持的系统架构：${machine}"
            exit 2
            ;;
    esac
}

sha256_for_asset() {
    local asset="$1"
    case "$asset" in
        XrayR-linux-64.zip) echo "5403225a5e4f7b6d279c1fb43d0e0e9468dea5c57c52ab7cff81571aca43c11e" ;;
        XrayR-linux-arm64-v8a.zip) echo "3de3cf292dd676b1cf00976be5f3456cc96639f8e68cc75a2ecad59ec270ff89" ;;
        XrayR-linux-arm32-v7a.zip) echo "5ad15a54bec567ffda84fc0999560748d5ce3bf51a27d53e85bc66a5cd370b74" ;;
        XrayR-linux-arm32-v6.zip) echo "c9ae961d846cd2761eb33d52b6f1a9cccc230fc7aae8dd4a19a50c16614d01f3" ;;
        XrayR-linux-32.zip) echo "59b29a6f2e767f129dce8176a5decaff763dfc9c15d897be59c5cda929f48fbc" ;;
        XrayR-linux-mips-softfloat.zip) echo "68d43f8d50e6d3eeac98818481bb66e1875e5e8b6c466e9408787823d2463aa9" ;;
        XrayR-linux-mipsle-softfloat.zip) echo "bfbea676245ab91007abc7ba4a6ea5176dff6bcd09d6ae99f52ff28cf918468c" ;;
        XrayR-linux-mips64.zip) echo "50f270ab3942cb66254af23a8e01186b6eb2f7773e00467122b6399716d09948" ;;
        XrayR-linux-mips64le.zip) echo "011b6f4196f346e3437edf811dbec2744d40aedfb5ab81cdb4940249ce35e8ac" ;;
        XrayR-linux-s390x.zip) echo "0d7a299320f4eeee649805137051ce58392f07266830f4f9d8d1f160fa7bac17" ;;
        XrayR-linux-ppc64le.zip) echo "e2371f23db0fd09511330fa2c411fad658c7ce8a86b621d44be3e053ce42dc74" ;;
        *)
            log_error "未配置 ${asset} 的 sha256，停止安装。"
            exit 1
            ;;
    esac
}

install_base() {
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update -y
        DEBIAN_FRONTEND=noninteractive apt-get install -y curl ca-certificates unzip
    elif command -v yum >/dev/null 2>&1; then
        yum install -y curl ca-certificates unzip
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y curl ca-certificates unzip
    else
        log_error "未找到 apt-get/yum/dnf，请手动安装 curl、ca-certificates、unzip 后重试。"
        exit 1
    fi
}

download_file() {
    local url="$1"
    local output="$2"
    curl -fL --connect-timeout 15 --retry 3 --retry-delay 2 -o "$output" "$url"
}

verify_file_sha256() {
    local file="$1"
    local expected="$2"
    local actual
    actual="$(sha256sum "$file" | awk '{print $1}')"
    if [[ "$actual" != "$expected" ]]; then
        log_error "sha256 校验失败："
        log_error "  文件：$file"
        log_error "  期望：$expected"
        log_error "  实际：$actual"
        exit 1
    fi
    log_info "sha256 校验通过：${actual}"
}

write_service() {
    cat > "$SERVICE_FILE" <<'EOF'
[Unit]
Description=XrayR Service
After=network.target nss-lookup.target
Wants=network.target

[Service]
User=root
Group=root
Type=simple
LimitAS=infinity
LimitRSS=infinity
LimitCORE=infinity
LimitNOFILE=1048576
LimitNPROC=1048576
WorkingDirectory=/usr/local/XrayR/
ExecStart=/usr/local/XrayR/XrayR -config /etc/XrayR/config.yml
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF
}

backup_sysctl_conf() {
    local backup
    if [[ ! -f "$SYSCTL_CONF" ]]; then
        touch "$SYSCTL_CONF"
    fi
    backup="${SYSCTL_CONF}.bak.XrayR.$(date +%Y%m%d%H%M%S)"
    cp -a "$SYSCTL_CONF" "$backup"
    log_info "已备份 ${SYSCTL_CONF} 到 ${backup}"
}

detect_congestion_control() {
    local current available
    current="$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || true)"
    available="$(cat /proc/sys/net/ipv4/tcp_available_congestion_control 2>/dev/null || true)"

    if [[ "$current" == "bbrplus" ]]; then
        echo "bbrplus"
        return 0
    fi
    if echo " $available " | grep -q " bbr "; then
        echo "bbr"
        return 0
    fi
    echo ""
}

clean_sysctl_duplicates() {
    local tmp
    tmp="$(mktemp)"
    awk '
        BEGIN { skip = 0 }
        /^# XrayR network optimization begin$/ { skip = 1; next }
        /^# XrayR network optimization end$/ { skip = 0; next }
        skip == 1 { next }
        {
            line = $0
            sub(/^[ \t]*/, "", line)
            if (line ~ /^(net\.core\.default_qdisc|net\.ipv4\.tcp_congestion_control|net\.ipv4\.tcp_fastopen|net\.ipv4\.tcp_tw_reuse|net\.ipv4\.ip_local_port_range|net\.core\.somaxconn|net\.ipv4\.tcp_max_syn_backlog|net\.core\.netdev_max_backlog)[ \t]*=/) {
                next
            }
            print
        }
    ' "$SYSCTL_CONF" > "$tmp"
    cat "$tmp" > "$SYSCTL_CONF"
    rm -f "$tmp"
}

append_sysctl_optimization() {
    local cc="$1"
    {
        echo ""
        echo "# XrayR network optimization begin"
        echo "net.core.default_qdisc=fq"
        if [[ -n "$cc" ]]; then
            echo "net.ipv4.tcp_congestion_control=${cc}"
        fi
        echo "net.ipv4.tcp_fastopen=3"
        echo "net.ipv4.tcp_tw_reuse=1"
        echo "net.ipv4.ip_local_port_range=1024 65535"
        echo "net.core.somaxconn=65535"
        echo "net.ipv4.tcp_max_syn_backlog=65535"
        echo "net.core.netdev_max_backlog=250000"
        echo "# XrayR network optimization end"
    } >> "$SYSCTL_CONF"
}

apply_sysctl_optimization() {
    local line key value
    while IFS= read -r line; do
        [[ -z "$line" || "$line" == \#* || "$line" != *=* ]] && continue
        key="${line%%=*}"
        value="${line#*=}"
        sysctl -w "${key}=${value}" >/dev/null 2>&1 || log_warn "无法应用 ${key}=${value}，已跳过。"
    done < <(sed -n '/^# XrayR network optimization begin$/,/^# XrayR network optimization end$/p' "$SYSCTL_CONF")
}

apply_systemd_optimization() {
    if [[ ! -x "$INSTALL_DIR/XrayR" ]]; then
        log_warn "未检测到 ${INSTALL_DIR}/XrayR，跳过 systemd service limits 写入。"
        return 0
    fi
    write_service
    if command -v systemctl >/dev/null 2>&1; then
        systemctl daemon-reload || log_warn "systemctl daemon-reload 失败，请手动检查 systemd 状态。"
    fi
    log_info "已写入 systemd 优化：LimitNOFILE=1048576，LimitNPROC=1048576，Restart=on-failure，RestartSec=5s。"
}

show_network_optimization_status() {
    local cc qdisc fastopen tw_reuse port_range somaxconn syn_backlog netdev_backlog available
    cc="$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo unknown)"
    qdisc="$(sysctl -n net.core.default_qdisc 2>/dev/null || echo unknown)"
    fastopen="$(sysctl -n net.ipv4.tcp_fastopen 2>/dev/null || echo unknown)"
    tw_reuse="$(sysctl -n net.ipv4.tcp_tw_reuse 2>/dev/null || echo unknown)"
    port_range="$(sysctl -n net.ipv4.ip_local_port_range 2>/dev/null || echo unknown)"
    somaxconn="$(sysctl -n net.core.somaxconn 2>/dev/null || echo unknown)"
    syn_backlog="$(sysctl -n net.ipv4.tcp_max_syn_backlog 2>/dev/null || echo unknown)"
    netdev_backlog="$(sysctl -n net.core.netdev_max_backlog 2>/dev/null || echo unknown)"
    available="$(cat /proc/sys/net/ipv4/tcp_available_congestion_control 2>/dev/null || echo unknown)"

    echo ""
    log_info "当前网络优化状态："
    echo "  tcp_available_congestion_control: ${available}"
    echo "  net.ipv4.tcp_congestion_control: ${cc}"
    echo "  net.core.default_qdisc: ${qdisc}"
    echo "  net.ipv4.tcp_fastopen: ${fastopen}"
    echo "  net.ipv4.tcp_tw_reuse: ${tw_reuse}"
    echo "  net.ipv4.ip_local_port_range: ${port_range}"
    echo "  net.core.somaxconn: ${somaxconn}"
    echo "  net.ipv4.tcp_max_syn_backlog: ${syn_backlog}"
    echo "  net.core.netdev_max_backlog: ${netdev_backlog}"
}

optimize_network() {
    local cc
    log_info "开始应用安全网络优化：原生 BBR/fq、高并发队列、systemd limits。"
    backup_sysctl_conf
    clean_sysctl_duplicates
    cc="$(detect_congestion_control)"
    if [[ -z "$cc" ]]; then
        log_warn "当前内核未检测到 bbr，跳过 tcp_congestion_control 设置；不会安装 BBRPlus 或更换内核。"
    elif [[ "$cc" == "bbrplus" ]]; then
        log_warn "检测到当前已使用 bbrplus，将保留现有拥塞控制；安装脚本不会默认安装或更换 BBRPlus 内核。"
    else
        log_info "检测到内核支持 bbr，将启用系统原生 BBR。"
    fi
    append_sysctl_optimization "$cc"
    apply_sysctl_optimization
    apply_systemd_optimization
    show_network_optimization_status
}

enable_bbrplus() {
    log_warn "BBRPlus 是高级手动选项，可能更换内核、需要重启服务器，并导致线上节点断开。"
    log_warn "默认安装不会启用 BBRPlus；如果你只是要安全优化，请运行 install/update/optimize。"
    if [[ ! -t 0 ]]; then
        log_error "非交互环境禁止自动启用 BBRPlus。请在 SSH 终端中手动运行：$0 --enable-bbrplus"
        exit 1
    fi
    read -r -p "确认继续执行第三方 BBRPlus/内核脚本？输入 yes 继续: " answer
    if [[ "$answer" != "yes" ]]; then
        log_warn "已取消 BBRPlus 操作。"
        exit 0
    fi
    bash <(curl -L -s https://raw.githubusercontent.com/chiakge/Linux-NetSpeed/master/tcp.sh)
}

install_manager() {
    local script_url="https://raw.githubusercontent.com/${OWNER}/${SCRIPT_REPO}/master/XrayR.sh"
    if curl -fLs --connect-timeout 15 --retry 3 --retry-delay 2 -o "$MANAGER_BIN" "$script_url"; then
        chmod +x "$MANAGER_BIN"
        ln -sf "$MANAGER_BIN" "$MANAGER_BIN_LOWER"
    else
        log_warn "管理脚本下载失败，跳过 /usr/bin/XrayR 安装。"
    fi
}

copy_config_files() {
    mkdir -p "$CONFIG_DIR"
    if [[ -f "$INSTALL_DIR/geoip.dat" ]]; then
        cp -f "$INSTALL_DIR/geoip.dat" "$CONFIG_DIR/geoip.dat"
    fi
    if [[ -f "$INSTALL_DIR/geosite.dat" ]]; then
        cp -f "$INSTALL_DIR/geosite.dat" "$CONFIG_DIR/geosite.dat"
    fi

    for file in config.yml dns.json route.json custom_outbound.json custom_inbound.json rulelist; do
        if [[ ! -f "$CONFIG_DIR/$file" && -f "$INSTALL_DIR/$file" ]]; then
            cp "$INSTALL_DIR/$file" "$CONFIG_DIR/$file"
        fi
    done
    if [[ ! -f "$CONFIG_DIR/config.yml" && -f "$INSTALL_DIR/config.example.yml" ]]; then
        cp "$INSTALL_DIR/config.example.yml" "$CONFIG_DIR/config.yml"
    fi
}

verify_installed_version() {
    local version_text
    if [[ ! -x "$INSTALL_DIR/XrayR" ]]; then
        log_error "安装失败：$INSTALL_DIR/XrayR 不存在或不可执行。"
        exit 1
    fi
    version_text="$("$INSTALL_DIR/XrayR" -version 2>&1 | head -n1)"
    echo "$version_text"
    if [[ "$version_text" != *"XrayR 0.9.4"* ]]; then
        log_error "版本验证失败：期望输出包含 XrayR 0.9.4。"
        exit 1
    fi
}

verify_path_layout() {
    if [[ ! -x "$INSTALL_DIR/XrayR" ]]; then
        log_error "安装失败：$INSTALL_DIR/XrayR 不存在或不可执行。"
        exit 1
    fi
    if [[ ! -x "$MANAGER_BIN" ]]; then
        log_error "安装失败：$MANAGER_BIN 管理菜单脚本不存在或不可执行。"
        exit 1
    fi
    if [[ ! -L "$MANAGER_BIN_LOWER" || "$(readlink "$MANAGER_BIN_LOWER")" != "$MANAGER_BIN" ]]; then
        log_error "安装失败：$MANAGER_BIN_LOWER 未正确指向 $MANAGER_BIN。"
        exit 1
    fi
}

show_xrayr_runtime_status() {
    local version_text active_state enabled_state

    echo ""
    log_info "XrayR 安装状态："
    if [[ -x "$INSTALL_DIR/XrayR" ]]; then
        version_text="$("$INSTALL_DIR/XrayR" -version 2>&1 | head -n1)"
        echo "  XrayR 版本: ${version_text}"
    else
        echo "  XrayR 版本: 未安装"
    fi

    if command -v systemctl >/dev/null 2>&1 && [[ -f "$SERVICE_FILE" ]]; then
        active_state="$(systemctl is-active XrayR 2>/dev/null || true)"
        enabled_state="$(systemctl is-enabled XrayR 2>/dev/null || true)"
        echo "  XrayR 状态: ${active_state:-unknown}"
        echo "  开机自启: ${enabled_state:-unknown}"
    else
        echo "  XrayR 状态: 未检测到 systemd 服务"
    fi
}

show_manager_menu() {
    if [[ -t 0 ]]; then
        "$MANAGER_BIN"
    else
        log_info "安装完成，请执行 XrayR 打开管理菜单。"
    fi
}

install_xrayr() {
    local version archive archive_sha256 tmp_dir url
    version="$(normalize_version "${1:-$DEFAULT_VERSION}")"
    if [[ "$version" != "$DEFAULT_VERSION" ]]; then
        log_error "当前安装脚本只支持 ${DEFAULT_VERSION}。"
        log_error "如需其他版本，请先在 dockerps13/starbridge-xrayr 发布对应 release 和 sha256。"
        exit 1
    fi
    archive="$(detect_arch)"
    archive_sha256="$(sha256_for_asset "$archive")"
    url="https://github.com/${OWNER}/${REPO}/releases/download/${version}/${archive}"
    tmp_dir="$(mktemp -d)"

    log_info "开始安装 XrayR ${version}"
    echo "匹配安装包：${archive}"
    echo "构建提交：${DEFAULT_COMMIT}"
    echo "下载地址：${url}"

    install_base
    download_file "$url" "$tmp_dir/$archive"
    verify_file_sha256 "$tmp_dir/$archive" "$archive_sha256"

    if command -v systemctl >/dev/null 2>&1; then
        systemctl stop XrayR >/dev/null 2>&1 || true
    fi

    rm -rf "$INSTALL_DIR"
    mkdir -p "$INSTALL_DIR"
    unzip -q "$tmp_dir/$archive" -d "$INSTALL_DIR"
    rm -rf "$tmp_dir"
    chmod +x "$INSTALL_DIR/XrayR"

    copy_config_files
    write_service
    install_manager
    optimize_network

    if command -v systemctl >/dev/null 2>&1; then
        systemctl daemon-reload
        systemctl enable XrayR >/dev/null 2>&1 || true
        if [[ -f "$CONFIG_DIR/config.yml" ]]; then
            systemctl restart XrayR >/dev/null 2>&1 || true
        fi
    fi

    log_info "XrayR ${version} 安装完成。"
    verify_path_layout
    verify_installed_version
    show_xrayr_runtime_status
    show_manager_menu
}

uninstall_xrayr() {
    need_root
    if command -v systemctl >/dev/null 2>&1; then
        systemctl stop XrayR >/dev/null 2>&1 || true
        systemctl disable XrayR >/dev/null 2>&1 || true
    fi
    rm -f "$SERVICE_FILE"
    if command -v systemctl >/dev/null 2>&1; then
        systemctl daemon-reload || true
        systemctl reset-failed >/dev/null 2>&1 || true
    fi
    rm -rf "$INSTALL_DIR" "$CONFIG_DIR"
    rm -f "$MANAGER_BIN" "$MANAGER_BIN_LOWER"
    log_info "XrayR 已卸载。"
}

show_version() {
    if [[ -x "$INSTALL_DIR/XrayR" ]]; then
        "$INSTALL_DIR/XrayR" -version
    else
        echo "XrayR 未安装，默认安装版本为 ${DEFAULT_VERSION}。"
    fi
}

usage() {
    cat <<EOF
Usage: $0 [install|update|uninstall|version] [version]

Commands:
  install [version]   安装 XrayR，默认安装 ${DEFAULT_VERSION}
  update [version]    更新 XrayR，默认更新到 ${DEFAULT_VERSION}
  optimize            仅应用安全网络优化，不安装/更新 XrayR
  --enable-bbrplus    高级手动选项：确认后执行 BBRPlus/内核脚本
  uninstall           卸载 XrayR
  version             查看已安装 XrayR 版本

Default:
  未传命令时等同于 install ${DEFAULT_VERSION}
EOF
}

main() {
    local command="${1:-install}"
    case "$command" in
        install)
            need_root
            install_xrayr "${2:-$DEFAULT_VERSION}"
            ;;
        update)
            need_root
            install_xrayr "${2:-$DEFAULT_VERSION}"
            ;;
        optimize)
            need_root
            optimize_network
            ;;
        --enable-bbrplus)
            need_root
            enable_bbrplus
            ;;
        uninstall)
            uninstall_xrayr
            ;;
        version)
            show_version
            ;;
        -h|--help|help)
            usage
            ;;
        v*|[0-9]*)
            need_root
            install_xrayr "$command"
            ;;
        *)
            log_error "未知命令：${command}"
            usage
            exit 1
            ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
