#!/usr/bin/env bash
# ==============================================================================
# start.sh - 在 Nano4 登入節點以 tmux 背景啟動 code-server
#
# 用法:
#   ./start.sh 1   (或 local)  : localhost 模式 - 經 SSH 通道連線，不需 base URL，webview 正常
#   ./start.sh 2   (或 remote) : remote 模式    - 經 Nano4 OOD /node 反向代理連線
#   ./start.sh status          : 顯示目前運行中的服務與連線方式
# ==============================================================================
set -euo pipefail

SESSION_NAME="nano4-code-server"
PASSWORD_FILE="${HOME}/.code-server-password"
INFO_FILE="${HOME}/.nano4-code-server.info"
OOD_HOST="nano4.nchc.org.tw"
SSH_HOST="nano4.nchc.org.tw"
LOCAL_PORT="${LOCAL_PORT:-8080}"   # localhost 模式下，使用者電腦端的連接埠
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_FILE="${HOME}/.nano4-code-server.state"   # 機器可讀狀態 (HOST/PORT/MODE/CHECK_PATH)
STOP_FILE="${HOME}/.nano4-code-server.stop"     # 跨登入節點的停止請求 ($HOME 各節點共用)

usage() {
    sed -n '4,8p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    exit 1
}

show_info() {
    if [ -f "${INFO_FILE}" ]; then
        cat "${INFO_FILE}"
    else
        echo "ℹ️ 找不到連線資訊檔 ${INFO_FILE}"
    fi
}

# 檢查服務狀態 (Nano4 有多台登入節點，服務可能在另一台上)
#   回傳 0: 本節點運行中 / 1: 其他節點運行中 (RUN_HOST) / 2: 沒有運行
service_state() {
    if tmux has-session -t "${SESSION_NAME}" 2>/dev/null; then
        return 0
    fi
    if [ -f "${STATE_FILE}" ]; then
        RUN_HOST="$(sed -n 's/^HOST=//p' "${STATE_FILE}")"
        local port path
        port="$(sed -n 's/^PORT=//p' "${STATE_FILE}")"
        path="$(sed -n 's/^CHECK_PATH=//p' "${STATE_FILE}")"
        if [ "${RUN_HOST}" != "$(hostname -s)" ] &&
           [ "$(curl -s -m 3 -o /dev/null -w '%{http_code}' "http://${RUN_HOST}:${port}${path}" || true)" = "200" ]; then
            return 1
        fi
        rm -f "${STATE_FILE}" "${INFO_FILE}"   # 殘留的舊狀態
    fi
    return 2
}

# ------------------------------------------------------------------------------
# 0. 解析參數
# ------------------------------------------------------------------------------
case "${1:-}" in
    1|local|localhost) MODE="local" ;;
    2|remote)          MODE="remote" ;;
    status)
        rc=0; service_state || rc=$?
        case ${rc} in
            0) show_info ;;
            1) echo "ℹ️ 服務運行於另一台登入節點 ${RUN_HOST}，連線方式不變:"; show_info ;;
            2) echo "ℹ️ 目前沒有運行中的 '${SESSION_NAME}' 服務。" ;;
        esac
        exit 0 ;;
    *) usage ;;
esac

# ------------------------------------------------------------------------------
# 1. 已在運行則直接顯示資訊 (一次只允許一個實例，避免共用設定目錄衝突)
# ------------------------------------------------------------------------------
rc=0; service_state || rc=$?
if [ ${rc} -eq 0 ]; then
    echo "⚠️ '${SESSION_NAME}' 已經在運行中！如需切換模式，請先執行 ./stop.sh"
    show_info
    exit 0
elif [ ${rc} -eq 1 ]; then
    echo "⚠️ 服務已運行於另一台登入節點 ${RUN_HOST}，可直接使用 (連線方式如下)。"
    echo "   如需重新啟動或切換模式，請先執行 ./stop.sh (任一登入節點皆可)"
    show_info
    exit 0
fi
rm -f "${STOP_FILE}"

