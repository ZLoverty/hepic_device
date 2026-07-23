async function req(method, path, body) {
  const r = await fetch(path, {
    method,
    headers: body ? { 'Content-Type': 'application/json' } : {},
    body: body ? JSON.stringify(body) : undefined,
  });
  if (!r.ok) throw new Error(`${method} ${path} → ${r.status}`);
  return r.json();
}

export const api = {
  klipper: {
    status:        ()            => req('GET',  '/api/klipper/status'),
    setTemp:       (temperature) => req('POST', '/api/klipper/temperature',    { temperature }),
    gcode:         (script)      => req('POST', '/api/klipper/gcode',          { script }),
    emergencyStop: ()            => req('POST', '/api/klipper/emergency_stop'),
    restart:       ()            => req('POST', '/api/klipper/restart'),
  },
  materials: {
    families: ()               => req('GET',  '/api/materials/'),
    version:  ()               => req('GET',  '/api/materials/version'),
    sync:     ()               => req('POST', '/api/materials/sync'),
    list:     (family)         => req('GET',  `/api/materials/${encodeURIComponent(family)}`),
    get:      (family, piCode) => req('GET',  `/api/materials/${encodeURIComponent(family)}/${encodeURIComponent(piCode)}`),
  },
  qc: {
    start:   (family, pi_code) => req('POST', '/api/qc/start', { family, pi_code }),
    history: (limit)           => req('GET',  `/api/qc/history${limit ? `?limit=${limit}` : ''}`),
    addHistory: (rec)          => req('POST', '/api/qc/history', rec),
  },
  system: {
    info:         ()     => req('GET',  '/api/system/info'),
    update:       ()     => req('POST', '/api/system/update'),
    updateStatus: (tail) => req('GET',  `/api/system/update/status${tail ? `?tail=${tail}` : ''}`),
  },
};
