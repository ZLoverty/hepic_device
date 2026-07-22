<script>
  import { wsConnected } from '../lib/stores.js';
  import { api } from '../lib/api.js';

  let klipperOk  = null;   // null=checking, true=ok, false=error
  let klipperMsg = '';
  let ipAddress  = '检测中...';
  let materialDbVersion = '检测中...';
  let systemName = '检测中...';
  let appVersion = '检测中...';

  async function checkKlipper() {
    klipperOk = null;
    try {
      const s = await api.klipper.status();
      klipperOk  = true;
      klipperMsg = `热端 ${s.hotend_temperature !== null ? Number(s.hotend_temperature).toFixed(1) : '---'} °C`;
    } catch (e) {
      klipperOk  = false;
      klipperMsg = String(e);
    }
  }

  async function loadSystemInfo() {
    try {
      const s = await api.system.info();
      ipAddress = s.ip_address ?? '未知';
      materialDbVersion = s.material_db_version ?? '未知';
      systemName = s.system_name ?? '未知';
      appVersion = s.version ? `v${s.version}` : '未知';
    } catch (e) {
      ipAddress = '获取失败';
      materialDbVersion = '获取失败';
      systemName = '获取失败';
      appVersion = '获取失败';
    }
  }

  // idle | running | done | error
  let updateState = 'idle';
  let updateLog = [];
  let pollTimer = null;

  async function pollUpdateStatus() {
    try {
      const s = await api.system.updateStatus();
      updateLog = s.log;
      if (s.running) {
        updateState = 'running';
      } else if (updateState === 'running') {
        clearInterval(pollTimer);
        pollTimer = null;
        updateState = s.log.some((l) => l.includes('update finished')) ? 'done' : 'error';
      }
    } catch (e) {
      // backend is likely mid-restart right now; keep polling silently
    }
  }

  async function startUpdate() {
    updateState = 'running';
    updateLog = [];
    try {
      await api.system.update();
    } catch (e) {
      // request may not even land if a restart is already underway; the
      // poll loop below will reconcile with reality either way
    }
    if (!pollTimer) pollTimer = setInterval(pollUpdateStatus, 2000);
    pollUpdateStatus();
  }

  checkKlipper();
  loadSystemInfo();
  pollUpdateStatus(); // in case a page refresh landed mid-update
</script>

<div class="layout">
  <div class="section">连接状态</div>

  <div class="row">
    <div class="dot" class:green={$wsConnected} class:red={!$wsConnected}/>
    <span class="name">传感器服务器</span>
    <span class="val" class:ok={$wsConnected} class:bad={!$wsConnected}>
      {$wsConnected ? '已连接' : '未连接'}
    </span>
  </div>

  <div class="row">
    <div
      class="dot"
      class:green={klipperOk === true}
      class:red={klipperOk === false}
      class:amber={klipperOk === null}
    />
    <span class="name">Klipper / Moonraker</span>
    <span class="val" class:ok={klipperOk === true} class:bad={klipperOk === false} class:muted={klipperOk === null}>
      {klipperOk === null ? '检测中...' : klipperOk ? `已连接 · ${klipperMsg}` : '未连接'}
    </span>
    <button class="refresh" on:click={checkKlipper}>刷新</button>
  </div>

  <div class="section" style="margin-top:20px">系统更新</div>
  <div class="update-box">
    <div class="row" style="border:none; padding:0; height:auto;">
      <span class="name">拉取最新代码、重新安装并重启服务</span>
      <button
        class="refresh"
        on:click={startUpdate}
        disabled={updateState === 'running'}
      >
        {updateState === 'running' ? '更新中…' : '检查并更新'}
      </button>
    </div>
    {#if updateState === 'done'}
      <div class="update-msg ok">更新完成</div>
    {:else if updateState === 'error'}
      <div class="update-msg bad">更新失败，请查看下方日志</div>
    {/if}
    {#if updateState !== 'idle'}
      <pre class="update-log">{updateLog.join('\n') || '等待日志…'}</pre>
    {/if}
  </div>

  <div class="section" style="margin-top:20px">关于</div>
  <div class="info">
    <div class="info-row"><span>版本</span><span class="mono">{appVersion}</span></div>
    <div class="info-row"><span>系统</span><span class="mono">{systemName}</span></div>
    <div class="info-row"><span>后端</span><span class="mono">FastAPI + Klipper</span></div>
    <div class="info-row"><span>WiFi IP 地址</span><span class="mono">{ipAddress}</span></div>
    <div class="info-row"><span>材料库版本</span><span class="mono">{materialDbVersion}</span></div>
  </div>
</div>

<style>
  .layout {
    height: 100%;
    padding: 18px 24px;
    color: #dce4f5;
    font-family: system-ui, sans-serif;
    display: flex;
    flex-direction: column;
    gap: 8px;
    overflow-y: auto;
    -webkit-overflow-scrolling: touch;
  }
  .section {
    font-size: 10px;
    letter-spacing: .16em;
    text-transform: uppercase;
    color: #5a6380;
    margin-bottom: 4px;
  }
  .row {
    display: flex;
    align-items: center;
    gap: 10px;
    background: #131623;
    border: 1px solid #1e2235;
    padding: 0 16px;
    height: 56px;
    border-radius: 2px;
  }
  .dot {
    width: 9px; height: 9px;
    border-radius: 50%;
    flex-shrink: 0;
    background: #3d4560;
    transition: background .4s;
  }
  .dot.green { background: #26bf6e; box-shadow: 0 0 8px #26bf6e88; }
  .dot.red   { background: #e5484d; }
  .dot.amber { background: #f5a623; box-shadow: 0 0 8px #f5a62388; }
  .name { flex: 1; font-size: 14px; }
  .val  { font-size: 13px; font-family: 'Courier New', Courier, monospace; }
  .ok   { color: #26bf6e; }
  .bad  { color: #e5484d; }
  .muted{ color: #5a6380; }
  .refresh {
    background: #1e2235;
    border: 1px solid #2e3352;
    color: #dce4f5;
    font-size: 13px;
    padding: 4px 12px;
    border-radius: 2px;
    cursor: pointer;
    height: 32px;
  }
  .refresh:active { background: #2e3352; }
  .refresh:disabled { opacity: .5; cursor: default; }

  .update-box {
    background: #131623;
    border: 1px solid #1e2235;
    padding: 14px 16px;
    border-radius: 2px;
    display: flex;
    flex-direction: column;
    gap: 10px;
  }
  .update-msg { font-size: 13px; }
  .update-log {
    margin: 0;
    max-height: 160px;
    overflow-y: auto;
    background: #0d0f18;
    border: 1px solid #1a1e30;
    border-radius: 2px;
    padding: 8px 10px;
    font-family: 'Courier New', Courier, monospace;
    font-size: 12px;
    color: #8a92b2;
    white-space: pre-wrap;
    word-break: break-all;
  }

  .info {
    background: #131623;
    border: 1px solid #1e2235;
    padding: 4px 16px;
    border-radius: 2px;
  }
  .info-row {
    display: flex;
    justify-content: space-between;
    padding: 10px 0;
    border-bottom: 1px solid #1a1e30;
    font-size: 14px;
    color: #5a6380;
  }
  .info-row:last-child { border-bottom: none; }
  .mono { color: #dce4f5; font-family: 'Courier New', Courier, monospace; }
</style>
