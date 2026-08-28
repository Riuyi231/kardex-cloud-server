'use strict';
const express = require('express');
const cors = require('cors');
const rateLimit = require('express-rate-limit');
const path = require('path');
const d = require('./db');
const config = require('./config');
const { requireAuth } = require('./middleware/auth');
const { loginHandler } = require('./routes/auth');
const { rpcHandler } = require('./routes/rpc');
const { ocrHandler } = require('./routes/ocr');
const { pingHandler } = require('./routes/ping');

d.init();

const app = express();
app.use(cors());
app.use(express.json({ limit: '32mb' }));
app.use(rateLimit({ windowMs: config.RATE_LIMIT_WINDOW, max: config.RATE_LIMIT_MAX }));

app.get('/api/ping', pingHandler);
app.post('/api/auth/login', loginHandler);
app.post('/api/rpc', requireAuth('invitado'), rpcHandler);
app.post('/api/ocr', requireAuth('editor'), ocrHandler);

app.use((err, req, res, next) => {
  console.error('[API] Error no controlado:', err);
  if (!res.headersSent) res.status(500).json({ ok: false, error: 'Error interno del servidor' });
});

app.listen(config.PORT, () => {
  console.log(`[KARDEX] Servidor escuchando en http://localhost:${config.PORT}`);
});
