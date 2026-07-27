import { writable } from 'svelte/store';

export const sensorData = writable({
  extrusion_force_N:    null,
  measured_feedrate_mms: null,
  hotend_temperature:   null,
  target_temperature:   null,
  feedrate_mms:         null,
  klippy_state:         'unknown',
});

/** Last 200 extrusion-force readings for the global sparkline. */
export const forceHistory = writable(/** @type {number[]} */([]));

/** Whether the /ws/sensors WebSocket is currently connected. */
export const wsConnected = writable(false);

/**
 * QC session state. Lives at App level so it survives page navigation.
 * The WebSocket to /api/qc/stream is managed by App.svelte, not the QC page.
 */
export const qcState = writable({
  phase:    /** @type {'idle'|'running'|'done'} */ ('idle'),
  statusMsg: '',
  family:   /** @type {string|null} */ (null),
  piCode:   /** @type {string|null} */ (null),
  material: /** @type {object|null} */ (null),
  extrudeStartedAt: /** @type {number|null} */ (null),  // Date.now() when extrusion begins
});

/** Force readings accumulated during the current QC session. */
export const qcForceHistory = writable(/** @type {number[]} */([]));

/**
 * Completed QC runs, newest first. Backed by the device's local
 * `/api/qc/history` (SQLite, via the shared HEPiC.database.QcHistoryStore) —
 * fetched on startup in App.svelte and appended to as runs finish.
 */
export const qcHistory = writable(/** @type {{id:number, timestamp:string, family:string|null, pi_code:string|null, mean_force:number|null, std_force:number|null}[]} */([]));

