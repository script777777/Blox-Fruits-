import 'dotenv/config';
import express from 'express';
import cookieParser from 'cookie-parser';
import path from 'node:path';
import fs from 'node:fs';
import { fileURLToPath } from 'node:url';
import { db, now } from './db.js';
import {
  startAuth,
  registerUser,
  loginUser,
  verifyEmail,
  resetPassword,
  issueCode,
  getUserByEmail,
  getSessionUser,
  requireUser,
  destroySession,
  publicUser,
  listSessions,
  cookieName,
} from './auth.js';
import { chatRouter } from './chat.js';
import { statusPayload } from './models.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.join(__dirname, '..');
const publicDir = path.join(root, 'public');

const app = express();
const PORT = Number(process.env.PORT || 3000);

app.disable('x-powered-by');
app.use(cookieParser(process.env.SESSION_SECRET || 'vais-dev-secret'));
app.use(express.json({ limit: '12mb' }));
app.use(express.text({ type: ['text/*'], limit: '2mb' }));

app.use((req, res, next) => {
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('X-Frame-Options', 'DENY');
  res.setHeader('Referrer-Policy', 'same-origin');
  res.setHeader(
    'Content-Security-Policy',
    "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; font-src 'self' data:; img-src 'self' data: blob: https:; connect-src 'self'; frame-src 'self'; worker-src 'self'; manifest-src 'self'; media-src 'self' blob: data:; object-src 'none'; base-uri 'self'; form-action 'self'; frame-ancestors 'none'",
  );
  next();
});

app.get('/api/status', (_req, res) => {
  res.json(statusPayload());
});

app.post('/api/log', (req, res) => {
  if (process.env.LOG_CLIENT === '1') console.log('[client]', req.body);
  res.status(204).end();
});

app.get('/api/auth/config', (_req, res) => {
  res.json({ google: !!(process.env.GOOGLE_CLIENT_ID && process.env.GOOGLE_CLIENT_SECRET) });
});

app.get('/api/auth/me', (req, res) => {
  const user = getSessionUser(req);
  if (!user) return res.status(401).json({ error: 'Bitte melde dich erneut an.' });
  res.json({ user: publicUser(user) });
});

app.post('/api/auth/start', (req, res) => {
  try {
    res.json(startAuth(req.body?.email));
  } catch (err) {
    res.status(err.status || 400).json({ error: err.message });
  }
});

app.post('/api/auth/register', async (req, res) => {
  try {
    await registerUser(req.body?.email, req.body?.password);
    res.json({ ok: true });
  } catch (err) {
    res.status(err.status || 400).json({ error: err.message, retryAfter: err.retryAfter });
  }
});

app.post('/api/auth/login', async (req, res) => {
  try {
    res.json(await loginUser(req.body?.email, req.body?.password, req, res));
  } catch (err) {
    res.status(err.status || 401).json({ error: err.message });
  }
});

app.post('/api/auth/verify', (req, res) => {
  try {
    res.json(verifyEmail(req.body?.email, req.body?.code, req, res));
  } catch (err) {
    res.status(err.status || 400).json({ error: err.message });
  }
});

app.post('/api/auth/forgot', (req, res) => {
  try {
    const email = String(req.body?.email || '').trim().toLowerCase();
    if (getUserByEmail(email)) issueCode(email, 'reset');
    res.json({ ok: true });
  } catch (err) {
    res.status(err.status || 400).json({ error: err.message });
  }
});

app.post('/api/auth/reset', async (req, res) => {
  try {
    res.json(await resetPassword(req.body?.email, req.body?.code, req.body?.password));
  } catch (err) {
    res.status(err.status || 400).json({ error: err.message });
  }
});

app.post('/api/auth/resend', (req, res) => {
  try {
    const email = String(req.body?.email || '').trim().toLowerCase();
    const purpose = req.body?.purpose === 'reset' ? 'reset' : 'verify';
    issueCode(email, purpose);
    res.json({ ok: true });
  } catch (err) {
    res.status(err.status || 400).json({ error: err.message });
  }
});

