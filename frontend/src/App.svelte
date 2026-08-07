<script>
  import { onMount, onDestroy } from 'svelte';
  import { get } from 'svelte/store';
  import { sensorData, forceHistory, wsConnected, qcState, qcForceHistory, qcHistory } from './lib/stores.js';
  import { evaluateForceWindow } from './lib/forceWindow.js';
  import { createReconnectingWS } from './lib/ws.js';
  import { api } from './lib/api.js';
  import NavBar        from './components/NavBar.svelte';
  import Dashboard     from './pages/Dashboard.svelte';
  import QualityCheck  from './pages/QualityCheck.svelte';
  import Settings      from './pages/Settings.svelte';

  const MAX_HISTORY = 200;
  const pages = [Dashboard, QualityCheck, Settings];
  let activePage = 0;
  let sensorWs = null;
  let qcWs = null;

  // ── Firmware shutdown recovery ──────────────────────────────────────
  // Klipper enters "shutdown" after any emergency stop (e.g. aborting a QC
  // run) and stops responding to gcode until FIRMWARE_RESTART is sent. This
  // banner is mounted at the shell level — above every page — so there's
  // always a touchscreen path back to "ready", regardless of which page
  // triggered the stop.
  $: firmwareDown = $sensorData.klippy_state === 'shutdown' || $sensorData.klippy_state === 'error';
  let restarting = false;

  async function restartFirmware() {
    restarting = true;
    try   { await api.klipper.restart(); }
    catch (e) { console.error(e); }
    finally { restarting = false; }
  }

  // ── QC WebSocket management ───────────────────────────────────────
  // Tracks $qcState.phase; opens/closes the QC stream WS regardless of
  // which page is visible. This keeps the session alive across navigation.
  $: {
    if ($qcState.phase === 'running' && !qcWs) {
      const proto = location.protocol === 'https:' ? 'wss:' : 'ws:';
      qcWs = createReconnectingWS(
        `${proto}//${location.host}/api/qc/stream`,
        { onMessage: handleQcMsg },
      );
    } else if ($qcState.phase !== 'running' && qcWs) {
      qcWs.close();
      qcWs = null;
    }
  }

  function handleQcMsg(msg) {
    const text = msg?.response ?? '';
    const up   = text.toUpperCase();

    if (up.includes('ZERO_SENSORS')) {
      api.klipper.zeroSensors().catch(console.error);
      return;
    }
    if (up.includes('STOP_QUALITY_CHECK')) {
      const { family, piCode } = get(qcState);
      // Same rolling window QualityCheck.svelte uses for the live "frozen"
      // display, so the persisted record always matches what was on screen.
      const forceEval = evaluateForceWindow(get(qcForceHistory));
      const mean_force = forceEval?.mean ?? null;
      const std_force  = forceEval?.std ?? null;
      // Persist to the device's local SQLite history; the store is only
      // updated once the write is confirmed, so the UI reflects what's
      // actually on disk rather than an optimistic guess.
      api.qc.addHistory({ family, pi_code: piCode, mean_force, std_force })
        .then(rec => qcHistory.update(h => [rec, ...h]))
        .catch(console.error);
      qcState.update(s => ({ ...s, phase: 'done', statusMsg: '质检完毕', extrudeStartedAt: null }));
      // The gcode script has no cancel/pause mechanism, so even a normal
      // finish is recovered the same way a mid-run abort is (see PC's
      // on_quality_check_clicked(), which routes both through the same
      // abort_and_recover()): emergency stop then firmware restart.
      api.klipper.abortAndRecover().catch(console.error);
      return;
    }
    if (up.includes('START_QUALITY_CHECK')) {
      qcState.update(s => ({ ...s, statusMsg: '正在挤出', extrudeStartedAt: Date.now() }));
      return;
    }
    const m = text.match(/STATUS\s+(.+)/i);
    if (m) qcState.update(s => ({ ...s, statusMsg: m[1].trim() }));
  }

  // ── QC history: load persisted records on startup ─────────────────
  onMount(() => {
    api.qc.history().then(d => qcHistory.set(d.records ?? [])).catch(console.error);
  });

  // ── Sensor WebSocket ──────────────────────────────────────────────
  onMount(() => {
    const proto = location.protocol === 'https:' ? 'wss:' : 'ws:';
    sensorWs = createReconnectingWS(`${proto}//${location.host}/ws/sensors`, {
      onOpen()  { wsConnected.set(true);  },
      onClose() { wsConnected.set(false); },
      onMessage(data) {
        sensorData.set(data);
        const f = data.extrusion_force_N;
        if (f !== null && f !== undefined && isFinite(f)) {
          forceHistory.update(h => {
            const n = [...h, f];
            return n.length > MAX_HISTORY ? n.slice(-MAX_HISTORY) : n;
          });
          // Accumulate QC-specific history while a session is running.
          // Using get() here is intentional: we need the current phase at
          // callback time without creating a reactive subscription.
          if (get(qcState).phase === 'running') {
            qcForceHistory.update(h => {
              const n = [...h, f];
              return n.length > 300 ? n.slice(-300) : n;  // 30 s window at 10 Hz
            });
          }
        }
      },
    });
  });

  onDestroy(() => {
    sensorWs?.close();
    qcWs?.close();
  });
</script>

<div class="shell">
  {#if firmwareDown}
    <div class="fw-banner">
      <span class="fw-msg">固件已停止（急停后需要重启才能继续）</span>
      <button class="fw-btn" disabled={restarting} on:click={restartFirmware}>
        {restarting ? '重启中...' : '固件重启'}
      </button>
    </div>
  {/if}
  <main class="content">
    <svelte:component this={pages[activePage]} />
  </main>
  <NavBar active={activePage} on:nav={(e) => (activePage = e.detail)} />
</div>

<style>
  :global(*, *::before, *::after) { box-sizing: border-box; margin: 0; padding: 0; }
  :global(html, body) {
    width: 100%; height: 100%;
    overflow: hidden;
    background: #ffffff;
    color: #14161d;
    font-family: system-ui, -apple-system, sans-serif;
    -webkit-tap-highlight-color: transparent;
    user-select: none;
  }
  :global(button) { cursor: pointer; }

  .shell {
    width: 100vw; height: 100vh;
    display: flex;
    flex-direction: column;
    background-color: #ffffff;
  }
  .content { flex: 1; min-height: 0; overflow: hidden; }

  .fw-banner {
    flex-shrink: 0;
    height: 48px;
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 12px;
    padding: 0 14px;
    background: #fdecec;
    border-bottom: 1px solid #dc2f35;
  }
  .fw-msg {
    font-size: 20px;
    color: #dc2f35;
    font-family: system-ui, sans-serif;
  }
  .fw-btn {
    flex-shrink: 0;
    height: 34px;
    padding: 0 14px;
    background: #dc2f35;
    border: none;
    border-radius: 2px;
    color: #fff;
    font-size: 20px;
    font-weight: 600;
    font-family: system-ui, sans-serif;
    letter-spacing: .04em;
  }
  .fw-btn:active:not(:disabled) { background: #b3261e; }
  .fw-btn:disabled { opacity: .5; cursor: default; }
</style>
