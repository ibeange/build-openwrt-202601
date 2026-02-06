#!/bin/bash

# 鎵撳寘toolchain鐩綍
if [[ "$REBUILD_TOOLCHAIN" = 'true' ]]; then
    cd $OPENWRT_PATH
    sed -i 's/ $(tool.*\/stamp-compile)//' Makefile
    if [[ -d ".ccache" && $(du -s .ccache | cut -f1) -gt 0 ]]; then
        echo "馃攳 缂撳瓨鐩綍澶у皬:"
        du -h --max-depth=1 .ccache
        ccache_dir=".ccache"
    fi
    echo "馃摝 宸ュ叿閾剧洰褰曞ぇ灏?"
    du -h --max-depth=1 staging_dir
    tar -I zstdmt -cf "$GITHUB_WORKSPACE/output/$CACHE_NAME.tzst" staging_dir/host* staging_dir/tool* $ccache_dir
    echo "馃搧 杈撳嚭鐩綍鍐呭:"
    ls -lh "$GITHUB_WORKSPACE/output"
    if [[ ! -e "$GITHUB_WORKSPACE/output/$CACHE_NAME.tzst" ]]; then
        echo "鉂?宸ュ叿閾炬墦鍖呭け璐?"
        exit 1
    fi
    echo "鉁?宸ュ叿閾炬墦鍖呭畬鎴?
    exit 0
fi

# 鍒涘缓toolchain缂撳瓨淇濆瓨鐩綍
[ -d "$GITHUB_WORKSPACE/output" ] || mkdir "$GITHUB_WORKSPACE/output"

# 棰滆壊杈撳嚭
color() {
    case "$1" in
        cr) echo -e "\e[1;31m${2}\e[0m" ;;  # 绾㈣壊
        cg) echo -e "\e[1;32m${2}\e[0m" ;;  # 缁胯壊
        cy) echo -e "\e[1;33m${2}\e[0m" ;;  # 榛勮壊
        cb) echo -e "\e[1;34m${2}\e[0m" ;;  # 钃濊壊
        cp) echo -e "\e[1;35m${2}\e[0m" ;;  # 绱壊
        cc) echo -e "\e[1;36m${2}\e[0m" ;;  # 闈掕壊
        cw) echo -e "\e[1;37m${2}\e[0m" ;;  # 鐧借壊
    esac
}

