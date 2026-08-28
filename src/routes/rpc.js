'use strict';
const d = require('../db');
const { NS_METHODS, TOP_METHODS } = require('../db-api');

let chain = Promise.resolve();

function enqueue(fn) {
  const p = chain.then(fn, fn);
  chain = p.then(() => undefined, () => undefined);
  return p;
}

function execute(ns, method, args) {
  const target = ns == null ? db : d[ns];
  if (!target) throw new Error('Espacio de datos no válido: ' + ns);
  const allowed = ns == null ? TOP_METHODS : NS_METHODS[ns];
  if (!allowed || !allowed.includes(method)) {
    throw new Error('Operación no permitida: ' + (ns ? ns + '.' : '') + method);
  }
  if (typeof target[method] !== 'function') {
    throw new Error('Operación no disponible: ' + method);
  }
  return target[method].apply(target, args || []);
}

const db = {
  persistNow() { return true; }
};

function rpcHandler(req, res) {
  const { ns, method, args } = req.body || {};
  enqueue(() => {
    const data = execute(ns, method, args || []);
    res.json({ ok: true, data });
  }).catch((e) => {
    if (!res.headersSent) res.json({ ok: false, error: (e && e.message) ? e.message : String(e) });
  });
}

module.exports = { rpcHandler };
