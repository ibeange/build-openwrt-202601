#!/bin/bash

# 打包toolchain目录
if [[ "$REBUILD_TOOLCHAIN" = 'true' ]]; then
    cd $OPENWRT_PATH
    sed -i 's/ $(tool.*\/stamp-compile)//' Makefile
    if [[ -d ".ccache" && $(du -s .ccache | cut -f1) -gt 0 ]]; then
        echo "🔍 缓存目录大小:"
        du -h --max-depth=1 .ccache
        ccache_dir=".ccache"
    fi
    echo "📦 工具链目录大小:"
    du -h --max-depth=1 staging_dir
    tar -I zstdmt -cf "$GITHUB_WORKSPACE/output/$CACHE_NAME.tzst" staging_dir/host* staging_dir/tool* $ccache_dir
    echo "📁 输出目录内容:"
    ls -lh "$GITHUB_WORKSPACE/output"
    if [[ ! -e "$GITHUB_WORKSPACE/output/$CACHE_NAME.tzst" ]]; then
        echo "❌ 工具链打包失败!"
        exit 1
    fi
    echo "✅ 工具链打包完成"
    exit 0
fi

# 创建toolchain缓存保存目录
[ -d "$GITHUB_WORKSPACE/output" ] || mkdir "$GITHUB_WORKSPACE/output"

# 颜色输出
color() {
    case "$1" in
        cr) echo -e "\e[1;31m${2}\e[0m" ;;  # 红色
        cg) echo -e "\e[1;32m${2}\e[0m" ;;  # 绿色
        cy) echo -e "\e[1;33m${2}\e[0m" ;;  # 黄色
        cb) echo -e "\e[1;34m${2}\e[0m" ;;  # 蓝色
        cp) echo -e "\e[1;35m${2}\e[0m" ;;  # 紫色
        cc) echo -e "\e[1;36m${2}\e[0m" ;;  # 青色
        cw) echo -e "\e[1;37m${2}\e[0m" ;;  # 白色
    esac
}

# 状态显示和时间统计
status_info() {
    local task_name="$1" begin_time=$(date +%s) exit_code time_info
    shift
    "$@"
    exit_code=$?
    [[ "$exit_code" -eq 99 ]] && return 0
    if [[ -n "$begin_time" ]]; then
        time_info="==> 用时 $(($(date +%s) - begin_time)) 秒"
    else
        time_info=""
    fi
    if [[ "$exit_code" -eq 0 ]]; then
        printf "%s %-52s %s %s %s %s %s %s %s\n" \
        $(color cy "⏳ $task_name") [ $(color cg ✔) ] $(color cw "$time_info")
    else
        printf "%s %-52s %s %s %s %s %s %s %s\n" \
        $(color cy "⏳ $task_name") [ $(color cr ✖) ] $(color cw "$time_info")
    fi
}

# 查找目录
find_dir() {
    find $1 -maxdepth 3 -type d -name "$2" -print -quit 2>/dev/null
}

# 打印信息
print_info() {
    printf "%s %-40s %s %s %s\n" "$1" "$2" "$3" "$4" "$5"
}

# 添加整个源仓库(git clone)
git_clone() {
    local repo_url branch target_dir current_dir
    if [[ "$1" == */* ]]; then
        repo_url="$1"
        shift
    else
        branch="-b $1 --single-branch"
        repo_url="$2"
        shift 2
    fi
    target_dir="${1:-${repo_url##*/}}"
    git clone -q $branch --depth=1 "$repo_url" "$target_dir" 2>/dev/null || {
        print_info $(color cr 拉取) "$repo_url" [ $(color cr ✖) ]
        return 1
    }
    rm -rf $target_dir/{.git*,README*.md,LICENSE}
    current_dir=$(find_dir "package/ feeds/ target/" "$target_dir")
    if [[ -d "$current_dir" ]]; then
        rm -rf "$current_dir"
        mv -f "$target_dir" "${current_dir%/*}"
        print_info $(color cg 替换) "$target_dir" [ $(color cg ✔) ]
    else
        mv -f "$target_dir" "$destination_dir"
        print_info $(color cb 添加) "$target_dir" [ $(color cb ✔) ]
    fi
}

