'use strict';
const db = require('./db');

const NS_METHODS = {
  auth: ['login'],
  users: ['list', 'get', 'create', 'update', 'delete', 'countAdmins'],
  employees: ['list', 'get', 'stats', 'create', 'update', 'delete', 'setStatus'],
  vacaciones: ['list', 'create', 'delete'],
  horasExtra: ['get', 'listForPeriod', 'save'],
  incentivos: ['list', 'listForPeriod', 'create', 'update', 'delete'],
  pagoVacaciones: ['get', 'listForPeriod', 'totalDiasPagados', 'save', 'delete'],
  deduccionesManuales: ['listForPeriod', 'listForEmployee', 'create', 'update', 'delete'],
  salarioHistorial: ['record', 'listForEmployee', 'getSalarioPromedio', 'resetBaseline'],
  liquidaciones: ['listForEmployee', 'listAll', 'save', 'delete'],
  reportes: ['plantilla', 'antiguedad', 'cumpleanos', 'departamentos', 'nominaDepartamentos', 'empleadosCompleto', 'cedulasVencer', 'aniversarios', 'beneficios'],
  audit: ['add', 'list'],
  settings: ['get', 'set'],
  contactos: ['list', 'get', 'create', 'update', 'delete'],
  mailLog: ['add', 'list'],
  backups: ['list', 'create', 'restore'],
  historial: ['list']
};

const TOP_METHODS = [
  'nowIso'
];

module.exports = { NS_METHODS, TOP_METHODS };
