import bcrypt from 'bcryptjs';
import { nanoid } from 'nanoid';
import { db, now } from './db.js';

const COOKIE = 'vais_sid';
const SESSION_DAYS = 60;

export function cookieName() {
  return COOKIE;
}

function deviceFromUa(ua = '') {
  if (/iPhone|iPad/i.test(ua)) return 'iPhone';
  if (/Android/i.test(ua)) return 'Android';
  if (/Mac OS/i.test(ua)) return 'Mac';
  if (/Windows/i.test(ua)) return 'Windows';
  if (/Linux/i.test(ua)) return 'Linux';
  return 'Browser';
}

export function publicUser(row) {
  if (!row) return null;
  return {
    email: row.email,
    admin: !!row.admin,
    mod: !!row.mod,
    welcomed: !!row.welcomed,
  };
}

export function getUserByEmail(email) {
  return db.prepare('SELECT * FROM users WHERE email = ? COLLATE NOCASE').get(String(email || '').trim());
}

export function getSessionUser(req) {
  const token = req.cookies?.[COOKIE];
  if (!token) return null;
  const row = db.prepare(`
    SELECT u.*, s.id AS session_id, s.token AS session_token
    FROM sessions s JOIN users u ON u.id = s.user_id
    WHERE s.token = ?
  `).get(token);
  if (!row || row.blocked) return null;
  db.prepare('UPDATE sessions SET last_seen = ? WHERE id = ?').run(now(), row.session_id);
  return row;
}

export function requireUser(req, res) {
  const user = getSessionUser(req);
  if (!user) {
    res.status(401).json({ error: 'Bitte melde dich erneut an.' });
    return null;
  }
  return user;
}

export function createSession(res, user, req) {
  const id = nanoid();
  const token = nanoid(48);
  const t = now();
  db.prepare(`
    INSERT INTO sessions (id, user_id, token, device, created, last_seen)
    VALUES (?, ?, ?, ?, ?, ?)
  `).run(id, user.id, token, deviceFromUa(req.headers['user-agent']), t, t);
  const secure = process.env.NODE_ENV === 'production' || process.env.FORCE_SECURE_COOKIE === '1';
  res.cookie(COOKIE, token, {
    httpOnly: true,
    sameSite: 'lax',
    secure,
    maxAge: SESSION_DAYS * 24 * 60 * 60 * 1000,
    path: '/',
  });
  return id;
}

export function destroySession(req, res) {
  const token = req.cookies?.[COOKIE];
  if (token) db.prepare('DELETE FROM sessions WHERE token = ?').run(token);
  res.clearCookie(COOKIE, { path: '/' });
}

function makeCode() {
  return String(Math.floor(100000 + Math.random() * 900000));
}

export function issueCode(email, purpose) {
  const code = makeCode();
  const t = now();
  db.prepare('DELETE FROM auth_codes WHERE email = ? COLLATE NOCASE AND purpose = ?').run(email, purpose);
  db.prepare(`
    INSERT INTO auth_codes (id, email, purpose, code, created, expires)
    VALUES (?, ?, ?, ?, ?, ?)
  `).run(nanoid(), email, purpose, code, t, t + 15 * 60 * 1000);
  if (process.env.AUTH_DEV === '1') {
    console.log(`[VAIs] ${purpose} code for ${email}: ${code}`);
  }
  // Hook for real SMTP later
  return code;
}

export function consumeCode(email, purpose, code) {
  if (process.env.AUTH_DEV === '1' && code === '123456') {
    db.prepare('DELETE FROM auth_codes WHERE email = ? COLLATE NOCASE AND purpose = ?').run(email, purpose);
    return true;
  }
  const row = db.prepare(`
    SELECT * FROM auth_codes
    WHERE email = ? COLLATE NOCASE AND purpose = ? AND code = ? AND expires > ?
    ORDER BY created DESC LIMIT 1
  `).get(email, purpose, code, now());
  if (!row) return false;
  db.prepare('DELETE FROM auth_codes WHERE id = ?').run(row.id);
  return true;
}