# 添加源仓库内的指定目录
clone_dir() {
    local repo_url branch temp_dir=$(mktemp -d)
    if [[ "$1" == */* ]]; then
        repo_url="$1"
        shift
    else
        branch="-b $1 --single-branch"
        repo_url="$2"
        shift 2
    fi
    git clone -q $branch --depth=1 "$repo_url" "$temp_dir" 2>/dev/null || {
        print_info $(color cr 拉取) "$repo_url" [ $(color cr ✖) ]
        rm -rf "$temp_dir"
        return 1
    }
    local target_dir source_dir current_dir
    for target_dir in "$@"; do
        source_dir=$(find_dir "$temp_dir" "$target_dir")
        [[ -d "$source_dir" ]] || \
        source_dir=$(find "$temp_dir" -maxdepth 4 -type d -name "$target_dir" -print -quit) && \
        [[ -d "$source_dir" ]] || {
            print_info $(color cr 查找) "$target_dir" [ $(color cr ✖) ]
            continue
        }
        current_dir=$(find_dir "package/ feeds/ target/" "$target_dir")
        if [[ -d "$current_dir" ]]; then
            rm -rf "$current_dir"
            mv -f "$source_dir" "${current_dir%/*}"
            print_info $(color cg 替换) "$target_dir" [ $(color cg ✔) ]
        else
            mv -f "$source_dir" "$destination_dir"
            print_info $(color cb 添加) "$target_dir" [ $(color cb ✔) ]
        fi
    done
    rm -rf "$temp_dir"
}

# 添加源仓库内的所有子目录
clone_all() {
    local repo_url branch temp_dir=$(mktemp -d)
    if [[ "$1" == */* ]]; then
        repo_url="$1"
        shift
    else
        branch="-b $1 --single-branch"
        repo_url="$2"
        shift 2
    fi
    git clone -q $branch --depth=1 "$repo_url" "$temp_dir" 2>/dev/null || {
        print_info $(color cr 拉取) "$repo_url" [ $(color cr ✖) ]
        rm -rf "$temp_dir"
        return 1
    }
    process_dir() {
        while IFS= read -r source_dir; do
            local target_dir=$(basename "$source_dir")
            local current_dir=$(find_dir "package/ feeds/ target/" "$target_dir")
            if [[ -d "$current_dir" ]]; then
                rm -rf "$current_dir"
                mv -f "$source_dir" "${current_dir%/*}"
                print_info $(color cg 替换) "$target_dir" [ $(color cg ✔) ]
            else
                mv -f "$source_dir" "$destination_dir"
                print_info $(color cb 添加) "$target_dir" [ $(color cb ✔) ]
            fi
        done < <(find "$1" -maxdepth 1 -mindepth 1 -type d ! -name '.*')
    }
    if [[ $# -eq 0 ]]; then
        process_dir "$temp_dir"
    else
        for dir_name in "$@"; do
            [[ -d "$temp_dir/$dir_name" ]] && process_dir "$temp_dir/$dir_name" || \
            print_info $(color cr 目录) "$dir_name" [ $(color cr ✖) ]
        done
    fi
    rm -rf "$temp_dir"
}

# 主流程
main() {
    echo "$(color cp "🚀 开始运行自定义脚本")"
    echo "========================================"

    # 拉取编译源码
    status_info "拉取编译源码" clone_source_code

    # 设置环境变量
    status_info "设置环境变量" set_variable_values

    # 下载部署toolchain缓存
    status_info "下载部署toolchain缓存" download_toolchain

    # 更新&安装插件
    status_info "更新&安装插件" update_install_feeds

    # 添加额外插件
    status_info "添加额外插件" add_custom_packages

    # 加载个人设置
    status_info "加载个人设置" apply_custom_settings

    # 更新配置文件
    status_info "更新配置文件" update_config_file

    # 下载openclash运行内核
    status_info "下载openclash运行内核" preset_openclash_core

    # 下载zsh终端工具
    status_info "下载zsh终端工具" preset_shell_tools

    # 显示编译信息
    show_build_info

    echo "$(color cp "✅ 自定义脚本运行完成")"
    echo "========================================"
}

# 拉取编译源码
clone_source_code() {
    # 设置编译源码与分支
    REPO_URL="https://github.com/coolsnowwolf/lede"
    echo "REPO_URL=$REPO_URL" >>$GITHUB_ENV
    REPO_BRANCH="master"
    echo "REPO_BRANCH=$REPO_BRANCH" >>$GITHUB_ENV

    # 拉取编译源码
    # cd /workdir
    git clone -q -b "$REPO_BRANCH" --single-branch "$REPO_URL" openwrt
    # ln -sf /workdir/openwrt $GITHUB_WORKSPACE/openwrt
    [ -d openwrt ] && cd openwrt || exit
    echo "OPENWRT_PATH=$PWD" >>$GITHUB_ENV

    # 设置luci版本为18.06
    sed -i '/luci/s/^#//; /luci.git;openwrt/s/^/#/' feeds.conf.default
}

# 设置环境变量
set_variable_values() {
    local TARGET_NAME SUBTARGET_NAME KERNEL TOOLS_HASH

    # 源仓库与分支
    SOURCE_REPO=$(basename "$REPO_URL")
    echo "SOURCE_REPO=$SOURCE_REPO" >>$GITHUB_ENV
    echo "LITE_BRANCH=${REPO_BRANCH#*-}" >>$GITHUB_ENV

    # 平台架构
    TARGET_NAME=$(grep -oP "^CONFIG_TARGET_\K[a-z0-9]+(?==y)" "$GITHUB_WORKSPACE/$CONFIG_FILE")
    SUBTARGET_NAME=$(grep -oP "^CONFIG_TARGET_${TARGET_NAME}_\K[a-z0-9]+(?==y)" "$GITHUB_WORKSPACE/$CONFIG_FILE")
    DEVICE_TARGET="$TARGET_NAME-$SUBTARGET_NAME"
    echo "DEVICE_TARGET=$DEVICE_TARGET" >>$GITHUB_ENV

    # 内核版本
    KERNEL=$(grep -oP 'KERNEL_PATCHVER:=\K[\d\.]+' "target/linux/$TARGET_NAME/Makefile")
    KERNEL_VERSION=$(grep -oP 'LINUX_KERNEL_HASH-\K[\d\.]+' "include/kernel-$KERNEL")
    echo "KERNEL_VERSION=$KERNEL_VERSION" >>$GITHUB_ENV

    # toolchain缓存文件名
    TOOLS_HASH=$(git log -1 --pretty=format:"%h" tools toolchain)
    CACHE_NAME="$SOURCE_REPO-${REPO_BRANCH#*-}-$DEVICE_TARGET-cache-$TOOLS_HASH"
    echo "CACHE_NAME=$CACHE_NAME" >>$GITHUB_ENV

    # 源码更新信息
    echo "COMMIT_AUTHOR=$(git show -s --date=short --format="作者: %an")" >>$GITHUB_ENV
    echo "COMMIT_DATE=$(git show -s --date=short --format="时间: %ci")" >>$GITHUB_ENV
    echo "COMMIT_MESSAGE=$(git show -s --date=short --format="内容: %s")" >>$GITHUB_ENV
    echo "COMMIT_HASH=$(git show -s --date=short --format="hash: %H")" >>$GITHUB_ENV
}

# 下载部署toolchain缓存
download_toolchain() {
    local cache_xa cache_xc
    if [[ "$TOOLCHAIN" = 'true' ]]; then
        cache_xa=$(curl -sL "https://api.github.com/repos/$GITHUB_REPOSITORY/releases" | awk -F '"' '/download_url/{print $4}' | grep "$CACHE_NAME")
        cache_xc=$(curl -sL "https://api.github.com/repos/haiibo/toolchain-cache/releases" | awk -F '"' '/download_url/{print $4}' | grep "$CACHE_NAME")
        if [[ "$cache_xa" || "$cache_xc" ]]; then
            wget -qc -t=3 "${cache_xa:-$cache_xc}"
            if [ -e *.tzst ]; then
                tar -I unzstd -xf *.tzst || tar -xf *.tzst
                [ "$cache_xa" ] || (cp *.tzst $GITHUB_WORKSPACE/output && echo "OUTPUT_RELEASE=true" >>$GITHUB_ENV)
                [ -d staging_dir ] && sed -i 's/ $(tool.*\/stamp-compile)//' Makefile
            fi
        else
            echo "REBUILD_TOOLCHAIN=true" >>$GITHUB_ENV
            echo "⚠️ 未找到最新工具链"
            return 99
        fi
    else
        echo "REBUILD_TOOLCHAIN=true" >>$GITHUB_ENV
        return 99
    fi
}

# 更新&安装插件
update_install_feeds() {
    ./scripts/feeds update -a 1>/dev/null 2>&1
    ./scripts/feeds install -a 1>/dev/null 2>&1
}

# 添加额外插件
add_custom_packages() {
    echo "📦 添加额外插件..."

    # 创建插件保存目录
    destination_dir="package/A"
    [ -d "$destination_dir" ] || mkdir -p "$destination_dir"

    # 基础插件
    # git_clone https://github.com/kongfl888/luci-app-adguardhome
    # clone_dir lua https://github.com/sbwml/luci-app-alist luci-app-alist
    # clone_all https://github.com/linkease/istore-ui
    # clone_all https://github.com/linkease/istore luci

    clone_all https://github.com/sirpdboy/luci-app-ddns-go

    clone_all v5 https://github.com/sbwml/luci-app-mosdns

    git_clone https://github.com/sbwml/packages_lang_golang golang

    git_clone https://github.com/pymumu/luci-app-smartdns
    git_clone https://github.com/pymumu/openwrt-smartdns smartdns

    git_clone https://github.com/ximiTech/luci-app-msd_lite
    git_clone https://github.com/ximiTech/msd_lite

    # openclash
    rm -rf feeds/luci/applications/luci-app-openclash
    clone_dir https://github.com/vernesong/OpenClash luci-app-openclash
    sed -i 's|("OpenClash"), 50)|("OpenClash"), 3)|g' package/luci-app-openclash/luci-app-nikki/luasrc/controller/*.lua

    # v2ray-server
    rm -rf feeds/luci/applications/luci-app-v2ray-server
    clone_dir https://github.com/kiddin9/kwrt-packages luci-app-v2ray-server
    clone_dir https://github.com/sbwml/openwrt_helloworld xray-core
    # 调整 V2ray服务器 到 VPN 菜单 (修正路径)
    if [ -d "package/luci-app-v2ray-server" ]; then
        sed -i 's/services/vpn/g' package/luci-app-v2ray-server/luasrc/controller/*.lua
        sed -i 's/services/vpn/g' package/luci-app-v2ray-server/luasrc/model/cbi/v2ray_server/*.lua
        sed -i 's/services/vpn/g' package/luci-app-v2ray-server/luasrc/view/v2ray_server/*.htm
    fi

    # nikki最新版本
    rm -rf feeds/luci/applications/luci-app-nikki
    clone_all https://github.com/nikkinikki-org/OpenWrt-nikki
    sed -i 's/"title": "Nikki",/&\n        "order": 1,/g' package/luci-app-nikki/luci-app-nikki/root/usr/share/luci/menu.d/luci-app-nikki.json

    # UU游戏加速器
    rm -rf feeds/luci/applications/luci-app-uugamebooster
    clone_dir https://github.com/kiddin9/kwrt-packages luci-app-uugamebooster
    clone_dir https://github.com/kiddin9/kwrt-packages uugamebooster

    # 关机
    clone_all https://github.com/sirpdboy/luci-app-poweroffdevice

    # Lucky
    clone_all https://github.com/sirpdboy/luci-app-lucky
    
    # luci-app-filemanager
    git_clone https://github.com/sbwml/luci-app-filemanager luci-app-filemanager
    
    # 添加 Turbo ACC 网络加速
    git_clone https://github.com/kiddin9/kwrt-packages luci-app-turboacc

    # Themes
    git_clone https://github.com/jerrykuku/luci-theme-argon
    git_clone https://github.com/jerrykuku/luci-app-argon-config

    # clone_dir https://github.com/xiaoqingfengATGH/luci-theme-infinityfreedom luci-theme-infinityfreedom-ng
    # clone_dir https://github.com/haiibo/packages luci-theme-opentomcat

    # 晶晨宝盒
    # clone_all https://github.com/ophub/luci-app-amlogic
    # sed -i "s|firmware_repo.*|firmware_repo 'https://github.com/$GITHUB_REPOSITORY'|g" $destination_dir/luci-app-amlogic/root/etc/config/amlogic
    # sed -i "s|kernel_path.*|kernel_path 'https://github.com/ophub/kernel'|g" $destination_dir/luci-app-amlogic/root/etc/config/amlogic
    # sed -i "s|ARMv8|$RELEASE_TAG|g" $destination_dir/luci-app-amlogic/root/etc/config/amlogic

    # 修复Makefile路径
    find "$destination_dir" -type f -name "Makefile" | xargs sed -i \
        -e 's?\.\./\.\./\(lang\|devel\)?$(TOPDIR)/feeds/packages/\1?' \
        -e 's?\.\./\.\./luci.mk?$(TOPDIR)/feeds/luci/luci.mk?'

    # 转换插件语言翻译
    for e in $(ls -d $destination_dir/luci-*/po feeds/luci/applications/luci-*/po); do
        if [[ -d $e/zh-cn && ! -d $e/zh_Hans ]]; then
            ln -s zh-cn $e/zh_Hans 2>/dev/null
        elif [[ -d $e/zh_Hans && ! -d $e/zh-cn ]]; then
            ln -s zh_Hans $e/zh-cn 2>/dev/null
        fi
    done
}

# 加载个人设置
apply_custom_settings() {
    local orig_version

    [ -e "$GITHUB_WORKSPACE/files" ] && mv "$GITHUB_WORKSPACE/files" files

    # 设置固件rootfs大小
    if [ "$PART_SIZE" ]; then
        sed -i '/ROOTFS_PARTSIZE/d' "$GITHUB_WORKSPACE/$CONFIG_FILE"
        echo "CONFIG_TARGET_ROOTFS_PARTSIZE=$PART_SIZE" >>"$GITHUB_WORKSPACE/$CONFIG_FILE"
    fi

    # 修改默认ip地址
    [ "$IP_ADDRESS" ] && sed -i '/lan) ipad/s/".*"/"'"$IP_ADDRESS"'"/' package/base-files/*/bin/config_generate

    # 更改默认shell为zsh
    # sed -i 's/\/bin\/ash/\/usr\/bin\/zsh/g' package/base-files/files/etc/passwd

    # ttyd免登录
    sed -i 's|/bin/login|/bin/login -f root|g' feeds/packages/utils/ttyd/files/ttyd.config

    # 设置 root 用户密码为 password
    sed -i 's/root:::0:99999:7:::/root:$1$V4UetPzk$CYXluq4wUazHjmCDBCqXF.::0:99999:7:::/g' package/base-files/files/etc/shadow
    
    # 更改argon主题背景
    cp -f $GITHUB_WORKSPACE/images/bg1.jpg feeds/luci/themes/luci-theme-argon/htdocs/luci-static/argon/img/bg1.jpg
    ARGON_CONFIG_FILE="feeds/luci/applications/luci-app-argon-config/root/etc/config/argon"
    if [ -f "$ARGON_CONFIG_FILE" ]; then
        # 设置Argon主题的登录页面壁纸为内建
        sed -i "s/option online_wallpaper 'bing'/option online_wallpaper 'none'/" $ARGON_CONFIG_FILE
        # 设置Argon主题的登录表单模糊度
        sed -i "s/option blur '[0-9]*'/option blur '0'/" $ARGON_CONFIG_FILE
        sed -i "s/option blur_dark '[0-9]*'/option blur_dark '0'/" $ARGON_CONFIG_FILE
        # 设置Argon主题颜色
        PRIMARY_COLORS=("#FF8C00" "#1E90FF" "#FF69B4" "#FF1493" "#e2c312" "#00CED1" "#DC143C")
        DARK_PRIMARY_COLORS=("#9370DB" "#8A2BE2" "#D87093" "#C71585" "#B8860B" "#4682B4" "#8B0000")
        WEEKDAY=$(date +%w)
        sed -i "s/option primary '#[0-9a-fA-F]\{6\}'/option primary '${PRIMARY_COLORS[$WEEKDAY]}'/" $ARGON_CONFIG_FILE
        sed -i "s/option dark_primary '#[0-9a-fA-F]\{6\}'/option dark_primary '${DARK_PRIMARY_COLORS[$WEEKDAY]}'/" $ARGON_CONFIG_FILE

        echo "argon theme has been customized!"
    fi

    echo "菜单 调整..."
    # sed -i 's|/services/|/control/|' feeds/luci/applications/luci-app-wol/root/usr/share/luci/menu.d/luci-app-wol.json
    #sed -i 's|/services/|/network/|' feeds/luci/applications/luci-app-nlbwmon/root/usr/share/luci/menu.d/luci-app-nlbwmon.json
    #sed -i 's|/services/|/nas/|' feeds/luci/applications/luci-app-alist/root/usr/share/luci/menu.d/luci-app-openlist2.json
    sed -i 's/"网络存储"/"存储"/g' `grep "网络存储" -rl ./`
    sed -i 's/"软件包"/"软件管理"/g' `grep "软件包" -rl ./`

    # 精简 UPnP 菜单名称
    sed -i 's,UPnP IGD 和 PCP,UPnP,g' feeds/luci/applications/luci-app-upnp/po/zh-cn/upnp.po
        
    echo "重命名系统菜单"
    #status menu
    sed -i 's/"概览"/"系统概览"/g' feeds/luci/modules/luci-base/po/zh-cn/base.po
    sed -i 's/"路由"/"路由映射"/g' feeds/luci/modules/luci-base/po/zh-cn/base.po
    #system menu
    sed -i 's/"系统"/"系统设置"/g' feeds/luci/modules/luci-base/po/zh-cn/base.po
    sed -i 's/"管理权"/"权限管理"/g' feeds/luci/modules/luci-base/po/zh-cn/base.po
    sed -i 's/"重启"/"立即重启"/g' feeds/luci/modules/luci-base/po/zh-cn/base.po
    sed -i 's/"备份与升级"/"备份升级"/g' feeds/luci/modules/luci-base/po/zh-cn/base.po
    sed -i 's/"挂载点"/"挂载路径"/g' feeds/luci/modules/luci-base/po/zh-cn/base.po
    sed -i 's/"启动项"/"启动管理"/g' feeds/luci/modules/luci-base/po/zh-cn/base.po
    sed -i 's/"软件包"/"软件管理"/g' feeds/luci/modules/luci-base/po/zh-cn/base.po
    
    # 更改 ttyd 顺序和名称
    #sed -i '3a \		"order": 10,' feeds/luci/applications/luci-app-ttyd/root/usr/share/luci/menu.d/luci-app-ttyd.json
    sed -i 's/"终端"/"命令终端"/g' feeds/luci/applications/luci-app-ttyd/po/zh-cn/terminal.po
    
    # 设置 nlbwmon 独立菜单
    #sed -i 's/524288/16777216/g' feeds/packages/net/nlbwmon/files/nlbwmon.config
    #sed -i 's/option commit_interval.*/option commit_interval 24h/g' feeds/packages/net/nlbwmon/files/nlbwmon.config
    #sed -i 's/services\/nlbw/nlbw/g; /path/s/admin\///g' feeds/luci/applications/luci-app-nlbwmon/root/usr/share/luci/menu.d/luci-app-nlbwmon.json
    #sed -i 's/services\///g' feeds/luci/applications/luci-app-nlbwmon/htdocs/luci-static/resources/view/nlbw/config.js
    
    echo "重命名网络菜单"
    #network
    sed -i 's/"接口"/"网络接口"/g' `grep "接口" -rl ./`
    sed -i 's/DHCP\/DNS/DHCP设定/g' feeds/luci/modules/luci-base/po/zh-cn/base.po

    # x86型号只显示cpu型号
    sed -i 's/${g}.*/${a}${b}${c}${d}${e}${f}${hydrid}/g' package/lean/autocore/files/x86/autocore
    sed -i "s/'C'/'Core '/g; s/'T '/'Thread '/g" package/lean/autocore/files/x86/autocore

    # 最大连接数修改为65535
    sed -i '$a net.netfilter.nf_conntrack_max=65535' package/base-files/files/etc/sysctl.conf
    
    # 修改本地时间格式
    sed -i 's/os.date()/os.date("%a %Y-%m-%d %H:%M:%S")/g' package/lean/autocore/files/*/index.htm
    
    #nlbwmon 修复log警报
    sed -i '$a net.core.wmem_max=16777216' package/base-files/files/etc/sysctl.conf
    sed -i '$a net.core.rmem_max=16777216' package/base-files/files/etc/sysctl.conf

    # 修改版本为编译日期
    # orig_version=$(awk -F "'" '/DISTRIB_REVISION=/{print $2}' package/lean/default-settings/files/zzz-default-settings)
    # sed -i "s/$orig_version/R$(date +%y.%-m.%-d)/g" package/lean/default-settings/files/zzz-default-settings
    sed -i "s/DISTRIB_DESCRIPTION=.*/DISTRIB_DESCRIPTION=\"OpenWrt By @Ethan\"/g" package/base-files/files/etc/openwrt_release
    sed -i "s/DISTRIB_ID=.*/DISTRIB_ID='Ethan'/g" package/base-files/files/etc/openwrt_release
    sed -i 's/^VERSION_DIST:=.*/VERSION_DIST:=Ethan/' include/version.mk
    sed -i "s/OPENWRT_RELEASE=.*/OPENWRT_RELEASE=\"Ethan R$(TZ=UTC-8 date +'%y.%-m.%-d')\"/g" package/lean/default-settings/files/zzz-default-settings
    echo -e "\e[41m当前写入的编译时间:\e[0m \e[33m$(grep 'OPENWRT_RELEASE' package/base-files/files/usr/lib/os-release)\e[0m"

    # 修改欢迎banner
    sed -i "/\\   DE \//s/$/  [31mBy @Ethan build $(TZ=UTC-8 date '+%Y.%m.%d')[0m/" package/base-files/files/etc/banner
    cat package/base-files/files/etc/banner

    # 删除主题默认设置
    # find $destination_dir/luci-theme-*/ -type f -name '*luci-theme-*' -exec sed -i '/set luci.main.mediaurlbase/d' {} +

    # 调整docker到"服务"菜单
    # sed -i 's/"admin"/"admin", "services"/g' feeds/luci/applications/luci-app-dockerman/luasrc/controller/*.lua
    # sed -i 's/"admin"/"admin", "services"/g; s/admin\//admin\/services\//g' feeds/luci/applications/luci-app-dockerman/luasrc/model/cbi/dockerman/*.lua
    # sed -i 's/admin\//admin\/services\//g' feeds/luci/applications/luci-app-dockerman/luasrc/view/dockerman/*.htm
    # sed -i 's|admin\\|admin\\/services\\|g' feeds/luci/applications/luci-app-dockerman/luasrc/view/dockerman/container.htm

    # 取消对samba4的菜单调整
    # sed -i '/samba4/s/^/#/' package/lean/default-settings/files/zzz-default-settings
}

# 更新配置文件
update_config_file() {
    [ -e "$GITHUB_WORKSPACE/$CONFIG_FILE" ] && cp -f "$GITHUB_WORKSPACE/$CONFIG_FILE" .config
    make defconfig 1>/dev/null 2>&1
}

# 检测指令集架构
detect_openwrt_arch() {
    local config="${1:-.config}"
    local arch_pkgs=$(grep '^CONFIG_TARGET_ARCH_PACKAGES=' "$config" | cut -d'"' -f2)
    [ -n "$arch_pkgs" ] || return 1
    case "$arch_pkgs" in
        x86_64) echo "amd64" ;; i386*) echo "386" ;; aarch64*) echo "arm64" ;;
        arm_cortex-a*) echo "armv7" ;; arm_arm1176*|arm_mpcore*) echo "armv6" ;;
        arm_arm926*|arm_fa526|arm*xscale) echo "armv5" ;;
        mips64el_*) echo "mips64le" ;; mips64_*) echo "mips64" ;;
        mipsel_*) echo "mipsle" ;; mips_*) echo "mips" ;;
        riscv64*) echo "riscv64" ;; loongarch64*) echo "loong64" ;;
        powerpc64_*) echo "ppc64" ;; powerpc_*) echo "ppc" ;;
        arc_*) echo "arc" ;; *) echo "unknown" ;;
    esac
}

