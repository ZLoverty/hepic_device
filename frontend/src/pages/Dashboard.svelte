<script>
  import LineChart      from '../components/LineChart.svelte';
  import QcHistoryList  from '../components/QcHistoryList.svelte';
  import { api } from '../lib/api.js';
  import { sensorData, forceHistory, qcHistory } from '../lib/stores.js';

  $: force    = $sensorData.extrusion_force_N;
  $: feedrate = $sensorData.measured_feedrate_mms;
  $: temp     = $sensorData.hotend_temperature;
  $: target   = $sensorData.target_temperature;
  $: tempDisplay = (temp !== null && temp !== undefined && isFinite(temp)) ? Math.round(temp) : '--';
  $: tgtDisplay  = (target !== null && target !== undefined && isFinite(target)) ? Math.round(target) : '--';
  $: forceDisplay = (force !== null && force !== undefined && isFinite(force)) ? Number(force).toFixed(2) : '---';
  $: feedDisplay  = (feedrate !== null && feedrate !== undefined && isFinite(feedrate)) ? Number(feedrate).toFixed(1) : '---';

  // Firmware enters "shutdown" after an emergency stop and stays unresponsive
  // until FIRMWARE_RESTART — same condition the App-level banner uses to show
  // its restart button, so extrude/retract/estop just disable rather than
  // duplicating restart logic locally.
  $: stopped = $sensorData.klippy_state === 'shutdown' || $sensorData.klippy_state === 'error';

  // Fixed extrusion speed: 3 mm/s, 5 mm per batch ≈ 1.67 s per batch.
  // Interval is 100 ms shorter than execution time so batches chain without gaps.
  const SPEED_MMS = 3;
  const BATCH_MM  = 5;
  const BATCH_MS  = Math.floor(BATCH_MM / SPEED_MMS * 1000) - 100; // 1567 ms

  let holdTimer = null;

  // ── Numpad state ──────────────────────────────────────────────────
  let numpadOpen  = false;
  let numpadInput = '';
  // True until the first keypress after opening: lets a digit overwrite the
  // prefilled default instead of appending to it, without touching normal
  // append/backspace behavior on every keypress after that.
  let numpadFresh = false;

  function openNumpad() {
    numpadInput = (target !== null && target !== undefined) ? String(Math.round(target)) : '200';
    numpadFresh = true;
    numpadOpen  = true;
  }

  function numpadKey(k) {
    if (k === '⌫') {
      numpadInput = numpadInput.slice(0, -1);
    } else if (numpadFresh) {
      numpadInput = k;
    } else if (numpadInput.length < 3) {
      numpadInput += k;
    }
    numpadFresh = false;
  }

  function confirmTemp() {
    const v = parseInt(numpadInput, 10);
    if (!isNaN(v) && v >= 20 && v <= 320) {
      api.klipper.setTemp(v).catch(console.error);
    }
    numpadOpen = false;
  }

  // ── Long-press extrude / retract ──────────────────────────────────
  function startHold(dir) {
    if (stopped) return;
    const f    = (SPEED_MMS * 60).toFixed(0);
    const send = () =>
      api.klipper.gcode(`M83\nG1 E${dir * BATCH_MM} F${f}\nM82`).catch(console.error);
    send();
    holdTimer = setInterval(send, BATCH_MS);
  }

  function endHold() {
    if (holdTimer !== null) {
      clearInterval(holdTimer);
      holdTimer = null;
    }
  }

  // ── Emergency stop (armed with a confirm step to guard against mis-taps,
  // since it now sits far from the normal controls specifically to be
  // deliberate rather than quick) ─────────────────────────────────────
  let estopConfirmOpen = false;

  async function confirmEstop() {
    estopConfirmOpen = false;
    endHold();
    await api.klipper.emergencyStop().catch(console.error);
  }
</script>

