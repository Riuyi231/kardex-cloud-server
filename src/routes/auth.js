'use strict';
const d = require('../db');
const jwt = require('../jwt');

function loginHandler(req, res) {
  const { username, password } = req.body || {};
  const user = d.auth.login(String(username || '').trim(), String(password || ''));
  if (!user) return res.status(401).json({ ok: false, error: 'Usuario o contraseña incorrectos' });
  const token = jwt.sign({ role: user.role, sub: user.id, username: user.username, full_name: user.full_name });
  res.json({ ok: true, token, user });
}

module.exports = { loginHandler };