# 鐘舵€佹樉绀哄拰鏃堕棿缁熻
status_info() {
    local task_name="$1" begin_time=$(date +%s) exit_code time_info
    shift
    "$@"
    exit_code=$?
    [[ "$exit_code" -eq 99 ]] && return 0
    if [[ -n "$begin_time" ]]; then
        time_info="==> 鐢ㄦ椂 $(($(date +%s) - begin_time)) 绉?
    else
        time_info=""
    fi
    if [[ "$exit_code" -eq 0 ]]; then
        printf "%s %-52s %s %s %s %s %s %s %s\n" \
        $(color cy "鈴?$task_name") [ $(color cg 鉁? ] $(color cw "$time_info")
    else
        printf "%s %-52s %s %s %s %s %s %s %s\n" \
        $(color cy "鈴?$task_name") [ $(color cr 鉁? ] $(color cw "$time_info")
    fi
}

# 鏌ユ壘鐩綍
find_dir() {
    find $1 -maxdepth 3 -type d -name "$2" -print -quit 2>/dev/null
}

# 鎵撳嵃淇℃伅
print_info() {
    printf "%s %-40s %s %s %s\n" "$1" "$2" "$3" "$4" "$5"
}

# 娣诲姞鏁翠釜婧愪粨搴?git clone)
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
        print_info $(color cr 鎷夊彇) "$repo_url" [ $(color cr 鉁? ]
        return 1
    }
    rm -rf $target_dir/{.git*,README*.md,LICENSE}
    current_dir=$(find_dir "package/ feeds/ target/" "$target_dir")
    if [[ -d "$current_dir" ]]; then
        rm -rf "$current_dir"
        mv -f "$target_dir" "${current_dir%/*}"
        print_info $(color cg 鏇挎崲) "$target_dir" [ $(color cg 鉁? ]
    else
        mv -f "$target_dir" "$destination_dir"
        print_info $(color cb 娣诲姞) "$target_dir" [ $(color cb 鉁? ]
    fi
}

# 娣诲姞婧愪粨搴撳唴鐨勬寚瀹氱洰褰?
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
        print_info $(color cr 鎷夊彇) "$repo_url" [ $(color cr 鉁? ]
        rm -rf "$temp_dir"
        return 1
    }
    local target_dir source_dir current_dir
    for target_dir in "$@"; do
        source_dir=$(find_dir "$temp_dir" "$target_dir")
        [[ -d "$source_dir" ]] || \
        source_dir=$(find "$temp_dir" -maxdepth 4 -type d -name "$target_dir" -print -quit) && \
        [[ -d "$source_dir" ]] || {
            print_info $(color cr 鏌ユ壘) "$target_dir" [ $(color cr 鉁? ]
            continue
        }
        current_dir=$(find_dir "package/ feeds/ target/" "$target_dir")
        if [[ -d "$current_dir" ]]; then
            rm -rf "$current_dir"
            mv -f "$source_dir" "${current_dir%/*}"
            print_info $(color cg 鏇挎崲) "$target_dir" [ $(color cg 鉁? ]
        else
            mv -f "$source_dir" "$destination_dir"
            print_info $(color cb 娣诲姞) "$target_dir" [ $(color cb 鉁? ]
        fi
    done
    rm -rf "$temp_dir"
}

# 娣诲姞婧愪粨搴撳唴鐨勬墍鏈夊瓙鐩綍
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
        print_info $(color cr 鎷夊彇) "$repo_url" [ $(color cr 鉁? ]
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
                print_info $(color cg 鏇挎崲) "$target_dir" [ $(color cg 鉁? ]
            else
                mv -f "$source_dir" "$destination_dir"
                print_info $(color cb 娣诲姞) "$target_dir" [ $(color cb 鉁? ]
            fi
        done < <(find "$1" -maxdepth 1 -mindepth 1 -type d ! -name '.*')
    }
    if [[ $# -eq 0 ]]; then
        process_dir "$temp_dir"
    else
        for dir_name in "$@"; do
            [[ -d "$temp_dir/$dir_name" ]] && process_dir "$temp_dir/$dir_name" || \
            print_info $(color cr 鐩綍) "$dir_name" [ $(color cr 鉁? ]
        done
    fi
    rm -rf "$temp_dir"
}

# 涓绘祦绋?
main() {
    echo "$(color cp "馃殌 寮€濮嬭繍琛岃嚜瀹氫箟鑴氭湰")"
    echo "========================================"

    # 鎷夊彇缂栬瘧婧愮爜
    status_info "鎷夊彇缂栬瘧婧愮爜" clone_source_code

    # 璁剧疆鐜鍙橀噺
    status_info "璁剧疆鐜鍙橀噺" set_variable_values

    # 涓嬭浇閮ㄧ讲toolchain缂撳瓨
    status_info "涓嬭浇閮ㄧ讲toolchain缂撳瓨" download_toolchain

    # 鏇存柊&瀹夎鎻掍欢
    status_info "鏇存柊&瀹夎鎻掍欢" update_install_feeds

    # 娣诲姞棰濆鎻掍欢
    status_info "娣诲姞棰濆鎻掍欢" add_custom_packages

    # 鍔犺浇涓汉璁剧疆
    status_info "鍔犺浇涓汉璁剧疆" apply_custom_settings

    # 鏇存柊閰嶇疆鏂囦欢
    status_info "鏇存柊閰嶇疆鏂囦欢" update_config_file

    # 涓嬭浇openclash杩愯鍐呮牳
    status_info "涓嬭浇openclash杩愯鍐呮牳" preset_openclash_core

    # 涓嬭浇zsh缁堢宸ュ叿
    status_info "涓嬭浇zsh缁堢宸ュ叿" preset_shell_tools

    # 鏄剧ず缂栬瘧淇℃伅
    show_build_info

    echo "$(color cp "鉁?鑷畾涔夎剼鏈繍琛屽畬鎴?)"
    echo "========================================"
}

# 鎷夊彇缂栬瘧婧愮爜
clone_source_code() {
    # 璁剧疆缂栬瘧婧愮爜涓庡垎鏀?
    REPO_URL="https://github.com/coolsnowwolf/lede"
    echo "REPO_URL=$REPO_URL" >>$GITHUB_ENV
    REPO_BRANCH="master"
    echo "REPO_BRANCH=$REPO_BRANCH" >>$GITHUB_ENV

    # 鎷夊彇缂栬瘧婧愮爜
    # cd /workdir
    git clone -q -b "$REPO_BRANCH" --single-branch "$REPO_URL" openwrt
    # ln -sf /workdir/openwrt $GITHUB_WORKSPACE/openwrt
    [ -d openwrt ] && cd openwrt || exit
    echo "OPENWRT_PATH=$PWD" >>$GITHUB_ENV

    # 璁剧疆luci鐗堟湰涓?8.06
    sed -i '/luci/s/^#//; /luci.git;openwrt/s/^/#/' feeds.conf.default
}

# 璁剧疆鐜鍙橀噺
set_variable_values() {
    local TARGET_NAME SUBTARGET_NAME KERNEL TOOLS_HASH

    # 婧愪粨搴撲笌鍒嗘敮
    SOURCE_REPO=$(basename "$REPO_URL")
    echo "SOURCE_REPO=$SOURCE_REPO" >>$GITHUB_ENV
    echo "LITE_BRANCH=${REPO_BRANCH#*-}" >>$GITHUB_ENV

    # 骞冲彴鏋舵瀯
    TARGET_NAME=$(grep -oP "^CONFIG_TARGET_\K[a-z0-9]+(?==y)" "$GITHUB_WORKSPACE/$CONFIG_FILE")
    SUBTARGET_NAME=$(grep -oP "^CONFIG_TARGET_${TARGET_NAME}_\K[a-z0-9]+(?==y)" "$GITHUB_WORKSPACE/$CONFIG_FILE")
    DEVICE_TARGET="$TARGET_NAME-$SUBTARGET_NAME"
    echo "DEVICE_TARGET=$DEVICE_TARGET" >>$GITHUB_ENV

    # 鍐呮牳鐗堟湰
    KERNEL=$(grep -oP 'KERNEL_PATCHVER:=\K[\d\.]+' "target/linux/$TARGET_NAME/Makefile")
    KERNEL_VERSION=$(grep -oP 'LINUX_KERNEL_HASH-\K[\d\.]+' "include/kernel-$KERNEL")
    echo "KERNEL_VERSION=$KERNEL_VERSION" >>$GITHUB_ENV

    # toolchain缂撳瓨鏂囦欢鍚?
    TOOLS_HASH=$(git log -1 --pretty=format:"%h" tools toolchain)
    CACHE_NAME="$SOURCE_REPO-${REPO_BRANCH#*-}-$DEVICE_TARGET-cache-$TOOLS_HASH"
    echo "CACHE_NAME=$CACHE_NAME" >>$GITHUB_ENV

    # 婧愮爜鏇存柊淇℃伅
    echo "COMMIT_AUTHOR=$(git show -s --date=short --format="浣滆€? %an")" >>$GITHUB_ENV
    echo "COMMIT_DATE=$(git show -s --date=short --format="鏃堕棿: %ci")" >>$GITHUB_ENV
    echo "COMMIT_MESSAGE=$(git show -s --date=short --format="鍐呭: %s")" >>$GITHUB_ENV
    echo "COMMIT_HASH=$(git show -s --date=short --format="hash: %H")" >>$GITHUB_ENV
}

# 涓嬭浇閮ㄧ讲toolchain缂撳瓨
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
            echo "鈿狅笍 鏈壘鍒版渶鏂板伐鍏烽摼"
            return 99
        fi
    else
        echo "REBUILD_TOOLCHAIN=true" >>$GITHUB_ENV
        return 99
    fi
}

# 鏇存柊&瀹夎鎻掍欢
update_install_feeds() {
    ./scripts/feeds update -a 1>/dev/null 2>&1
    ./scripts/feeds install -a 1>/dev/null 2>&1
}

# 娣诲姞棰濆鎻掍欢
add_custom_packages() {
    echo "馃摝 娣诲姞棰濆鎻掍欢..."

    # 鍒涘缓鎻掍欢淇濆瓨鐩綍
    destination_dir="package/A"
    [ -d "$destination_dir" ] || mkdir -p "$destination_dir"

    # 鍩虹鎻掍欢
    # git_clone https://github.com/kongfl888/luci-app-adguardhome
    # clone_dir lua https://github.com/sbwml/luci-app-alist luci-app-alist
    # clone_all https://github.com/linkease/istore-ui
    # clone_all https://github.com/linkease/istore luci

    clone_all https://github.com/sirpdboy/luci-app-ddns-go

    clone_all v5 https://github.com/sbwml/luci-app-mosdns

    git_clone https://github.com/pymumu/luci-app-smartdns
    git_clone https://github.com/pymumu/openwrt-smartdns smartdns

    git_clone https://github.com/sbwml/packages_lang_golang golang

    git_clone https://github.com/ximiTech/luci-app-msd_lite
    git_clone https://github.com/ximiTech/msd_lite

    # UU娓告垙鍔犻€熷櫒
    clone_dir https://github.com/kiddin9/kwrt-packages luci-app-uugamebooster
    clone_dir https://github.com/kiddin9/kwrt-packages uugamebooster

    # 鍏虫満
    clone_all https://github.com/sirpdboy/luci-app-poweroffdevice
    
    # luci-app-filemanager
    git_clone https://github.com/sbwml/luci-app-filemanager luci-app-filemanager
    
    # 娣诲姞 Turbo ACC 缃戠粶鍔犻€?
    git_clone https://github.com/kiddin9/kwrt-packages luci-app-turboacc

    # 绉戝涓婄綉鎻掍欢
    # clone_all https://github.com/fw876/helloworld
    # clone_all https://github.com/Openwrt-Passwall/openwrt-passwall-packages
    # clone_all https://github.com/Openwrt-Passwall/openwrt-passwall
    # clone_all https://github.com/Openwrt-Passwall/openwrt-passwall2
    clone_dir https://github.com/vernesong/OpenClash luci-app-openclash
    clone_dir https://github.com/sbwml/openwrt_helloworld xray-core
    clone_all https://github.com/nikkinikki-org/OpenWrt-nikki
    clone_dir https://github.com/kiddin9/kwrt-packages luci-app-v2ray-server

    # Themes
    git_clone https://github.com/jerrykuku/luci-theme-argon
    git_clone https://github.com/jerrykuku/luci-app-argon-config
    # clone_dir https://github.com/xiaoqingfengATGH/luci-theme-infinityfreedom luci-theme-infinityfreedom-ng
    # clone_dir https://github.com/haiibo/packages luci-theme-opentomcat

    # 鏅舵櫒瀹濈洅
    # clone_all https://github.com/ophub/luci-app-amlogic
    # sed -i "s|firmware_repo.*|firmware_repo 'https://github.com/$GITHUB_REPOSITORY'|g" $destination_dir/luci-app-amlogic/root/etc/config/amlogic
    # sed -i "s|kernel_path.*|kernel_path 'https://github.com/ophub/kernel'|g" $destination_dir/luci-app-amlogic/root/etc/config/amlogic
    # sed -i "s|ARMv8|$RELEASE_TAG|g" $destination_dir/luci-app-amlogic/root/etc/config/amlogic

    # 淇Makefile璺緞
    find "$destination_dir" -type f -name "Makefile" | xargs sed -i \
        -e 's?\.\./\.\./\(lang\|devel\)?$(TOPDIR)/feeds/packages/\1?' \
        -e 's?\.\./\.\./luci.mk?$(TOPDIR)/feeds/luci/luci.mk?'

    # 杞崲鎻掍欢璇█缈昏瘧
    for e in $(ls -d $destination_dir/luci-*/po feeds/luci/applications/luci-*/po); do
        if [[ -d $e/zh-cn && ! -d $e/zh_Hans ]]; then
            ln -s zh-cn $e/zh_Hans 2>/dev/null
        elif [[ -d $e/zh_Hans && ! -d $e/zh-cn ]]; then
            ln -s zh_Hans $e/zh-cn 2>/dev/null
        fi
    done
}

# 鍔犺浇涓汉璁剧疆
apply_custom_settings() {
    local orig_version

    [ -e "$GITHUB_WORKSPACE/files" ] && mv "$GITHUB_WORKSPACE/files" files

    # 璁剧疆鍥轰欢rootfs澶у皬
    if [ "$PART_SIZE" ]; then
        sed -i '/ROOTFS_PARTSIZE/d' "$GITHUB_WORKSPACE/$CONFIG_FILE"
        echo "CONFIG_TARGET_ROOTFS_PARTSIZE=$PART_SIZE" >>"$GITHUB_WORKSPACE/$CONFIG_FILE"
    fi

    # 淇敼榛樿ip鍦板潃
    [ "$IP_ADDRESS" ] && sed -i '/lan) ipad/s/".*"/"'"$IP_ADDRESS"'"/' package/base-files/*/bin/config_generate

    # 鏇存敼榛樿shell涓簔sh
    # sed -i 's/\/bin\/ash/\/usr\/bin\/zsh/g' package/base-files/files/etc/passwd

    # ttyd鍏嶇櫥褰?
    sed -i 's|/bin/login|/bin/login -f root|g' feeds/packages/utils/ttyd/files/ttyd.config

    # 璁剧疆 root 鐢ㄦ埛瀵嗙爜涓?password
    sed -i 's/root:::0:99999:7:::/root:$1$V4UetPzk$CYXluq4wUazHjmCDBCqXF.::0:99999:7:::/g' package/base-files/files/etc/shadow
    
    # 鏇存敼argon涓婚鑳屾櫙
    cp -f $GITHUB_WORKSPACE/images/bg1.jpg feeds/luci/themes/luci-theme-argon/htdocs/luci-static/argon/img/bg1.jpg

    echo "鑿滃崟 璋冩暣..."
    # sed -i 's|/services/|/control/|' feeds/luci/applications/luci-app-wol/root/usr/share/luci/menu.d/luci-app-wol.json
    #sed -i 's|/services/|/network/|' feeds/luci/applications/luci-app-nlbwmon/root/usr/share/luci/menu.d/luci-app-nlbwmon.json
    #sed -i 's|/services/|/nas/|' feeds/luci/applications/luci-app-alist/root/usr/share/luci/menu.d/luci-app-openlist2.json
    sed -i '/"title": "Nikki",/a \        "order": -9,' package/waynesg/luci-app-nikki/luci-app-nikki/root/usr/share/luci/menu.d/luci-app-nikki.json
    sed -i 's/("OpenClash"), 50)/("OpenClash"), -10)/g' feeds/luci/applications/luci-app-openclash/luasrc/controller/openclash.lua
    sed -i 's/"缃戠粶瀛樺偍"/"瀛樺偍"/g' `grep "缃戠粶瀛樺偍" -rl ./`
    sed -i 's/"杞欢鍖?/"杞欢绠＄悊"/g' `grep "杞欢鍖? -rl ./`

    # 绮剧畝 UPnP 鑿滃崟鍚嶇О
    sed -i 's,UPnP IGD 鍜?PCP,UPnP,g' feeds/luci/applications/luci-app-upnp/po/zh-cn/upnp.po
        
    echo "閲嶅懡鍚嶇郴缁熻彍鍗?
    #status menu
    sed -i 's/"姒傝"/"绯荤粺姒傝"/g' feeds/luci/modules/luci-base/po/zh-cn/base.po
    sed -i 's/"璺敱"/"璺敱鏄犲皠"/g' feeds/luci/modules/luci-base/po/zh-cn/base.po
    #system menu
    #sed -i 's/"绯荤粺"/"绯荤粺璁剧疆"/g' feeds/luci/modules/luci-base/po/zh-cn/base.po
    sed -i 's/"绠＄悊鏉?/"鏉冮檺绠＄悊"/g' feeds/luci/modules/luci-base/po/zh-cn/base.po
    sed -i 's/"閲嶅惎"/"绔嬪嵆閲嶅惎"/g' feeds/luci/modules/luci-base/po/zh-cn/base.po
    sed -i 's/"澶囦唤涓庡崌绾?/"澶囦唤鍗囩骇"/g' feeds/luci/modules/luci-base/po/zh-cn/base.po
    sed -i 's/"鎸傝浇鐐?/"鎸傝浇璺緞"/g' feeds/luci/modules/luci-base/po/zh-cn/base.po
    sed -i 's/"鍚姩椤?/"鍚姩绠＄悊"/g' feeds/luci/modules/luci-base/po/zh-cn/base.po
    sed -i 's/"杞欢鍖?/"杞欢绠＄悊"/g' feeds/luci/modules/luci-base/po/zh-cn/base.po

    
    # 鏇存敼 ttyd 椤哄簭鍜屽悕绉?
    sed -i '3a \		"order": 10,' feeds/luci/applications/luci-app-ttyd/root/usr/share/luci/menu.d/luci-app-ttyd.json
    sed -i 's/"缁堢"/"鍛戒护缁堢"/g' feeds/luci/applications/luci-app-ttyd/po/zh-cn/ttyd.po
    
    # 璁剧疆 nlbwmon 鐙珛鑿滃崟
    sed -i 's/524288/16777216/g' feeds/packages/net/nlbwmon/files/nlbwmon.config
    sed -i 's/option commit_interval.*/option commit_interval 24h/g' feeds/packages/net/nlbwmon/files/nlbwmon.config
    sed -i 's/services\/nlbw/nlbw/g; /path/s/admin\///g' feeds/luci/applications/luci-app-nlbwmon/root/usr/share/luci/menu.d/luci-app-nlbwmon.json
    sed -i 's/services\///g' feeds/luci/applications/luci-app-nlbwmon/htdocs/luci-static/resources/view/nlbw/config.js
    
    echo "閲嶅懡鍚嶇綉缁滆彍鍗?
    #network
    sed -i 's/"鎺ュ彛"/"缃戠粶鎺ュ彛"/g' `grep "鎺ュ彛" -rl ./`
    sed -i 's/DHCP\/DNS/DHCP/g' feeds/luci/modules/luci-base/po/zh-cn/base.po

    # x86鍨嬪彿鍙樉绀篶pu鍨嬪彿
    sed -i 's/${g}.*/${a}${b}${c}${d}${e}${f}${hydrid}/g' package/lean/autocore/files/x86/autocore
    sed -i "s/'C'/'Core '/g; s/'T '/'Thread '/g" package/lean/autocore/files/x86/autocore

    # 鏈€澶ц繛鎺ユ暟淇敼涓?5535
    sed -i '$a net.netfilter.nf_conntrack_max=65535' package/base-files/files/etc/sysctl.conf
    
    # 淇敼鏈湴鏃堕棿鏍煎紡
    sed -i 's/os.date()/os.date("%a %Y-%m-%d %H:%M:%S")/g' package/emortal/autocore/files/*/index.htm
    
    #nlbwmon 淇log璀︽姤
    sed -i '$a net.core.wmem_max=16777216' package/base-files/files/etc/sysctl.conf
    sed -i '$a net.core.rmem_max=16777216' package/base-files/files/etc/sysctl.conf

    # 淇敼鐗堟湰涓虹紪璇戞棩鏈?
    # orig_version=$(awk -F "'" '/DISTRIB_REVISION=/{print $2}' package/lean/default-settings/files/zzz-default-settings)
    # sed -i "s/$orig_version/R$(date +%y.%-m.%-d)/g" package/lean/default-settings/files/zzz-default-settings
    sed -i "s/DISTRIB_DESCRIPTION=.*/DISTRIB_DESCRIPTION=\"OpenWrt By @Ethan\"/g" package/base-files/files/etc/openwrt_release
    sed -i "s/DISTRIB_ID=.*/DISTRIB_ID='Ethan'/g" package/base-files/files/etc/openwrt_release
    sed -i 's/^VERSION_DIST:=.*/VERSION_DIST:=Ethan/' include/version.mk
    sed -i "s/OPENWRT_RELEASE=.*/OPENWRT_RELEASE=\"Ethan R$(TZ=UTC-8 date +'%y.%-m.%-d')\"/g" package/lean/default-settings/files/zzz-default-settings
    echo -e "\e[41m褰撳墠鍐欏叆鐨勭紪璇戞椂闂?\e[0m \e[33m$(grep 'OPENWRT_RELEASE' package/base-files/files/usr/lib/os-release)\e[0m"

    # 鍒犻櫎涓婚榛樿璁剧疆
    # find $destination_dir/luci-theme-*/ -type f -name '*luci-theme-*' -exec sed -i '/set luci.main.mediaurlbase/d' {} +

    # 璋冩暣docker鍒?鏈嶅姟"鑿滃崟
    # sed -i 's/"admin"/"admin", "services"/g' feeds/luci/applications/luci-app-dockerman/luasrc/controller/*.lua
    # sed -i 's/"admin"/"admin", "services"/g; s/admin\//admin\/services\//g' feeds/luci/applications/luci-app-dockerman/luasrc/model/cbi/dockerman/*.lua
    # sed -i 's/admin\//admin\/services\//g' feeds/luci/applications/luci-app-dockerman/luasrc/view/dockerman/*.htm
    # sed -i 's|admin\\|admin\\/services\\|g' feeds/luci/applications/luci-app-dockerman/luasrc/view/dockerman/container.htm

    # 鍙栨秷瀵箂amba4鐨勮彍鍗曡皟鏁?
    # sed -i '/samba4/s/^/#/' package/lean/default-settings/files/zzz-default-settings
}

# 鏇存柊閰嶇疆鏂囦欢
update_config_file() {
    [ -e "$GITHUB_WORKSPACE/$CONFIG_FILE" ] && cp -f "$GITHUB_WORKSPACE/$CONFIG_FILE" .config
    make defconfig 1>/dev/null 2>&1
}

# 妫€娴嬫寚浠ら泦鏋舵瀯
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

# 涓嬭浇openclash杩愯鍐呮牳
preset_openclash_core() {
    CPU_ARCH=$(detect_openwrt_arch ".config")
    if [[ "$CPU_ARCH" =~ ^(amd64|arm64|armv7|armv6|armv5|386|mips64|mips64le|riscv64)$ ]] && grep -q "luci-app-openclash=y" .config; then
        chmod +x $GITHUB_WORKSPACE/scripts/preset-clash-core.sh
        $GITHUB_WORKSPACE/scripts/preset-clash-core.sh $CPU_ARCH
    else
        return 99
    fi
}

# 涓嬭浇zsh缁堢宸ュ叿
preset_shell_tools() {
    if grep -q "zsh=y" .config; then
        chmod +x $GITHUB_WORKSPACE/scripts/preset-terminal-tools.sh
        $GITHUB_WORKSPACE/scripts/preset-terminal-tools.sh
    else
        return 99
    fi
}

show_build_info() {
    echo -e "$(color cy "馃搳 褰撳墠缂栬瘧淇℃伅")"
    echo "========================================"
    echo "馃敺 鍥轰欢婧愮爜: $(color cc "$SOURCE_REPO")"
    echo "馃敺 婧愮爜鍒嗘敮: $(color cc "$REPO_BRANCH")"
    echo "馃敺 鐩爣璁惧: $(color cc "$DEVICE_TARGET")"
    echo "馃敺 鍐呮牳鐗堟湰: $(color cc "$KERNEL_VERSION")"
    echo "馃敺 缂栬瘧鏋舵瀯: $(color cc "$CPU_ARCH")"
    echo "========================================"
}

main "$@"
