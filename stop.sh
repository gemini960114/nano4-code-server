#!/usr/bin/env bash
# ==============================================================================
# stop.sh - 停止 start.sh 啟動的 code-server (含 remote 模式的 proxy)
# 可在任一台登入節點執行：服務若在另一台節點上，會透過共用 $HOME 送出停止請求
# ==============================================================================
set -euo pipefail

SESSION_NAME="nano4-code-server"
INFO_FILE="${HOME}/.nano4-code-server.info"
STATE_FILE="${HOME}/.nano4-code-server.state"
STOP_FILE="${HOME}/.nano4-code-server.stop"

# 1. 服務在本節點
if tmux has-session -t "${SESSION_NAME}" 2>/dev/null; then
    tmux kill-session -t "${SESSION_NAME}"
    rm -f "${INFO_FILE}" "${STATE_FILE}" "${STOP_FILE}"
    echo "✅ '${SESSION_NAME}' 已停止。"
    exit 0
fi

# 2. 服務在其他登入節點
if [ -f "${STATE_FILE}" ]; then
    HOST="$(sed -n 's/^HOST=//p' "${STATE_FILE}")"
    PORT="$(sed -n 's/^PORT=//p' "${STATE_FILE}")"
    CHECK_PATH="$(sed -n 's/^CHECK_PATH=//p' "${STATE_FILE}")"
    alive() { [ "$(curl -s -m 3 -o /dev/null -w '%{http_code}' "http://${HOST}:${PORT}${CHECK_PATH}" || true)" = "200" ]; }

    if [ "${HOST}" != "$(hostname -s)" ] && alive; then
        echo "==> 服務運行於另一台登入節點 ${HOST}，送出停止請求..."
        touch "${STOP_FILE}"
        for _ in $(seq 1 15); do
            sleep 1
            alive || { rm -f "${STOP_FILE}"; echo "✅ ${HOST} 上的 '${SESSION_NAME}' 已停止。"; exit 0; }
        done
        rm -f "${STOP_FILE}"
        echo "❌ ${HOST} 上的服務未回應停止請求，請登入該節點後執行 tmux kill-session -t ${SESSION_NAME}"
        exit 1
    fi
    rm -f "${INFO_FILE}" "${STATE_FILE}"   # 殘留的舊狀態
fi

echo "ℹ️ 目前沒有運行中的 '${SESSION_NAME}' 服務。"