<div class="layout">
  <!-- Top bar: live values on the left, e-stop isolated on the right -->
  <div class="topbar">
    <div class="tb-group">
      <div class="tb-stat">
        <span class="tb-stat-label">进线速度</span>
        <span class="tb-stat-val">{feedDisplay}<span class="tb-unit">mm/s</span></span>
      </div>
      <div class="tb-stat">
        <span class="tb-stat-label">挤出力</span>
        <span class="tb-stat-val">{forceDisplay}<span class="tb-unit">N</span></span>
      </div>
    </div>

    <button class="estop" disabled={stopped} on:click={() => (estopConfirmOpen = true)}>
      急&nbsp;停
    </button>
  </div>

  <div class="main">
    <!-- Left: QC history -->
    <div class="side">
      <QcHistoryList records={$qcHistory} />
    </div>

    <!-- Middle: extrude/retract + temp, stacked top to bottom -->
    <div class="controls-col">
      <button class="dir retract" disabled={stopped}
        aria-label="回抽"
        on:pointerdown={() => startHold(-1)}
        on:pointerup={endHold}
        on:pointercancel={endHold}>
        <svg viewBox="0 0 24 24"><polygon points="12,5 20,17 4,17"/></svg>
      </button>
      <button class="dir extrude" disabled={stopped}
        aria-label="挤出"
        on:pointerdown={() => startHold(1)}
        on:pointerup={endHold}
        on:pointercancel={endHold}>
        <svg viewBox="0 0 24 24"><polygon points="12,19 4,7 20,7"/></svg>
      </button>
      <button class="temp-card" on:click={openNumpad}>
        <div class="temp-row">
          <span class="temp-cur">{tempDisplay}</span><span class="temp-sep">/</span><span
            class="temp-tgt">{tgtDisplay}</span><span class="temp-unit">°C</span>
        </div>
        <div class="edit-hint">点击设置 ✎</div>
      </button>
    </div>

    <!-- Right: live force sparkline -->
    <div class="chart">
      <LineChart data={$forceHistory} color="#f5a623" title="挤出力历史" unit="N" />
    </div>
  </div>

  <!-- Numpad overlay -->
  {#if numpadOpen}
    <!-- svelte-ignore a11y-click-events-have-key-events -->
    <!-- svelte-ignore a11y-no-static-element-interactions -->
    <div class="overlay" on:click|self={() => (numpadOpen = false)}>
      <div class="numpad">
        <div class="np-display">
          {numpadInput || '0'}<span class="np-unit">°C</span>
        </div>
        <div class="np-grid">
          {#each ['7','8','9','4','5','6','1','2','3','⌫','0','✓'] as k}
            <button
              class="np-key {k === '✓' ? 'np-confirm' : k === '⌫' ? 'np-back' : ''}"
              on:click={() => k === '✓' ? confirmTemp() : numpadKey(k)}>
              {k}
            </button>
          {/each}
        </div>
      </div>
    </div>
  {/if}

  <!-- E-stop confirm overlay -->
  {#if estopConfirmOpen}
    <!-- svelte-ignore a11y-click-events-have-key-events -->
    <!-- svelte-ignore a11y-no-static-element-interactions -->
    <div class="overlay" on:click|self={() => (estopConfirmOpen = false)}>
      <div class="confirm-box">
        <div class="confirm-title">确认急停？</div>
        <div class="confirm-sub">当前挤出/回抽动作将立即停止</div>
        <div class="confirm-actions">
          <button class="confirm-cancel" on:click={() => (estopConfirmOpen = false)}>取消</button>
          <button class="confirm-go" on:click={confirmEstop}>确认急停</button>
        </div>
      </div>
    </div>
  {/if}
</div>

<style>
  .layout {
    position: relative;
    width: 100%;
    height: 100%;
    display: flex;
    flex-direction: column;
  }

  /* ── Top bar: live values on the left, e-stop pinned right ── */
  .topbar {
    flex-shrink: 0;
    height: 46px;
    display: flex;
    align-items: center;
    gap: 14px;
    padding: 0 14px;
    border-bottom: 1px solid #252d48;
  }
  .tb-group {
    display: flex;
    align-items: center;
    gap: 8px;
  }

  .tb-stat, .estop {
    height: 32px;
    border-radius: 16px;
    font-family: system-ui, sans-serif;
  }

  .tb-stat {
    display: flex;
    align-items: center;
    gap: 6px;
    padding: 0 12px;
    background: #1a1f35;
    border: 1px solid #2e3a58;
  }
  .tb-stat-label {
    font-size: 16px;
    letter-spacing: .06em;
    color: #7888b0;
  }
  .tb-stat-val {
    font-size: 16px;
    color: #eef2ff;
    font-family: 'Courier New', Courier, monospace;
  }
  .tb-unit { font-size: 16px; color: #7888b0; margin-left: 2px; }

  .estop {
    margin-left: auto;
    flex-shrink: 0;
    padding: 0 18px;
    background: #22100e;
    border: 1px solid #e5484d;
    color: #e5484d;
    font-size: 14px;
    font-weight: 600;
    letter-spacing: .08em;
    cursor: pointer;
    transition: opacity .1s, background .12s;
  }
  .estop:active:not(:disabled) { background: #e5484d; color: #fff; }
  .estop:disabled { opacity: .35; cursor: not-allowed; }

  /* ── Main: three columns — QC history / controls / force chart ── */
  .main {
    flex: 1;
    min-height: 0;
    display: flex;
  }
  .side {
    width: 270px;
    flex-shrink: 0;
    display: flex;
    flex-direction: column;
    border-right: 1px solid #252d48;
  }
  .chart {
    flex: 1;
    min-width: 0;
    padding: 4px 4px 4px 0;
  }

  /* ── Middle column: retract / extrude / temp, stacked ── */
  .controls-col {
    width: 160px;
    flex-shrink: 0;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 22px;
    padding: 16px 0;
    border-right: 1px solid #252d48;
  }
  .dir {
    width: 84px;
    height: 84px;
    border-radius: 50%;
    background: #232a48;
    border: 2px solid;
    display: flex;
    align-items: center;
    justify-content: center;
    cursor: pointer;
    transition: background .12s, opacity .1s;
  }
  .dir svg { width: 34px; height: 34px; fill: currentColor; }
  .dir:active:not(:disabled) { opacity: .7; }
  .dir:disabled { opacity: .3; cursor: not-allowed; }
  .dir.retract { border-color: #5b8dee; color: #5b8dee; }
  .dir.retract:active:not(:disabled) { background: #1a2442; }
  .dir.extrude { border-color: #26bf6e; color: #26bf6e; }
  .dir.extrude:active:not(:disabled) { background: #1a3a28; }

  .temp-card {
    width: 132px;
    background: #1a1f35;
    border: 2px solid #f97316;
    border-radius: 6px;
    box-shadow: 0 0 0 3px #f973161f, 0 2px 10px #f9731633;
    padding: 8px 10px;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 2px;
    cursor: pointer;
    transition: background .12s, box-shadow .12s;
  }
  .temp-card:active {
    background: #232a48;
    box-shadow: 0 0 0 3px #f9731633, 0 2px 10px #f9731655;
  }
  .temp-row {
    line-height: 1;
    font-family: 'Courier New', Courier, monospace;
  }
  .temp-cur { font-size: 26px; font-weight: 700; color: #f97316; text-shadow: 0 0 20px #f973164d; }
  .temp-sep { font-size: 20px; color: #5a6380; margin: 0 2px; }
  .temp-tgt { font-size: 20px; color: #9aa8cc; }
  .temp-unit { font-size: 13px; color: #7888b0; margin-left: 3px; }
  .edit-hint {
    font-size: 11px;
    color: #f5a623;
    font-family: system-ui, sans-serif;
    letter-spacing: .02em;
  }

  /* ── Numpad / confirm overlay ── */
  .overlay {
    position: absolute;
    inset: 0;
    background: rgba(7, 9, 16, .72);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 10;
  }
  .numpad {
    background: #151b2e;
    border: 1px solid #252d48;
    border-radius: 4px;
    padding: 18px;
    display: flex;
    flex-direction: column;
    gap: 14px;
    width: 290px;
  }
  .np-display {
    font-family: 'Courier New', Courier, monospace;
    font-size: 52px;
    font-weight: 700;
    color: #eef2ff;
    text-align: right;
    padding: 0 6px;
    line-height: 1;
    border-bottom: 1px solid #252d48;
    padding-bottom: 12px;
  }
  .np-unit {
    font-size: 16px;
    color: #5a6380;
    margin-left: 4px;
  }
  .np-grid {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 8px;
  }
  .np-key {
    height: 56px;
    background: #1a1f35;
    border: 1px solid #252d48;
    color: #eef2ff;
    font-size: 22px;
    font-family: 'Courier New', Courier, monospace;
    border-radius: 2px;
    cursor: pointer;
    transition: background .1s;
  }
  .np-key:active  { background: #252d48; }
  .np-back  { color: #e5484d; font-size: 18px; }
  .np-confirm {
    background: #0e2218;
    border-color: #26bf6e55;
    color: #26bf6e;
    font-size: 20px;
  }
  .np-confirm:active { background: #1a3a28; }

  /* ── E-stop confirm ── */
  .confirm-box {
    background: #151b2e;
    border: 1px solid #e5484d;
    border-radius: 4px;
    padding: 22px;
    display: flex;
    flex-direction: column;
    gap: 14px;
    width: 300px;
  }
  .confirm-title {
    font-size: 20px;
    font-weight: 700;
    color: #e5484d;
    font-family: system-ui, sans-serif;
  }
  .confirm-sub {
    font-size: 13px;
    color: #9aa8cc;
    font-family: system-ui, sans-serif;
  }
  .confirm-actions {
    display: flex;
    gap: 10px;
    margin-top: 6px;
  }
  .confirm-cancel, .confirm-go {
    flex: 1;
    height: 46px;
    border-radius: 2px;
    font-size: 15px;
    font-weight: 600;
    font-family: system-ui, sans-serif;
    cursor: pointer;
    transition: background .12s;
  }
  .confirm-cancel {
    background: #1a1f35;
    border: 1px solid #2e3a58;
    color: #eef2ff;
  }
  .confirm-cancel:active { background: #232a48; }
  .confirm-go {
    background: #22100e;
    border: 1px solid #e5484d;
    color: #e5484d;
  }
  .confirm-go:active { background: #e5484d; color: #fff; }
</style>
