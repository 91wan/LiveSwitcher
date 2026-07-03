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
      <main class="remote-shell">
        <header class="hero">
          <div>
            <p class="eyebrow">LiveSwitcher</p>
            <h1>手机遥控</h1>
          </div>
          <p id="connection-state" class="status-chip">连接中</p>
        </header>

        <section id="reconnect-banner" class="reconnect-banner" hidden>
          重新连接中，请确认手机仍在同一局域网。
        </section>

        <section id="read-only-banner" class="reconnect-banner" hidden>
          已有手机正在控制，本机只读
        </section>

        <section id="snapshot" class="snapshot-grid" aria-live="polite">
          <article class="snapshot-card current-card">
            <span class="label">当前节目</span>
            <strong id="current-title">未选中</strong>
            <span id="media-state" class="subtle">媒体未播放</span>
          </article>
          <article class="snapshot-card">
            <span class="label">下一节目</span>
            <strong id="next-title">无下一项</strong>
            <span id="broadcast-state" class="subtle">未直播</span>
          </article>
          <article class="snapshot-card">
            <span class="label">BGM</span>
            <strong id="bgm-title">未选择</strong>
            <span id="bgm-state" class="subtle">未播放</span>
          </article>
          <article class="snapshot-card">
            <span class="label">状态</span>
            <strong id="blackout-state">正常</strong>
            <span id="speaker-state" class="subtle">主讲人模式关闭</span>
          </article>
        </section>

        <p id="disabled-reason" class="disabled-reason" hidden></p>
        <p id="command-status" class="command-status" role="status">最近命令：待命</p>

        <section class="control-section" aria-label="节目控制">
          <button class="command-button primary" data-command="takeNext">
            <span>切下一项</span>
            <small>执行当前待播节目</small>
          </button>
        </section>

        <section class="control-grid" aria-label="媒体与 BGM 控制">
          <button class="command-button" data-command="toggleCurrentMediaPlayback">
            <span>播放/暂停</span>
            <small>当前媒体</small>
          </button>
          <button class="command-button" data-command="returnCurrentMediaToStart">
            <span>回到开头</span>
            <small>当前媒体</small>
          </button>
          <button class="command-button" data-command="selectPreviousBGM">
            <span>上一首</span>
            <small>BGM</small>
          </button>
          <button class="command-button" data-command="toggleBGMPlayback">
            <span>BGM 播放</span>
            <small>播放/暂停</small>
          </button>
          <button class="command-button" data-command="selectNextBGM">
            <span>下一首</span>
            <small>BGM</small>
          </button>
          <button class="command-button" data-command="toggleSpeakerMode">
            <span>主讲人</span>
            <small>模式切换</small>
          </button>
        </section>

        <section class="danger-zone" aria-label="危险控制">
          <button
            class="command-button danger"
            data-command="toggleFadeToBlack"
            data-dangerous="true"
            data-hold-ms="1200"
          >
            <span>长按切黑</span>
            <small>按住直到确认</small>
          </button>
          <button
            class="command-button danger panic"
            data-command="togglePanic"
            data-dangerous="true"
            data-hold-ms="1200"
          >
            <span>长按紧急切黑</span>
            <small>按住直到确认</small>
          </button>
        </section>
      </main>
      <script src="/remote.js"></script>
    </body>
    </html>
    """

    static let css = """
    :root {
      color-scheme: dark;
      font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", sans-serif;
      background: #0f1218;
      color: #f8fafc;
      -webkit-tap-highlight-color: transparent;
    }

    * {
      box-sizing: border-box;
    }

    body {
      margin: 0;
      min-height: 100vh;
      background: linear-gradient(180deg, #171b24 0%, #0f1218 100%);
    }

    button {
      font: inherit;
    }

    .remote-shell {
      width: min(100%, 560px);
      min-height: 100vh;
      margin: 0 auto;
      display: grid;
      gap: 16px;
      padding: max(20px, env(safe-area-inset-top)) 16px max(24px, env(safe-area-inset-bottom));
    }

    .hero {
      display: flex;
      align-items: flex-start;
      justify-content: space-between;
      gap: 16px;
      padding-top: 4px;
    }

    .eyebrow,
    .label,
    .subtle,
    .command-button small {
      color: #a9b4c8;
    }

    .eyebrow {
      margin: 0 0 4px;
      font-size: 0.78rem;
      font-weight: 800;
      letter-spacing: 0;
      text-transform: uppercase;
    }

    h1 {
      margin: 0;
      font-size: clamp(2rem, 11vw, 3rem);
      line-height: 0.96;
      letter-spacing: 0;
    }

    .status-chip {
      margin: 0;
      min-width: 88px;
      padding: 10px 12px;
      border: 1px solid rgba(149, 164, 190, 0.24);
      border-radius: 999px;
      background: rgba(255, 255, 255, 0.08);
      color: #dbeafe;
      font-size: 0.92rem;
      font-weight: 800;
      text-align: center;
    }

    .reconnect-banner,
    .disabled-reason,
    .command-status {
      border: 1px solid rgba(250, 204, 21, 0.38);
      border-radius: 16px;
      padding: 12px 14px;
      background: rgba(113, 63, 18, 0.44);
      color: #fde68a;
      font-weight: 800;
    }

    .command-status {
      margin: 0;
      border-color: rgba(96, 165, 250, 0.34);
      background: rgba(30, 50, 74, 0.58);
      color: #bfdbfe;
      font-size: 0.95rem;
    }

    .command-status.is-error {
      border-color: rgba(248, 113, 113, 0.5);
      background: rgba(69, 26, 26, 0.58);
      color: #fecaca;
    }

    .reconnect-banner[hidden],
    .disabled-reason[hidden] {
      display: none;
    }

    .snapshot-grid {
      display: grid;
      grid-template-columns: repeat(2, minmax(0, 1fr));
      gap: 10px;
    }

    .snapshot-card {
      min-height: 112px;
      display: grid;
      align-content: space-between;
      gap: 8px;
      border: 1px solid rgba(149, 164, 190, 0.2);
      border-radius: 18px;
      padding: 14px;
      background: rgba(25, 32, 44, 0.78);
      box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.05);
    }

    .current-card {
      border-color: rgba(96, 165, 250, 0.48);
      background: rgba(30, 50, 74, 0.9);
    }

    .snapshot-card strong {
      min-width: 0;
      overflow-wrap: anywhere;
      font-size: 1.15rem;
      line-height: 1.15;
    }

    .label,
    .subtle,
    .command-button small {
      font-size: 0.82rem;
      font-weight: 760;
      letter-spacing: 0;
    }

    .control-section,
    .control-grid,
    .danger-zone {
      display: grid;
      gap: 10px;
    }

    .control-grid,
    .danger-zone {
      grid-template-columns: repeat(2, minmax(0, 1fr));
    }

    .command-button {
      min-height: 64px;
      display: grid;
      align-content: center;
      gap: 4px;
      border: 1px solid rgba(117, 138, 171, 0.3);
      border-radius: 18px;
      padding: 14px;
      background: #263244;
      color: #f8fafc;
      text-align: left;
      touch-action: manipulation;
      user-select: none;
      -webkit-user-select: none;
    }

    .command-button span {
      font-size: 1.05rem;
      font-weight: 850;
      line-height: 1.1;
      overflow-wrap: anywhere;
    }

    .command-button.primary {
      min-height: 76px;
      background: linear-gradient(135deg, #2f88ff 0%, #55b8ff 100%);
      border-color: rgba(147, 197, 253, 0.7);
      color: white;
    }

    .command-button.primary small {
      color: rgba(255, 255, 255, 0.78);
    }

    .command-button.danger {
      background: #3a2426;
      border-color: rgba(248, 113, 113, 0.54);
    }

    .command-button.panic {
      background: #402326;
    }

    .command-button.is-holding {
      outline: 3px solid rgba(248, 113, 113, 0.45);
      outline-offset: 2px;
    }

    .command-button:disabled {
      opacity: 0.44;
      filter: grayscale(0.2);
    }

    .command-button:not(:disabled):active {
      transform: translateY(1px);
    }

    @media (max-width: 360px) {
      .snapshot-grid,
      .control-grid,
      .danger-zone {
        grid-template-columns: 1fr;
      }
    }
    """

    static let javascript = """
    const token = new URLSearchParams(location.hash.slice(1)).get("token") || "";
    const clientIDStorageKey = "LiveSwitcher.remote.controllerClientID";
    const clientID = storedClientID();
    let clientRole = "pending";
    let claimPromise = null;
    const commandButtons = Array.from(document.querySelectorAll("[data-command]"));
    const reconnectBanner = document.querySelector("#reconnect-banner");
    const readOnlyBanner = document.querySelector("#read-only-banner");
    const connectionState = document.querySelector("#connection-state");
    const disabledReason = document.querySelector("#disabled-reason");
    const commandStatus = document.querySelector("#command-status");
    let latestSnapshot = null;
    const commandLabels = {
      takeNext: "切下一项",
      toggleCurrentMediaPlayback: "播放/暂停",
      returnCurrentMediaToStart: "回到开头",
      toggleBGMPlayback: "BGM 播放/暂停",
      selectPreviousBGM: "上一首",
      selectNextBGM: "下一首",
      toggleSpeakerMode: "主讲人模式",
      toggleFadeToBlack: "切黑",
      togglePanic: "紧急切黑"
    };

    function storedClientID() {
      try {
        const existing = sessionStorage.getItem(clientIDStorageKey);
        if (existing) {
          return existing;
        }
        const value = commandID();
        sessionStorage.setItem(clientIDStorageKey, value);
        return value;
      } catch (error) {
        return commandID();
      }
    }

    function headers(contentType) {
      const value = { Authorization: `Bearer ${token}` };
      value["X-Remote-Client-ID"] = clientID;
      if (contentType) {
        value["Content-Type"] = contentType;
      }
      return value;
    }

    function setText(id, value) {
      const element = document.querySelector(`#${id}`);
      if (element) {
        element.textContent = value;
      }
    }

    function setCommandStatus(message, isError = false) {
      commandStatus.textContent = message;
      commandStatus.classList.toggle("is-error", isError);
    }

    function commandLabel(kind) {
      return commandLabels[kind] || "命令";
    }

    function safeErrorCopy(errorCode) {
      switch (errorCode) {
      case "clientNotController":
      case "missingControllerClientID":
        return "只读连接，不能控制";
      case "networkDisconnected":
        return "网络断开";
      default:
        return errorCode;
      }
    }

    function commandPendingCopy(kind) {
      return `${commandLabel(kind)} 发送中`;
    }

    function commandSuccessCopy(kind, data = latestSnapshot) {
      if (kind === "toggleCurrentMediaPlayback" && data) {
        return data.isCurrentMediaPlaying ? "媒体暂停 已执行" : "媒体播放 已执行";
      }
      if (kind === "toggleBGMPlayback" && data) {
        return data.isBGMPlaying ? "BGM 暂停 已执行" : "BGM 播放 已执行";
      }
      if (kind === "toggleSpeakerMode" && data) {
        return data.isSpeakerMode ? "主讲人模式 已关" : "主讲人模式 已开";
      }
      if (kind === "toggleFadeToBlack" && data) {
        return data.isFadeToBlackActive ? "切黑 已解除" : "切黑 已开启";
      }
      if (kind === "togglePanic" && data) {
        return data.isPanicActive ? "紧急切黑 已解除" : "紧急切黑 已开启";
      }
      return `${commandLabel(kind)} 已执行`;
    }

    function commandFailureCopy(kind, errorCode) {
      return `${commandLabel(kind)} 失败：${safeErrorCopy(errorCode)}`;
    }

    function uuidV4() {
      if (window.crypto && crypto.randomUUID) {
        return crypto.randomUUID();
      }

      const bytes = new Uint8Array(16);
      if (window.crypto && crypto.getRandomValues) {
        crypto.getRandomValues(bytes);
      } else {
        for (let index = 0; index < bytes.length; index += 1) {
          bytes[index] = Math.floor(Math.random() * 256);
        }
      }

      bytes[6] = (bytes[6] & 0x0f) | 0x40;
      bytes[8] = (bytes[8] & 0x3f) | 0x80;
      const hex = Array.from(bytes, (byte) => byte.toString(16).padStart(2, "0"));
      return `${hex[0]}${hex[1]}${hex[2]}${hex[3]}-${hex[4]}${hex[5]}-${hex[6]}${hex[7]}-${hex[8]}${hex[9]}-${hex[10]}${hex[11]}${hex[12]}${hex[13]}${hex[14]}${hex[15]}`;
    }

    function commandID() {
      return uuidV4();
    }

    function connectionCopy(state) {
      switch (state) {
      case "connected":
        return "已连接";
      case "enabled":
        return "等待连接";
      case "readOnly":
        return "只读连接";
      default:
        return "未连接";
      }
    }

    function blackoutCopy(data) {
      if (data.isPanicActive) {
        return "紧急切黑";
      }
      if (data.isFadeToBlackActive) {
        return "切黑中";
      }
      return "正常";
    }

    function setReconnect(visible) {
      reconnectBanner.hidden = !visible;
    }

    async function claimSession() {
      if (!token || clientRole !== "pending") {
        return;
      }
      if (claimPromise) {
        return claimPromise;
      }

      claimPromise = fetch("/api/session/claim", {
        method: "POST",
        headers: headers("application/json"),
        body: JSON.stringify({ clientID })
      })
        .then(async (response) => {
          const payload = await response.json().catch(() => ({}));
          if (response.status === 409 && payload.role === "readOnly") {
            clientRole = "readOnly";
            readOnlyBanner.hidden = false;
            return;
          }
          if (!response.ok) {
            throw new Error("session claim failed");
          }
          clientRole = payload.role || "controller";
          readOnlyBanner.hidden = clientRole !== "readOnly";
        })
        .finally(() => {
          claimPromise = null;
        });
      return claimPromise;
    }

    function updateButtonStates(data, online) {
      const disabledByCommand = {
        takeNext: !data || !data.nextProgramTitle,
        toggleCurrentMediaPlayback: !data || !data.canToggleCurrentMedia,
        returnCurrentMediaToStart: !data || !data.canReturnCurrentMediaToStart,
        toggleBGMPlayback: !data || (!data.currentBGMTitle && !data.canSelectPreviousBGM && !data.canSelectNextBGM),
        selectPreviousBGM: !data || !data.canSelectPreviousBGM,
        selectNextBGM: !data || !data.canSelectNextBGM,
        toggleSpeakerMode: !data,
        toggleFadeToBlack: !data,
        togglePanic: !data
      };

      commandButtons.forEach((button) => {
        const command = button.dataset.command;
        button.disabled = clientRole !== "controller" || !token || !online || Boolean(data?.disabledReason) || Boolean(disabledByCommand[command]);
      });
    }

    function renderSnapshot(data) {
      latestSnapshot = data;
      connectionState.textContent = clientRole === "readOnly" ? "只读连接" : connectionCopy(data.connectionState);
      setText("current-title", data.currentProgramTitle || "未选中");
      setText("next-title", data.nextProgramTitle || "无下一项");
      setText("bgm-title", data.currentBGMTitle || "未选择");
      setText("media-state", data.isCurrentMediaPlaying ? "媒体播放中" : "媒体已暂停");
      setText("broadcast-state", data.isBroadcasting ? "正在直播" : "未直播");
      setText("bgm-state", data.isBGMPlaying ? "BGM 播放中" : "BGM 已暂停");
      setText("blackout-state", blackoutCopy(data));
      setText("speaker-state", data.isSpeakerMode ? "主讲人模式开启" : "主讲人模式关闭");
      const reason = clientRole === "readOnly" ? "已有手机正在控制，本机只读" : (data.disabledReason || "");
      disabledReason.hidden = !reason;
      disabledReason.textContent = reason;
      updateButtonStates(data, true);
      setReconnect(false);
    }

    async function refreshSnapshot() {
      if (!token) {
        connectionState.textContent = "缺少 token";
        setReconnect(true);
        updateButtonStates(null, false);
        return;
      }

      try {
        await claimSession();
        const response = await fetch("/api/snapshot", { headers: headers() });
        if (!response.ok) {
          throw new Error("snapshot failed");
        }
        renderSnapshot(await response.json());
      } catch (error) {
        connectionState.textContent = "连接断开";
        setReconnect(true);
        updateButtonStates(null, false);
      }
    }

    async function sendCommand(kind, confirmation) {
      await claimSession();
      if (clientRole !== "controller") {
        readOnlyBanner.hidden = false;
        setCommandStatus(commandFailureCopy(kind, "clientNotController"), true);
        updateButtonStates(null, false);
        return;
      }

      const payload = { id: commandID(), kind };
      if (confirmation) {
        payload.confirmation = confirmation;
      }

      setCommandStatus(commandPendingCopy(kind));
      let response;
      try {
        response = await fetch("/api/command", {
          method: "POST",
          headers: headers("application/json"),
          body: JSON.stringify(payload)
        });
      } catch (error) {
        setCommandStatus(commandFailureCopy(kind, "networkDisconnected"), true);
        setReconnect(true);
        return;
      }

      if (!response.ok) {
        const payload = await response.json().catch(() => ({}));
        const errorCode = payload.error || "unknown";
        setCommandStatus(commandFailureCopy(kind, errorCode), true);
        if (errorCode === "clientNotController" || errorCode === "missingControllerClientID") {
          readOnlyBanner.hidden = false;
        }
        return;
      }
      setCommandStatus(commandSuccessCopy(kind));
      await refreshSnapshot();
    }

    async function issueDangerConfirmation(kind) {
      await claimSession();
      if (clientRole !== "controller") {
        readOnlyBanner.hidden = false;
        setCommandStatus(commandFailureCopy(kind, "clientNotController"), true);
        throw new Error("client is read only");
      }

      let response;
      try {
        response = await fetch("/api/danger-confirmation", {
          method: "POST",
          headers: headers("application/json"),
          body: JSON.stringify({ kind })
        });
      } catch (error) {
        setCommandStatus(commandFailureCopy(kind, "networkDisconnected"), true);
        setReconnect(true);
        throw error;
      }
      if (!response.ok) {
        const payload = await response.json().catch(() => ({}));
        const errorCode = payload.error || "unknown";
        setCommandStatus(commandFailureCopy(kind, errorCode), true);
        throw new Error("danger confirmation failed");
      }
      return response.json();
    }

    function activateCommandButton(button, event) {
      event?.preventDefault();
      const lastActivatedAt = Number(button.lastActivatedAt || 0);
      if (Date.now() - lastActivatedAt < 350) {
        return;
      }
      button.lastActivatedAt = Date.now();
      if (!button.disabled) {
        sendCommand(button.dataset.command);
      }
    }

    function clearDangerHold(button) {
      if (button.holdTimer) {
        clearTimeout(button.holdTimer);
      }
      button.holdTimer = null;
      button.holdActive = false;
      button.classList.remove("is-holding");
    }

    function startDangerHold(event) {
      const button = event.currentTarget;
      if (button.disabled) {
        return;
      }
      event.preventDefault();
      clearDangerHold(button);

      const holdMS = Number(button.dataset.holdMs || 1200);
      button.classList.add("is-holding");
      button.holdActive = true;
      button.setPointerCapture?.(event.pointerId);
      const startedAt = Date.now();
      issueDangerConfirmation(button.dataset.command)
        .then((challenge) => {
          if (!button.holdActive) {
            return;
          }
          const serverHoldMS = Number(challenge.minimumHoldDuration || 1) * 1000;
          const requiredHoldMS = Math.max(holdMS, serverHoldMS);
          const elapsedMS = Date.now() - startedAt;
          button.holdTimer = setTimeout(async () => {
            if (!button.holdActive) {
              return;
            }
            try {
              await sendCommand(button.dataset.command, {
                nonce: challenge.nonce
              });
            } catch (error) {
              setReconnect(true);
            } finally {
              clearDangerHold(button);
            }
          }, Math.max(0, requiredHoldMS - elapsedMS));
        })
        .catch(() => {
          setReconnect(true);
          clearDangerHold(button);
        });
    }

    commandButtons.forEach((button) => {
      if (button.dataset.dangerous === "true") {
        button.addEventListener("pointerdown", startDangerHold);
        button.addEventListener("pointerup", () => clearDangerHold(button));
        button.addEventListener("pointercancel", () => clearDangerHold(button));
        button.addEventListener("pointerleave", () => clearDangerHold(button));
        button.addEventListener("click", (event) => event.preventDefault());
        return;
      }

      button.addEventListener("pointerup", (event) => activateCommandButton(button, event));
      button.addEventListener("touchend", (event) => activateCommandButton(button, event));
      button.addEventListener("click", (event) => activateCommandButton(button, event));
    });

    setInterval(refreshSnapshot, 1000);
    refreshSnapshot();
    """
}