# ------------------------------------------------------------------------------
# 2. 尋找 code-server 與 node 執行檔
# ------------------------------------------------------------------------------
if [ -x "${HOME}/.local/bin/code-server" ]; then
    CODE_SERVER="${HOME}/.local/bin/code-server"
elif command -v code-server &>/dev/null; then
    CODE_SERVER="$(command -v code-server)"
else
    echo "❌ 錯誤: 找不到 code-server 執行檔 (~/.local/bin/code-server)！"
    exit 1
fi

# ------------------------------------------------------------------------------
# 3. 檢查或生成個人密碼檔
# ------------------------------------------------------------------------------
if [ ! -f "${PASSWORD_FILE}" ]; then
    tr -dc A-Za-z0-9 </dev/urandom | head -c 14 > "${PASSWORD_FILE}" || true
    echo "⚠️ 尚未偵測到密碼檔，已自動生成安全密碼於: ${PASSWORD_FILE}"
fi
chmod 600 "${PASSWORD_FILE}"

# ------------------------------------------------------------------------------
# 4. 取得連接埠與主機名稱
# ------------------------------------------------------------------------------
free_port() { python3 -c "import socket; s=socket.socket(); s.bind(('',0)); print(s.getsockname()[1]); s.close()"; }
PORT=$(free_port)
MY_HOSTNAME=$(hostname -s)

# 若從 code-server 內建終端機執行，需清除這些變數，
# 否則新的 code-server 會誤判自己是 CLI client 而立即結束
# 密碼在 tmux 內才從檔案讀入，不出現在指令參數中 (避免同節點其他使用者以 ps 看到)
CLEAN_ENV="export PASSWORD=\"\$(tr -d '\\r\\n' < '${PASSWORD_FILE}')\"; exec env -u VSCODE_IPC_HOOK_CLI -u VSCODE_GIT_IPC_HANDLE -u VSCODE_PROXY_URI -u GIT_ASKPASS -u BROWSER"

# ------------------------------------------------------------------------------
# 5. 依模式組裝啟動指令
# ------------------------------------------------------------------------------
if [ "${MODE}" = "local" ]; then
    # localhost 模式: code-server 直接監聽 (綁 0.0.0.0，讓 SSH 通道從任一登入節點都能轉進來)
    CHECK_URL="http://127.0.0.1:${PORT}/login"
    tmux new-session -d -s "${SESSION_NAME}" -n server \
        "${CLEAN_ENV} '${CODE_SERVER}' --bind-addr '0.0.0.0:${PORT}' --auth password --cert false '${HOME}'"
else
    # remote 模式: Nano4 OOD 只有 /node (前綴原封不動轉發)，code-server 無 base-path 參數，
    # 因此 code-server 只綁 127.0.0.1，由 strip_prefix_proxy.cjs 去掉前綴後對外
    PROXY_JS="${SCRIPT_DIR}/lib/strip_prefix_proxy.cjs"
    NODE_BIN="$(dirname "$(readlink -f "${CODE_SERVER}")")/../lib/node"
    [ -x "${NODE_BIN}" ] || NODE_BIN="$(command -v node || true)"
    if [ ! -f "${PROXY_JS}" ] || [ -z "${NODE_BIN}" ]; then
        echo "❌ 錯誤: 找不到 ${PROXY_JS} 或 node 執行檔！"
        exit 1
    fi
    BACKEND_PORT=$(free_port)
    PREFIX="/node/${MY_HOSTNAME}/${PORT}"
    CHECK_URL="http://127.0.0.1:${PORT}${PREFIX}/login"
    tmux new-session -d -s "${SESSION_NAME}" -n server \
        "${CLEAN_ENV} '${CODE_SERVER}' --bind-addr '127.0.0.1:${BACKEND_PORT}' --auth password --cert false '${HOME}'"
    tmux new-window -t "${SESSION_NAME}" -n proxy \
        "'${NODE_BIN}' '${PROXY_JS}' '${PORT}' '${BACKEND_PORT}' '${PREFIX}'"