# 下载openclash运行内核
preset_openclash_core() {
    CPU_ARCH=$(detect_openwrt_arch ".config")
    if [[ "$CPU_ARCH" =~ ^(amd64|arm64|armv7|armv6|armv5|386|mips64|mips64le|riscv64)$ ]] && grep -q "luci-app-openclash=y" .config; then
        chmod +x $GITHUB_WORKSPACE/scripts/preset-clash-core.sh
        $GITHUB_WORKSPACE/scripts/preset-clash-core.sh $CPU_ARCH
    else
        return 99
    fi
}

# 下载zsh终端工具
preset_shell_tools() {
    if grep -q "zsh=y" .config; then
        chmod +x $GITHUB_WORKSPACE/scripts/preset-terminal-tools.sh
        $GITHUB_WORKSPACE/scripts/preset-terminal-tools.sh
    else
        return 99
    fi
}

show_build_info() {
    echo -e "$(color cy "📊 当前编译信息")"
    echo "========================================"
    echo "🔷 固件源码: $(color cc "$SOURCE_REPO")"
    echo "🔷 源码分支: $(color cc "$REPO_BRANCH")"
    echo "🔷 目标设备: $(color cc "$DEVICE_TARGET")"
    echo "🔷 内核版本: $(color cc "$KERNEL_VERSION")"
    echo "🔷 编译架构: $(color cc "$CPU_ARCH")"
    echo "========================================"
}

main "$@"