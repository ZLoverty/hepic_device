<script>
  export let records = /** @type {{time:number, mean:number|null, std:number|null, family:string|null, piCode:string|null}[]} */ ([]);

  function fmtTime(ms) {
    const d = new Date(ms);
    return `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
  }

  function fmtForce(rec) {
    return (rec.mean !== null && rec.std !== null)
      ? `${rec.mean.toFixed(2)} ± ${rec.std.toFixed(3)} N`
      : '数据不足';
  }
</script>

<div class="hist">
  <div class="hist-title">质检历史数据</div>
  {#if records.length === 0}
    <div class="empty">暂无记录</div>
  {:else}
    <div class="rows">
      {#each records as rec (rec.time)}
        <div class="row">
          <span class="time">{fmtTime(rec.time)}</span>
          <span class="force">{fmtForce(rec)}</span>
          <span class="code">{rec.piCode ?? rec.family ?? '--'}</span>
        </div>
      {/each}
    </div>
  {/if}
</div>

<style>
  .hist {
    flex: 1;
    min-height: 0;
    display: flex;
    flex-direction: column;
    background: #1a1f35;
  }
  .hist-title {
    flex-shrink: 0;
    padding: 10px 18px 8px;
    font-size: 13px;
    letter-spacing: .12em;
    text-transform: uppercase;
    color: #7888b0;
    font-family: system-ui, sans-serif;
    border-bottom: 1px solid #2e3a58;
  }
  .empty {
    flex: 1;
    display: flex;
    align-items: center;
    justify-content: center;
    color: #3a4570;
    font-size: 14px;
    font-family: system-ui, sans-serif;
  }
  .rows {
    flex: 1;
    min-height: 0;
    overflow-y: auto;
  }
  .row {
    display: grid;
    grid-template-columns: 44px 1fr auto;
    align-items: baseline;
    gap: 10px;
    padding: 9px 18px;
    border-bottom: 1px solid #232a48;
    font-family: 'Courier New', Courier, monospace;
  }
  .row:last-child { border-bottom: none; }
  .time  { color: #5a6888; font-size: 13px; }
  .force { color: #eef2ff; font-size: 14px; }
  .code  { color: #7aa5f4; font-size: 13px; }
</style>
