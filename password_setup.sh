#!/usr/bin/env bash
# ==============================================================================
# password_setup.sh - 設定或重新生成 code-server 密碼 (修改後需 ./stop.sh 再 ./start.sh 才生效)
# 用法:
#   ./password_setup.sh            # 自動生成 14 碼隨機密碼
#   ./password_setup.sh 自訂密碼
# ==============================================================================
set -euo pipefail

PASSWORD_FILE="${HOME}/.code-server-password"

if [ -n "${1:-}" ]; then
    NEW_PASS="$1"
else
    NEW_PASS="$(tr -dc A-Za-z0-9 </dev/urandom | head -c 14 || true)"
fi

echo "${NEW_PASS}" > "${PASSWORD_FILE}"
chmod 600 "${PASSWORD_FILE}"

echo "✅ 密碼已寫入 ${PASSWORD_FILE} (權限 600)"
echo "   密碼內容: ${NEW_PASS}"
echo "   若服務正在運行，請執行 ./stop.sh 後再 ./start.sh 1 或 ./start.sh 2"
