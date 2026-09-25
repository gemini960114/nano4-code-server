#!/usr/bin/env bash
# ==============================================================================
# install_code_server.sh - 免 root 安裝 code-server (官方 standalone 版) 至 ~/.local
# 用法:
#   ./install_code_server.sh             # 安裝最新版 (已安裝則升級)
#   ./install_code_server.sh 4.137.0     # 安裝指定版本
# 可用 PREFIX 環境變數改變安裝位置 (預設 ~/.local)
# ==============================================================================
set -euo pipefail

PREFIX="${PREFIX:-${HOME}/.local}"
VERSION="${1:-}"

# 官方 install.sh 若發現目標目錄不存在或不可寫，會改用 sudo；
# HPC 上沒有 root 權限，因此先自行建立目錄
mkdir -p "${PREFIX}/lib" "${PREFIX}/bin"

if [ -x "${PREFIX}/bin/code-server" ]; then
    echo "==> 目前已安裝: $("${PREFIX}/bin/code-server" --version | head -n 1 | cut -d' ' -f1)"
fi

ARGS=(--method=standalone --prefix="${PREFIX}")
[ -n "${VERSION}" ] && ARGS+=(--version="${VERSION}")

echo "==> 下載並安裝 code-server ${VERSION:-(最新版)} 至 ${PREFIX} ..."
curl -fsSL https://code-server.dev/install.sh | sh -s -- "${ARGS[@]}"

echo "========================================================"
echo "✅ 安裝完成: $("${PREFIX}/bin/code-server" --version | head -n 1)"
echo "   執行檔: ${PREFIX}/bin/code-server"
if ! echo ":${PATH}:" | grep -q ":${PREFIX}/bin:"; then
    echo ""
    echo "   (選用) 加入 PATH，之後可直接輸入 code-server:"
    echo "   echo 'export PATH=\"${PREFIX}/bin:\$PATH\"' >> ~/.bashrc && source ~/.bashrc"
fi
echo "--------------------------------------------------------"
echo "下一步:"
echo "   ./password_setup.sh 您的密碼"
echo "   ./start.sh 1"
echo "========================================================"
