enum RemoteControlStaticPage {
    static let html = """
    <!doctype html>
    <html lang="zh-CN">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <title>LiveSwitcher Remote</title>
      <link rel="stylesheet" href="/remote.css">
    </head>
    <body>
      <main>
        <header>
          <p id="connection">未连接</p>
          <h1>LiveSwitcher Remote</h1>
        </header>
        <section id="snapshot" aria-live="polite"></section>
      </main>
      <script src="/remote.js"></script>
    </body>
    </html>
    """

    static let css = """
    :root {
      color-scheme: dark;
      font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", sans-serif;
      background: #111317;
      color: #f8fafc;
    }

    body {
      margin: 0;
      min-height: 100vh;
      background: #111317;
    }

    main {
      display: grid;
      gap: 16px;
      padding: 20px;
    }

    #snapshot {
      min-height: 72px;
      border: 1px solid #2a3444;
      border-radius: 12px;
      padding: 16px;
      background: #181d25;
    }
    """

    static let javascript = """
    const token = new URLSearchParams(location.hash.slice(1)).get("token") || "";
    const headers = () => ({ Authorization: `Bearer ${token}` });
    const snapshot = document.querySelector("#snapshot");
    const connection = document.querySelector("#connection");

    async function refreshSnapshot() {
      const response = await fetch("/api/snapshot", { headers: headers() });
      if (!response.ok) {
        connection.textContent = "连接已断开";
        return;
      }
      const data = await response.json();
      connection.textContent = data.connectionState || "connected";
      snapshot.textContent = `${data.currentProgramTitle || "未选中"} / ${data.nextProgramTitle || "无下一项"}`;
    }

    setInterval(refreshSnapshot, 1000);
    refreshSnapshot();
    """
}