fi

# 監看停止請求: 讓 stop.sh 從任何一台登入節點都能關閉本服務
tmux new-window -d -t "${SESSION_NAME}" -n watch \
    "while sleep 3; do [ -f '${STOP_FILE}' ] && { rm -f '${STOP_FILE}' '${STATE_FILE}' '${INFO_FILE}'; tmux kill-session -t '${SESSION_NAME}'; }; done"

# ------------------------------------------------------------------------------
# 6. 健康檢查: 登入頁需回應 200 (最多約 20 秒)
# ------------------------------------------------------------------------------
code="000"
for _ in $(seq 1 20); do
    code=$(curl -s -o /dev/null -w "%{http_code}" "${CHECK_URL}" || true)
    [ "${code}" = "200" ] && break
    sleep 1
done
if [ "${code}" != "200" ]; then
    echo "❌ 啟動失敗: ${CHECK_URL} 回應 HTTP ${code}"
    echo "   日誌: tmux capture-pane -p -t ${SESSION_NAME}:server"
    tmux kill-session -t "${SESSION_NAME}" 2>/dev/null || true
    exit 1
fi

# ------------------------------------------------------------------------------
# 7. 輸出並保存連線資訊
# ------------------------------------------------------------------------------
{
    echo "========================================================"
    echo "🎉 code-server 已於背景 (tmux: ${SESSION_NAME}) 啟動！"
    echo "========================================================"
    echo "模式           : ${MODE}"
    echo "登入節點       : ${MY_HOSTNAME}"
    echo "服務連接埠     : ${PORT}"
    [ "${MODE}" = "remote" ] && echo "後端 (本機)    : 127.0.0.1:${BACKEND_PORT} (經 strip_prefix_proxy.cjs 轉發)"
    echo "登入密碼       : 見 ${PASSWORD_FILE} (查看: cat ${PASSWORD_FILE})"
    echo "code-server    : $("${CODE_SERVER}" --version | head -n 1 | cut -d' ' -f1)"
    echo "--------------------------------------------------------"
    if [ "${MODE}" = "local" ]; then
        echo "① 在「您的電腦」開終端機 (Windows PowerShell / Mac Terminal) 建立 SSH 通道，視窗保持開啟:"
        echo "   ssh -N -L ${LOCAL_PORT}:${MY_HOSTNAME}:${PORT} ${USER}@${SSH_HOST}"
        echo ""
        echo "② 瀏覽器開啟:"
        echo "👉 http://localhost:${LOCAL_PORT}/?folder=${HOME}"
        echo ""
        echo "   (若電腦上 ${LOCAL_PORT} 已被占用，把兩處的 ${LOCAL_PORT} 換成其他數字即可)"
    else
        echo "① 先在瀏覽器登入 https://${OOD_HOST} (SSO + OTP)"
        echo "② 同一瀏覽器開啟:"
        echo "👉 https://${OOD_HOST}${PREFIX}/?folder=${HOME}"
        echo ""
        echo "   ⚠️ ${OOD_HOST} 憑證過期期間，webview (ChatGPT 面板、Markdown 預覽) 會無法載入；"
        echo "      編輯器與終端機可正常使用。憑證更新後即恢復，或改用 ./start.sh 1"
    fi
    echo "--------------------------------------------------------"
    echo "查看狀態 : ./start.sh status"
    echo "查看日誌 : tmux attach -t ${SESSION_NAME}  (離開按 Ctrl+B 後按 D)"
    echo "關閉服務 : ./stop.sh"
    echo "========================================================"
} | tee "${INFO_FILE}"
chmod 600 "${INFO_FILE}"
printf 'HOST=%s\nPORT=%s\nMODE=%s\nCHECK_PATH=%s\n' \
    "${MY_HOSTNAME}" "${PORT}" "${MODE}" "${CHECK_URL#http://127.0.0.1:${PORT}}" > "${STATE_FILE}"
chmod 600 "${STATE_FILE}"
