# Nano4 Code-Server：在國網 Nano4 登入節點使用瀏覽器版 VS Code

在 Nano4 登入節點 (`25a-lgn0X`) 以 tmux 背景啟動 [code-server](https://github.com/coder/code-server)，提供兩種連線模式：

| 模式 | 指令 | 連線方式 | 何時使用 |
| :--- | :--- | :--- | :--- |
| **1. localhost** | `./start.sh 1` | 您的電腦建立 SSH 通道 ➔ `http://localhost:8080/` | **目前建議使用**，所有功能 (含 ChatGPT 面板、Markdown 預覽等 webview) 正常 |
| **2. remote** | `./start.sh 2` | 瀏覽器經 Nano4 OOD ➔ `https://nano4.nchc.org.tw/node/<主機>/<埠>/` | 不想開 SSH 通道時；待 `nano4.nchc.org.tw` 憑證更新後即可完整使用 |

---

## 0. 起手式：第一次使用 (只需做一次)

### 步驟 0-1：前置需求

| 項目 | 說明 |
| :--- | :--- |
| Nano4 帳號 | 可 SSH 登入 `nano4.nchc.org.tw` (密碼 + OTP) |
| 您電腦上的 `ssh` | Windows 10/11 內建 (PowerShell 直接輸入 `ssh`)；Mac / Linux 內建。模式 1 需要 |
| 登入節點的工具 | `tmux`、`curl`、`python3` (Nano4 登入節點皆已內建) |

### 步驟 0-2：SSH 登入 Nano4 並取得本資料夾

```bash
# 在您的電腦 (把 <帳號> 換成您的 Nano4 帳號)
ssh <帳號>@nano4.nchc.org.tw

# 在 Nano4 登入節點：下載本專案
git clone https://github.com/gemini960114/nano4-code-server.git ~/nano4-code-server
cd ~/nano4-code-server
```

### 步驟 0-3：安裝 code-server (免 root)

```bash
./install_code_server.sh            # 安裝最新版至 ~/.local
# ./install_code_server.sh 4.137.0  # 或指定版本
```

輸出範例：

```text
==> 下載並安裝 code-server (最新版) 至 /home/<帳號>/.local ...
...
✅ 安裝完成: 4.138.0 59c988c744a240b05b039f57b856a5312f19d5b1 with Code 1.138.0
   執行檔: /home/<帳號>/.local/bin/code-server
```

說明：
* 使用 code-server 官方安裝腳本的 **standalone** 模式，把官方 release (內含自己的 Node.js) 解壓到 `~/.local/lib/code-server-<版本>/`，並在 `~/.local/bin/code-server` 建立連結。
* **完全不需要 `sudo`**：官方腳本若發現 `~/.local/lib`、`~/.local/bin` 不存在，會改用 `sudo` 建立而失敗；`install_code_server.sh` 會先自行建立這兩個目錄。
* 再次執行即為**升級**；設定、擴充套件存於 `~/.local/share/code-server/` 與 `~/.config/code-server/`，升級不會遺失。
* 移除：`rm -rf ~/.local/lib/code-server-* ~/.local/bin/code-server`

確認安裝：

```bash
~/.local/bin/code-server --version
```

### 步驟 0-4：設定登入密碼

```bash
./password_setup.sh 您的密碼        # 自訂密碼
./password_setup.sh                 # 或自動產生 14 碼隨機密碼 (會顯示在畫面上，請記下)

cat ~/.code-server-password         # 忘記時查看
```

密碼的運作方式：
* 密碼存於 `~/.code-server-password`，權限自動設為 `600` (只有您本人可讀)。
* `start.sh` 啟動時才從檔案讀入，以環境變數 `PASSWORD` 交給 code-server，**不會出現在指令參數中** (同節點其他使用者無法以 `ps` 看到)。
* 若未設定就直接 `./start.sh`，會自動產生一組隨機密碼寫入該檔案。
* **修改密碼後需重新啟動才生效**：`./stop.sh` 再 `./start.sh 1`。
* `~/.config/code-server/config.yaml` 內的 `password:` 與 `bind-addr:` 會被 `start.sh` 的設定覆蓋，**不需要**修改該檔。

> [!WARNING]
> code-server 密碼是唯一的防線，拿到密碼的人等同取得您帳號的 shell。請使用夠長的密碼，不要與 Nano4 登入密碼相同，也不要寫進 Git。

### 步驟 0-5：啟動

完成以上步驟後，進入下一節「快速開始」。

---

## 1. 快速開始

```bash
cd ~/nano4-code-server
./start.sh 1                        # localhost 模式 (建議)；或 ./start.sh 2
```

其他指令：

```bash
./start.sh status                   # 查看目前模式與連線網址
cat ~/.code-server-password         # 查看密碼
tmux attach -t nano4-code-server    # 查看即時日誌 (Ctrl+B 後按 D 離開)
./stop.sh                           # 關閉服務 (切換模式前需先關閉)
```

> 一次只會運行一個實例 (兩個 code-server 共用同一設定目錄會互相衝突)。要從模式 1 換到模式 2，請先 `./stop.sh`。

---

## 2. 模式 1：localhost (SSH 通道)

```text
您的電腦                              Nano4
┌─────────────────────┐   SSH 通道   ┌─────────────────────────────────┐
│ 瀏覽器               │ ═══════════► │ 登入節點 ──► 25a-lgn02:38431     │
│ http://localhost:8080│              │             code-server         │
└─────────────────────┘              └─────────────────────────────────┘
```

`./start.sh 1` 輸出範例：

```text
模式           : local
登入節點       : 25a-lgn02
服務連接埠     : 38431
--------------------------------------------------------
① 在「您的電腦」開終端機 (Windows PowerShell / Mac Terminal) 建立 SSH 通道，視窗保持開啟:
   ssh -N -L 8080:25a-lgn02:38431 <帳號>@nano4.nchc.org.tw

② 瀏覽器開啟:
👉 http://localhost:8080/?folder=/home/<帳號>
```

1. 在**您的電腦**執行輸出中的 `ssh -N -L ...`，輸入密碼與 OTP。畫面沒有任何輸出就是通道已建立，**視窗保持開啟**。
2. 瀏覽器開啟 `http://localhost:8080/?folder=...`，輸入 code-server 密碼。

說明：
* code-server 綁 `0.0.0.0`，因此 SSH 不論落在哪一台登入節點，都能轉進 `25a-lgn02`。
* 瀏覽器視 `http://localhost` 為安全來源，webview 的 Service Worker 可正常註冊，**不受 nano4 憑證過期影響**。
* 不經過 OOD，**不需要 base URL、也不需要 proxy**。
* 電腦上 8080 被占用時，把 `ssh` 指令與網址中的 `8080` 換成其他數字 (或 `LOCAL_PORT=9000 ./start.sh 1`)。

---

## 3. 模式 2：remote (Nano4 OOD `/node` 反向代理)

```text
瀏覽器 ──► https://nano4.nchc.org.tw/node/25a-lgn02/38249/login
              │  OOD /node：路徑前綴「原封不動」轉發
              ▼
        lib/strip_prefix_proxy.cjs  0.0.0.0:38249    ← 去掉 /node/25a-lgn02/38249
              │  /login
              ▼
        code-server                 127.0.0.1:33211  ← 只綁本機
```

`./start.sh 2` 輸出範例：

```text
模式           : remote
登入節點       : 25a-lgn02
服務連接埠     : 38249
後端 (本機)    : 127.0.0.1:33211 (經 strip_prefix_proxy.cjs 轉發)
--------------------------------------------------------
① 先在瀏覽器登入 https://nano4.nchc.org.tw (SSO + OTP)
② 同一瀏覽器開啟:
👉 https://nano4.nchc.org.tw/node/25a-lgn02/38249/?folder=/home/<帳號>
```

### 為什麼需要 `strip_prefix_proxy.cjs`？

| | F1 | Nano4 |
| :--- | :--- | :--- |
| OOD 代理路徑 | `/rnode/<主機>/<埠>/` | 只有 `/node/<主機>/<埠>/` (未設定 `rnode_uri`) |
| 後端收到的路徑 | `/login` (前綴已去掉) | `/node/<主機>/<埠>/login` (前綴保留) |
| 直接跑 code-server | ✅ 正常 | ❌ 連 `/login` 都回 `401 {"error":"Unauthorized"}` |

code-server 4.x **沒有 base URL / base-path 參數**，無法處理 `/node/...` 前綴。`lib/strip_prefix_proxy.cjs` 是約 40 行、零依賴的 Node.js 程式 (使用 code-server 內附的 `node`)，模擬 F1 `/rnode` 的行為：

* HTTP 請求去掉前綴後轉發；後端回傳以 `/` 開頭的重導向會補回前綴。
* WebSocket (編輯器、終端機的即時連線) 原樣轉發，只改寫請求路徑。
* 副檔名 `.cjs`：強制以 CommonJS 執行，即使放在設定了 `"type": "module"` 的專案底下也不受影響。

### ⚠️ 目前的限制：nano4 憑證過期

`*.nchc.org.tw` 憑證已於 **2026-08-10** 到期。瀏覽器不允許在憑證無效的網站註冊 Service Worker (即使按了「繼續前往」)，因此模式 2 會出現：

```text
Error loading webview: Error: Could not register service worker: SecurityError: ...
An SSL certificate error occurred when fetching the script.
```

* **影響範圍**：webview 類功能 (ChatGPT / Codex 面板、Markdown 預覽、Jupyter、部分擴充套件面板)。編輯器、檔案總管、終端機正常。
* **暫時做法**：改用模式 1；或以 Chrome 參數只放行此憑證 (需獨立 profile)：
  ```text
  chrome.exe --user-data-dir=%TEMP%\nano4-chrome --ignore-certificate-errors-spki-list=XapUCS1oelcVxHhSz2Kq2EaCUd++XOiAhv+6an+choo=
  ```
* **根本解法**：國網中心更新憑證後，模式 2 不需任何修改即可完整使用。

---

## 4. 在 code-server 中登入 ChatGPT / Codex 擴充套件

遠端環境下，登入流程最後會導向 `http://localhost:1455/auth/callback?...`，而那是**您電腦**的 localhost，因此會顯示「無法連線」。手動完成的方式：

```bash
CODEX=$(ls -d ~/.local/share/code-server/extensions/openai.chatgpt-*/bin/linux-x86_64/codex | tail -1)

# ① 終端機 A：啟動登入程式 (保持執行)
$CODEX login
#    複製印出的 https://auth.openai.com/... 網址，在您的瀏覽器登入

# ② 瀏覽器停在 http://localhost:1455/auth/callback?code=...&state=... (無法連線，正常)
#    複製整串網址，在 code-server 另開終端機 B 執行 (務必加雙引號):
curl "http://localhost:1455/auth/callback?code=...&state=..."

# ③ 終端機 A 顯示 Successfully logged in 後確認
$CODEX login status        # Logged in using ChatGPT
```

完成後 `Ctrl+Shift+P` ➔ `Reload Window`。

> `codex login --device-auth` 需先在 ChatGPT「Security and login」開啟 Device code sign-in；若設定頁沒有該選項，請使用上述方式。

---

## 5. 檔案結構

```text
nano4-code-server/
├── README.md                    # 本說明
├── install_code_server.sh       # 免 root 安裝 / 升級 code-server 至 ~/.local
├── start.sh                     # 啟動: ./start.sh 1 | 2 | status
├── stop.sh                      # 停止服務 (含 remote 模式的 proxy)
├── password_setup.sh            # 設定 / 重新生成密碼
└── lib/
    └── strip_prefix_proxy.cjs   # remote 模式用: 去掉 OOD /node 前綴的轉發 proxy
```

執行期間產生的檔案：

| 檔案 | 用途 |
| :--- | :--- |
| `~/.code-server-password` | code-server 登入密碼 (權限 600) |
| `~/.nano4-code-server.info` | 目前模式與連線資訊 (`./start.sh status` 讀取) |
| `~/.nano4-code-server.state` | 服務所在節點、埠號 (跨登入節點判斷用) |
| `~/.nano4-code-server.stop` | 停止請求 (由 `stop.sh` 建立，服務端偵測到後自行關閉) |

---

## 6. 安全設計

* **密碼不出現在指令參數中**：`start.sh` 讓 tmux 內的 shell 才從 `~/.code-server-password` 讀入密碼，同節點其他使用者無法用 `ps` 看到。
* **清除 VS Code 環境變數**：從 code-server 內建終端機執行 `start.sh` 時，會繼承 `VSCODE_IPC_HOOK_CLI` 等變數，導致新的 code-server 誤判為 CLI client 而立即結束；啟動時會一併清除。
* **啟動健康檢查**：啟動後實際請求 `/login`，未回應 200 會自動清除 tmux session 並報錯。
* remote 模式下 code-server 只綁 `127.0.0.1`，對外只開放 proxy。
* **跨登入節點管理**：Nano4 有多台登入節點，每次 SSH 可能落在不同台。`start.sh` / `stop.sh` 透過各節點共用的 `$HOME` 記錄服務位置：在其他節點執行 `./start.sh` 不會重複啟動，`./stop.sh` 也能關閉另一台節點上的服務 (服務端的 `watch` 視窗每 3 秒檢查停止請求)。

---

## 7. 常見問題

| 症狀 | 原因與解法 |
| :--- | :--- |
| 瀏覽器顯示 `{"error":"Unauthorized"}` | 經 OOD 連到未加 proxy 的 code-server (舊腳本或手動啟動)。請 `./stop.sh` 後改用 `./start.sh 2` |
| `Error loading webview ... SSL certificate error` | nano4 憑證過期，見第 3 節。改用 `./start.sh 1` |
| 網址被導向 IDExpert / dex 登入頁 | OOD 登入已過期，重新登入 `https://nano4.nchc.org.tw` |
| `/rnode/...` 回 404 | Nano4 沒有 `/rnode`，請使用 `/node/...` |
| SSH 通道建立後瀏覽器連不上 | 確認 `ssh -N -L` 視窗仍開著，且 `./start.sh status` 顯示的主機與埠號與 `ssh` 指令一致 (每次啟動埠號都會不同) |
| `bind: Address already in use` (本機) | 電腦上 8080 被占用，換一個埠號 |
| 修改密碼後仍要用舊密碼 | 密碼只在啟動時讀取，請 `./stop.sh` 再 `./start.sh` |
| 今天 SSH 落在不同登入節點，找不到服務 | 直接執行 `./start.sh status`，會顯示服務所在節點與連線方式；連線方式不變，不需重新啟動 |
| `找不到 code-server 執行檔` | 尚未安裝，執行 `./install_code_server.sh` |
| 安裝時要求 `sudo` 密碼 | 請改用 `./install_code_server.sh` (會先建立 `~/.local/lib`、`~/.local/bin`)，不要直接執行官方指令 |
