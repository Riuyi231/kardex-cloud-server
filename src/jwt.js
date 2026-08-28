'use strict';
const crypto = require('crypto');
const config = require('./config');

let secret = config.JWT_SECRET;
if (!secret) {
  secret = crypto.randomBytes(48).toString('hex');
  console.log('[JWT] Secret auto-generado. Define JWT_SECRET en .env para persistencia.');
}
const TOKEN_TTL = 60 * 60 * 24 * 30; // 30 días

function b64url(buf) {
  return Buffer.from(buf).toString('base64').replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function sign(payload) {
  const header = { alg: 'HS256', typ: 'JWT' };
  const head = b64url(Buffer.from(JSON.stringify(header)));
  const body = b64url(Buffer.from(JSON.stringify({ ...payload, iat: Math.floor(Date.now() / 1000) })));
  const sig = crypto.createHmac('sha256', secret).update(head + '.' + body).digest();
  return head + '.' + body + '.' + b64url(sig);
}

function verify(token) {
  try {
    const [head, body, sig] = String(token).split('.');
    const expected = crypto.createHmac('sha256', secret).update(head + '.' + body).digest();
    const givenRaw = Buffer.from(sig.replace(/-/g, '+').replace(/_/g, '/'), 'base64');
    if (!crypto.timingSafeEqual(givenRaw, expected)) return null;
    const payload = JSON.parse(Buffer.from(body, 'base64').toString());
    if (!payload.iat || Date.now() / 1000 - payload.iat > TOKEN_TTL) return null;
    return payload;
  } catch (e) {
    return null;
  }
}

function requireAuth(minRole) {
  return (req, res, next) => {
    const tok = String(req.headers.authorization || '').replace(/^Bearer\s+/i, '');
    const payload = verify(tok);
    if (!payload) return res.status(401).json({ ok: false, error: 'No autorizado' });
    const rolePriority = { admin: 3, editor: 2, invitado: 1 };
    const userLevel = rolePriority[payload.role] || 0;
    const requiredLevel = rolePriority[minRole] || 0;
    if (userLevel < requiredLevel) return res.status(403).json({ ok: false, error: 'Acceso denegado' });
    req.user = payload;
    next();
  };
}

module.exports = { sign, verify, requireAuth };
