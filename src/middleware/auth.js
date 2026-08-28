'use strict';
const jwt = require('../jwt');

function requireAuth(minRole) {
  return jwt.requireAuth(minRole);
}

module.exports = { requireAuth };