export async function registerUser(email, password) {
  email = String(email || '').trim().toLowerCase();
  if (!email || !email.includes('@')) throw Object.assign(new Error('Bitte gib eine gültige E-Mail-Adresse ein.'), { status: 400 });
  if (!password || password.length < 8) throw Object.assign(new Error('Das Passwort muss mindestens 8 Zeichen lang sein.'), { status: 400 });
  const existing = getUserByEmail(email);
  if (existing?.verified) throw Object.assign(new Error('Für diese E-Mail gibt es schon ein Konto. Melde dich an.'), { status: 400 });
  const hash = await bcrypt.hash(password, 10);
  const t = now();
  const adminEmail = (process.env.ADMIN_EMAIL || '').trim().toLowerCase();
  const isAdmin = adminEmail && adminEmail === email ? 1 : 0;
  if (existing) {
    db.prepare('UPDATE users SET password_hash = ?, verified = 0 WHERE id = ?').run(hash, existing.id);
  } else {
    db.prepare(`
      INSERT INTO users (id, email, password_hash, verified, admin, created)
      VALUES (?, ?, ?, 0, ?, ?)
    `).run(nanoid(), email, hash, isAdmin, t);
  }
  issueCode(email, 'verify');
}

export async function loginUser(email, password, req, res) {
  email = String(email || '').trim().toLowerCase();
  const user = getUserByEmail(email);
  if (!user) throw Object.assign(new Error('E-Mail oder Passwort stimmt nicht.'), { status: 401 });
  if (user.blocked) throw Object.assign(new Error('Dieses Konto wurde gesperrt.'), { status: 403 });
  const ok = await bcrypt.compare(String(password || ''), user.password_hash);
  if (!ok) throw Object.assign(new Error('E-Mail oder Passwort stimmt nicht.'), { status: 401 });
  if (!user.verified) {
    issueCode(email, 'verify');
    return { next: 'verify' };
  }
  createSession(res, user, req);
  return { ok: true };
}

export function startAuth(email) {
  email = String(email || '').trim().toLowerCase();
  if (!email || !email.includes('@')) throw Object.assign(new Error('Bitte gib eine gültige E-Mail-Adresse ein.'), { status: 400 });
  const user = getUserByEmail(email);
  return { mode: user?.verified ? 'login' : 'register' };
}

export function verifyEmail(email, code, req, res) {
  email = String(email || '').trim().toLowerCase();
  if (!consumeCode(email, 'verify', String(code || '').trim())) {
    throw Object.assign(new Error('Der Code stimmt nicht oder ist abgelaufen.'), { status: 400 });
  }
  const user = getUserByEmail(email);
  if (!user) throw Object.assign(new Error('Konto nicht gefunden.'), { status: 404 });
  db.prepare('UPDATE users SET verified = 1 WHERE id = ?').run(user.id);
  createSession(res, { ...user, verified: 1 }, req);
  return { ok: true };
}

export async function resetPassword(email, code, password) {
  email = String(email || '').trim().toLowerCase();
  if (!password || password.length < 8) throw Object.assign(new Error('Das Passwort muss mindestens 8 Zeichen lang sein.'), { status: 400 });
  if (!consumeCode(email, 'reset', String(code || '').trim())) {
    throw Object.assign(new Error('Der Code stimmt nicht oder ist abgelaufen.'), { status: 400 });
  }
  const user = getUserByEmail(email);
  if (!user) throw Object.assign(new Error('Konto nicht gefunden.'), { status: 404 });
  const hash = await bcrypt.hash(password, 10);
  db.prepare('UPDATE users SET password_hash = ?, verified = 1 WHERE id = ?').run(hash, user.id);
  return { ok: true };
}

export function listSessions(user, currentToken) {
  const rows = db.prepare('SELECT id, device, created, last_seen, token FROM sessions WHERE user_id = ? ORDER BY last_seen DESC').all(user.id);
  return rows.map((r) => ({
    id: r.id,
    device: r.device,
    created: r.created,
    lastSeen: r.last_seen,
    current: r.token === currentToken,
  }));
}
