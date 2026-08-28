'use strict';
function pingHandler(req, res) {
  res.json({ ok: true, ts: Date.now() });
}
module.exports = { pingHandler };
