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
      ? `${rec.mean_force.toFixed(2)} ± ${rec.std_force.toFixed(2)}`
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
    background: #f5f6f9;
  }
  .hist-title {
    flex-shrink: 0;
    padding: 10px 18px 8px;
    font-size: 20px;
    letter-spacing: .12em;
    text-transform: uppercase;
    color: #667085;
    font-family: system-ui, sans-serif;
    border-bottom: 1px solid #e2e5ec;
  }
  .empty {
    flex: 1;
    display: flex;
    align-items: center;
    justify-content: center;
    color: #9ca3af;
    font-size: 20px;
    font-family: system-ui, sans-serif;
  }
  .rows {
    flex: 1;
    min-height: 0;
    overflow: auto;
    scrollbar-width: thin;
    scrollbar-color: #d0d5e0 transparent;
  }
  .rows::-webkit-scrollbar { width: 8px; height: 8px; }
  .rows::-webkit-scrollbar-track { background: transparent; }
  .rows::-webkit-scrollbar-thumb { background: #d0d5e0; border-radius: 4px; }
  .date-header {
    position: sticky;
    top: 0;
    left: 0;
    padding: 8px 18px;
    background: #eceef3;
    color: #2f6fed;
    font-size: 20px;
    font-weight: 700;
    letter-spacing: .04em;
    font-family: Arial, Helvetica, sans-serif; font-variant-numeric: tabular-nums;
    border-bottom: 1px solid #e2e5ec;
    width: max-content;
    min-width: 100%;
  }
  .row {
    display: grid;
    grid-template-columns: 64px auto auto;
    align-items: baseline;
    gap: 10px;
    padding: 12px 18px;
    border-bottom: 1px solid #e2e5ec;
    font-family: Arial, Helvetica, sans-serif; font-variant-numeric: tabular-nums;
    white-space: nowrap;
    width: max-content;
    min-width: 100%;
  }
  .row:last-child { border-bottom: none; }
  .time  { color: #667085; font-size: 20px; flex-shrink: 0; }
  .force { color: #14161d; font-size: 20px; }
  .code  { color: #2f6fed; font-size: 20px; }
</style>
