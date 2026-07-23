<script>
  export let records = /** @type {{id:number, timestamp:string, family:string|null, pi_code:string|null, mean_force:number|null, std_force:number|null}[]} */ ([]);

  function fmtTime(iso) {
    const d = new Date(iso);
    return `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
  }

  function fmtDate(iso) {
    const d = new Date(iso);
    return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
  }

  function fmtForce(rec) {
    return (rec.mean_force !== null && rec.std_force !== null)
      ? `${rec.mean_force.toFixed(2)} ± ${rec.std_force.toFixed(3)} N`
      : '数据不足';
  }

  // Records already arrive newest-first; group consecutive rows sharing a
  // calendar date under one header so the date only appears once per day.
  $: groups = (() => {
    const out = [];
    for (const rec of records) {
      const date = fmtDate(rec.timestamp);
      const last = out[out.length - 1];
      if (last && last.date === date) last.rows.push(rec);
      else out.push({ date, rows: [rec] });
    }
    return out;
  })();
</script>

<div class="hist">
  <div class="hist-title">质检历史数据</div>
  {#if records.length === 0}
    <div class="empty">暂无记录</div>
  {:else}
    <div class="rows">
      {#each groups as group (group.date)}
        <div class="date-header">{group.date}</div>
        {#each group.rows as rec (rec.id)}
          <div class="row">
            <span class="time">{fmtTime(rec.timestamp)}</span>
            <span class="force">{fmtForce(rec)}</span>
            <span class="code">{rec.pi_code ?? rec.family ?? '--'}</span>
          </div>
        {/each}
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
  .date-header {
    position: sticky;
    top: 0;
    padding: 6px 18px;
    background: #141a30;
    color: #7aa5f4;
    font-size: 12px;
    font-weight: 700;
    letter-spacing: .04em;
    font-family: 'Courier New', Courier, monospace;
    border-bottom: 1px solid #2e3a58;
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