app.post('/api/auth/logout', (req, res) => {
  destroySession(req, res);
  res.json({ ok: true });
});

app.post('/api/auth/welcomed', (req, res) => {
  const user = requireUser(req, res);
  if (!user) return;
  db.prepare('UPDATE users SET welcomed = 1 WHERE id = ?').run(user.id);
  res.json({ ok: true });
});

app.get('/api/auth/sessions', (req, res) => {
  const user = requireUser(req, res);
  if (!user) return;
  res.json({ sessions: listSessions(user, req.cookies?.[cookieName()]) });
});

app.post('/api/auth/sessions/revoke', (req, res) => {
  const user = requireUser(req, res);
  if (!user) return;
  if (req.body?.others) {
    db.prepare('DELETE FROM sessions WHERE user_id = ? AND token != ?')
      .run(user.id, req.cookies?.[cookieName()]);
  } else if (req.body?.id) {
    db.prepare('DELETE FROM sessions WHERE id = ? AND user_id = ?').run(req.body.id, user.id);
  }
  res.json({ ok: true });
});

app.post('/api/auth/password', async (req, res) => {
  const user = requireUser(req, res);
  if (!user) return;
  try {
    const bcrypt = (await import('bcryptjs')).default;
    const ok = await bcrypt.compare(String(req.body?.current || ''), user.password_hash);
    if (!ok) return res.status(400).json({ error: 'Aktuelles Passwort stimmt nicht.' });
    if (!req.body?.next || String(req.body.next).length < 8) {
      return res.status(400).json({ error: 'Das neue Passwort muss mindestens 8 Zeichen lang sein.' });
    }
    const hash = await bcrypt.hash(String(req.body.next), 10);
    db.prepare('UPDATE users SET password_hash = ? WHERE id = ?').run(hash, user.id);
    res.json({ ok: true });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

app.post('/api/auth/delete', (req, res) => {
  const user = requireUser(req, res);
  if (!user) return;
  destroySession(req, res);
  db.prepare('DELETE FROM users WHERE id = ?').run(user.id);
  res.json({ ok: true });
});

app.use('/api/chat', chatRouter);

app.use('/api/groups', (req, res) => {
  if (req.method === 'GET') return res.json({ groups: [] });
  return res.status(400).json({ error: 'Teams sind in diesem Rebuild noch nicht aktiv.' });
});

function sendHtml(res, file) {
  res.sendFile(path.join(publicDir, file));
}

app.get('/login', (_req, res) => sendHtml(res, 'login.html'));
app.get('/datenschutz', (_req, res) => sendHtml(res, 'datenschutz.html'));
app.get('/impressum', (_req, res) => sendHtml(res, 'impressum.html'));
app.get('/status', (_req, res) => sendHtml(res, 'status.html'));

app.get('/s/:id', (req, res) => {
  const share = db.prepare('SELECT chat_id FROM shares WHERE id = ?').get(req.params.id);
  if (!share) return res.status(404).send('Not found');
  // Shared view reuses the app shell; client loads via hash if needed
  sendHtml(res, 'app.html');
});

app.get('/', (req, res) => {
  const user = getSessionUser(req);
  if (!user) return res.redirect('/login');
  sendHtml(res, 'app.html');
});

app.use(express.static(publicDir, {
  extensions: ['html'],
  setHeaders(res, filePath) {
    if (filePath.endsWith('.html')) res.setHeader('Cache-Control', 'no-cache');
  },
}));

app.use((req, res) => {
  if (req.path.startsWith('/api/')) return res.status(404).json({ error: 'Not found' });
  res.status(404).send('Not found');
});

app.listen(PORT, () => {
  console.log(`VAIs listening on http://127.0.0.1:${PORT}`);
  console.log(`Auth dev mode: ${process.env.AUTH_DEV === '1' ? 'ON (code 123456 works)' : 'off'}`);
  console.log(`Groq: ${process.env.GROQ_API_KEY ? 'configured' : 'missing'} · OpenRouter: ${process.env.OPENROUTER_API_KEY ? 'configured' : 'missing'}`);
  void now;
});
