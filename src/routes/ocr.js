'use strict';
const fs = require('fs');
const os = require('os');
const path = require('path');
const crypto = require('crypto');
const { processFile } = require('../services/cedula');

const ALLOWED_EXT = /\.(pdf|png|jpe?g|webp|bmp|gif)$/i;
const MAX_BYTES = 20 * 1024 * 1024;

let chain = Promise.resolve();

function enqueue(fn) {
  const p = chain.then(fn, fn);
  chain = p.then(() => undefined, () => undefined);
  return p;
}

function ocrHandler(req, res) {
  const { name, data } = req.body || {};
  enqueue(async () => {
    if (typeof data !== 'string' || !data) throw new Error('Falta el contenido base64 del archivo');

    let ext = '.pdf';
    if (typeof name === 'string' && name) {
      const m = /\.([a-z0-9]+)$/i.exec(name);
      if (m) ext = '.' + m[1].toLowerCase();
    }
    if (!ALLOWED_EXT.test(ext)) throw new Error('Solo se admiten archivos PDF, PNG o JPG');

    const buf = Buffer.from(data, 'base64');
    if (buf.length === 0) throw new Error('Contenido vacío');
    if (buf.length > MAX_BYTES) throw new Error('El archivo excede el tamaño máximo permitido (20MB)');

    const tmp = path.join(os.tmpdir(), `kardex-ocr-${crypto.randomBytes(6).toString('hex')}${ext}`);
    fs.writeFileSync(tmp, buf);
    try {
      const result = await processFile(tmp);
      res.json({ ok: true, data: { ...result, fileName: name || result.fileName } });
    } finally {
      try { fs.unlinkSync(tmp); } catch (e) { /* noop */ }
    }
  }).catch((e) => {
    console.error('[KARDEX] Error OCR:', (e && e.message) ? e.message : e);
    if (!res.headersSent) res.status(500).json({ ok: false, error: (e && e.message) ? e.message : String(e) });
  });
}

module.exports = { ocrHandler };