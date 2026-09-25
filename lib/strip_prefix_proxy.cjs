// strip_prefix_proxy.cjs - 模擬 F1 的 /rnode：去掉 OOD /node/<host>/<port> 前綴後轉給本機 code-server
// 用法: node strip_prefix_proxy.cjs <listen_port> <backend_port> <prefix>
const http = require("http");
const net = require("net");

const [listenPort, backendPort, rawPrefix] = process.argv.slice(2);
const prefix = rawPrefix.replace(/\/+$/, "");

const strip = (url) =>
  url === prefix ? "/" : url.startsWith(prefix + "/") || url.startsWith(prefix + "?")
    ? url.slice(prefix.length).replace(/^\?/, "/?") : url;

const server = http.createServer((req, res) => {
  const up = http.request(
    { host: "127.0.0.1", port: backendPort, method: req.method, path: strip(req.url), headers: req.headers },
    (r) => {
      const h = { ...r.headers };
      // 後端回的絕對路徑重導向要補回前綴
      if (h.location && h.location.startsWith("/") && !h.location.startsWith(prefix + "/")) h.location = prefix + h.location;
      res.writeHead(r.statusCode, h);
      r.pipe(res);
    }
  );
  up.on("error", () => { res.writeHead(502); res.end("backend unavailable"); });
  req.pipe(up);
});

// WebSocket 升級：原樣轉發原始 TCP，只改請求行的路徑
server.on("upgrade", (req, sock, head) => {
  const up = net.connect(backendPort, "127.0.0.1", () => {
    let lines = `${req.method} ${strip(req.url)} HTTP/${req.httpVersion}\r\n`;
    for (let i = 0; i < req.rawHeaders.length; i += 2) lines += `${req.rawHeaders[i]}: ${req.rawHeaders[i + 1]}\r\n`;
    up.write(lines + "\r\n");
    if (head && head.length) up.write(head);
    sock.pipe(up).pipe(sock);
  });
  up.on("error", () => sock.destroy());
  sock.on("error", () => up.destroy());
});

server.listen(listenPort, "0.0.0.0", () => console.log(`proxy 0.0.0.0:${listenPort}${prefix}/ -> 127.0.0.1:${backendPort}/`));
