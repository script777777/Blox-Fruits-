import { Router } from 'express';
import { nanoid } from 'nanoid';
import { db, now } from './db.js';
import { requireUser, cookieName } from './auth.js';
import { publicModels, pickForMode, modelById } from './models.js';
import { streamModel, buildSystemPrompt, improveText, translateText } from './providers.js';

export const chatRouter = Router();

const MAX_CHATS = Number(process.env.MAX_CHATS || 100);

function parseJson(s, fallback) {
  try {
    return JSON.parse(s);
  } catch {
    return fallback;
  }
}

function getChat(userId, chatId) {
  return db.prepare('SELECT * FROM chats WHERE id = ? AND user_id = ?').get(chatId, userId);
}

function loadTurns(chatId) {
  const turns = db.prepare('SELECT * FROM turns WHERE chat_id = ? ORDER BY turn_index').all(chatId);
  const answers = db.prepare('SELECT * FROM answers WHERE chat_id = ? ORDER BY turn_index, side').all(chatId);
  return turns.map((t) => ({
    user: t.user_text,
    attachments: parseJson(t.attachments_json, []),
    answers: answers
      .filter((a) => a.turn_index === t.turn_index)
      .map((a) => ({
        text: a.text,
        status: a.status,
        error: a.error,
        thinking: a.thinking,
        thinkMs: a.think_ms,
        images: parseJson(a.images_json, []),
        sources: parseJson(a.sources_json, []),
        steps: parseJson(a.steps_json, []),
        reaction: a.reaction,
        feedback: a.feedback,
        reasons: parseJson(a.reasons_json, []),
        auto: parseJson(a.auto_json, null),
        buildMs: a.build_ms,
      })),
  }));
}

function serializeChat(row) {
  const labels = parseJson(row.labels_json, []);
  const reveal = parseJson(row.model_ids_json, []).map((id) => modelById(id)?.name || id);
  return {
    id: row.id,
    mode: row.mode,
    modality: row.modality,
    title: row.title,
    labels: row.mode === 'battle' && !row.winner ? labels : (row.winner ? reveal : labels),
    winner: row.winner,
    shared: !!row.shared,
    incognito: !!row.incognito,
    pinned: !!row.pinned,
    folder: row.folder || null,
    updated: row.updated,
    created: row.created,
    turns: loadTurns(row.id),
  };
}

function profileOf(user) {
  const memories = db.prepare('SELECT id, text, created FROM memories WHERE user_id = ? ORDER BY id DESC LIMIT 40').all(user.id);
  return {
    instructions: user.instructions || '',
    memoryOn: !!user.memory_on,
    planFirst: user.plan_first !== 0,
    memories,
  };
}

chatRouter.get('/models', (req, res) => {
  if (!requireUser(req, res)) return;
  res.json({ models: publicModels() });
});

chatRouter.get('/maintenance', (_req, res) => {
  res.json({ on: false, message: '', staff: false });
});

chatRouter.get('/list', (req, res) => {
  const user = requireUser(req, res);
  if (!user) return;
  const chats = db.prepare(`
    SELECT id, title, mode, updated, pinned, folder, incognito
    FROM chats WHERE user_id = ? AND incognito = 0
    ORDER BY pinned DESC, updated DESC
  `).all(user.id).map((c) => ({
    id: c.id,
    title: c.title,
    mode: c.mode,
    updated: c.updated,
    pinned: !!c.pinned,
    folder: c.folder || null,
  }));
  res.json({ chats, maxChats: MAX_CHATS });
});

chatRouter.post('/start', (req, res) => {
  const user = requireUser(req, res);
  if (!user) return;
  const count = db.prepare('SELECT COUNT(*) AS n FROM chats WHERE user_id = ? AND incognito = 0').get(user.id).n;
  if (count >= MAX_CHATS) {
    return res.status(400).json({
      error: 'Chat-Limit erreicht.',
      chatLimit: MAX_CHATS,
    });
  }
  const mode = req.body?.mode || 'direct';
  const modality = req.body?.modality || 'auto';
  const title = String(req.body?.title || 'Chat').slice(0, 80);
  const picked = pickForMode(mode, modality, req.body?.models || []);
  if (!picked.ids.length) {
    return res.status(400).json({ error: 'Kein Modell verfügbar. Bitte API-Schlüssel setzen.' });
  }
  const id = nanoid();
  const t = now();
  const labels = mode === 'battle' ? ['Assistent A', 'Assistent B'] : picked.labels;
  db.prepare(`
    INSERT INTO chats (id, user_id, mode, modality, title, labels_json, model_ids_json, incognito, created, updated)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  `).run(
    id,
    user.id,
    mode,
    modality,
    title,
    JSON.stringify(labels),
    JSON.stringify(picked.ids),
    req.body?.incognito ? 1 : 0,
    t,
    t,
  );
  res.json({ id, models: labels });
});

chatRouter.post('/stream', async (req, res) => {
  const user = requireUser(req, res);
  if (!user) return;
  const { chatId, side = 0, turn = 0, messages = [], display } = req.body || {};
  const chat = getChat(user.id, chatId);
  if (!chat) return res.status(404).json({ error: 'Chat nicht gefunden.' });

  const modelIds = parseJson(chat.model_ids_json, []);
  const modelId = modelIds[side] || modelIds[0];
  const profile = profileOf(user);

  // Persist turn + empty answer
  const userText = display?.text ?? '';
  const attachments = display?.attachments ?? [];
  db.prepare(`
    INSERT INTO turns (chat_id, turn_index, user_text, attachments_json)
    VALUES (?, ?, ?, ?)
    ON CONFLICT(chat_id, turn_index) DO UPDATE SET
      user_text = excluded.user_text,
      attachments_json = excluded.attachments_json
  `).run(chatId, turn, userText, JSON.stringify(attachments));

  db.prepare(`
    INSERT INTO answers (chat_id, turn_index, side, text, status)
    VALUES (?, ?, ?, '', 'streaming')
    ON CONFLICT(chat_id, turn_index, side) DO UPDATE SET
      text = '', status = 'streaming', error = NULL, thinking = '', images_json = '[]', steps_json = '[]'
  `).run(chatId, turn, side);

  res.setHeader('Content-Type', 'application/x-ndjson; charset=utf-8');
  res.setHeader('Cache-Control', 'no-cache, no-transform');
  res.setHeader('X-Accel-Buffering', 'no');
  if (typeof res.flushHeaders === 'function') res.flushHeaders();

  const write = (obj) => {
    res.write(`${JSON.stringify(obj)}\n`);
  };

  const started = Date.now();
  let text = '';
  let thinking = '';
  const images = [];
  const steps = [];
  const ctrl = new AbortController();
  req.on('close', () => ctrl.abort());

  try {
    const system = buildSystemPrompt({
      mode: chat.mode,
      modality: chat.modality,
      profile,
      memories: profile.memoryOn ? profile.memories : [],
    });
    let sawDone = false;
    for await (const msg of streamModel({
      modelId,
      modality: chat.modality,
      messages,
      system,
      signal: ctrl.signal,
    })) {
      if (msg.t) text += msg.t;
      if (msg.r) thinking += msg.r;
      if (msg.image) images.push(msg.image);
      if (msg.step) steps.push(msg.step);
      if (msg.done) sawDone = true;
      write(msg);
    }
    if (!text && !images.length) {
      write({ t: 'Keine Antwort vom Modell.' });
      text = 'Keine Antwort vom Modell.';
    }
    if (!sawDone) write({ done: true });
    db.prepare(`
      UPDATE answers SET text = ?, status = 'done', thinking = ?, images_json = ?, steps_json = ?, build_ms = ?, think_ms = ?
      WHERE chat_id = ? AND turn_index = ? AND side = ?
    `).run(
      text,
      thinking,
      JSON.stringify(images),
      JSON.stringify(steps),
      Date.now() - started,
      thinking ? Math.min(Date.now() - started, 60000) : 0,
      chatId,
      turn,
      side,
    );
    db.prepare('UPDATE chats SET updated = ? WHERE id = ?').run(now(), chatId);
  } catch (err) {
    if (!ctrl.signal.aborted) {
      write({ error: err.message || 'Modellfehler' });
      db.prepare(`
        UPDATE answers SET status = 'error', error = ?, text = ?, thinking = ?, build_ms = ?
        WHERE chat_id = ? AND turn_index = ? AND side = ?
      `).run(err.message || 'error', text, thinking, Date.now() - started, chatId, turn, side);
    } else {
      db.prepare(`
        UPDATE answers SET status = ?, text = ?, thinking = ?, build_ms = ?
        WHERE chat_id = ? AND turn_index = ? AND side = ?
      `).run(text || images.length ? 'done' : 'stopped', text, thinking, Date.now() - started, chatId, turn, side);
    }
  } finally {
    res.end();
  }
});

chatRouter.post('/stop', (req, res) => {
  if (!requireUser(req, res)) return;
  res.json({ ok: true });
});

chatRouter.post('/vote', (req, res) => {
  const user = requireUser(req, res);
  if (!user) return;
  const chat = getChat(user.id, req.body?.chatId);
  if (!chat) return res.status(404).json({ error: 'Chat nicht gefunden.' });
  const winner = req.body?.winner === 'b' ? 'b' : 'a';
  const ids = parseJson(chat.model_ids_json, []);
  const models = ids.map((id) => modelById(id)?.name || id);
  db.prepare('UPDATE chats SET winner = ? WHERE id = ?').run(winner, chat.id);
  db.prepare('INSERT OR REPLACE INTO votes (chat_id, winner, created) VALUES (?, ?, ?)').run(chat.id, winner, now());
  res.json({ winner, models });
});

chatRouter.post('/feedback', (req, res) => {
  const user = requireUser(req, res);
  if (!user) return;
  const { chatId, turn, side, value, reasons = [] } = req.body || {};
  const chat = getChat(user.id, chatId);
  if (!chat) return res.status(404).json({ error: 'Chat nicht gefunden.' });
  db.prepare(`
    UPDATE answers SET feedback = ?, reasons_json = ? WHERE chat_id = ? AND turn_index = ? AND side = ?
  `).run(value ?? null, JSON.stringify(reasons), chatId, turn, side);
  db.prepare(`
    INSERT INTO feedback (chat_id, turn_index, side, value, reasons_json, created)
    VALUES (?, ?, ?, ?, ?, ?)
  `).run(chatId, turn, side, value ?? 0, JSON.stringify(reasons), now());
  res.json({ ok: true });
});

chatRouter.post('/rename', (req, res) => {
  const user = requireUser(req, res);
  if (!user) return;
  const chat = getChat(user.id, req.body?.chatId);
  if (!chat) return res.status(404).json({ error: 'Chat nicht gefunden.' });
  const title = String(req.body?.title || '').trim().slice(0, 80) || chat.title;
  db.prepare('UPDATE chats SET title = ?, updated = ? WHERE id = ?').run(title, now(), chat.id);
  res.json({ title });
});

chatRouter.post('/organize', (req, res) => {
  const user = requireUser(req, res);
  if (!user) return;
  const chat = getChat(user.id, req.body?.chatId);
  if (!chat) return res.status(404).json({ error: 'Chat nicht gefunden.' });
  const pinned = req.body?.pinned === undefined ? chat.pinned : (req.body.pinned ? 1 : 0);
  const folder = req.body?.folder === undefined ? chat.folder : (req.body.folder || null);
  db.prepare('UPDATE chats SET pinned = ?, folder = ?, updated = ? WHERE id = ?').run(pinned, folder, now(), chat.id);
  res.json({ ok: true, pinned: !!pinned, folder });
});

chatRouter.post('/share', (req, res) => {
  const user = requireUser(req, res);
  if (!user) return;
  const chat = getChat(user.id, req.body?.chatId);
  if (!chat) return res.status(404).json({ error: 'Chat nicht gefunden.' });
  let shareId = chat.share_id;
  if (!shareId) {
    shareId = nanoid(10);
    db.prepare('UPDATE chats SET shared = 1, share_id = ? WHERE id = ?').run(shareId, chat.id);
    db.prepare('INSERT OR REPLACE INTO shares (id, chat_id, created) VALUES (?, ?, ?)').run(shareId, chat.id, now());
  } else {
    db.prepare('UPDATE chats SET shared = 1 WHERE id = ?').run(chat.id);
  }
  res.json({ url: `/s/${shareId}` });
});

chatRouter.post('/unshare', (req, res) => {
  const user = requireUser(req, res);
  if (!user) return;
  const chat = getChat(user.id, req.body?.chatId);
  if (!chat) return res.status(404).json({ error: 'Chat nicht gefunden.' });
  db.prepare('UPDATE chats SET shared = 0 WHERE id = ?').run(chat.id);
  res.json({ ok: true });
});

chatRouter.post('/forget', (req, res) => {
  const user = requireUser(req, res);
  if (!user) return;
  const chat = getChat(user.id, req.body?.chatId);
  if (chat?.incognito) db.prepare('DELETE FROM chats WHERE id = ?').run(chat.id);
  res.json({ ok: true });
});

chatRouter.post('/clear', (req, res) => {
  const user = requireUser(req, res);
  if (!user) return;
  db.prepare('DELETE FROM chats WHERE user_id = ?').run(user.id);
  res.json({ ok: true });
});

chatRouter.post('/truncate', (req, res) => {
  const user = requireUser(req, res);
  if (!user) return;
  const chat = getChat(user.id, req.body?.chatId);
  if (!chat) return res.status(404).json({ error: 'Chat nicht gefunden.' });
  const fromTurn = Number(req.body?.fromTurn ?? 0);
  db.prepare('DELETE FROM answers WHERE chat_id = ? AND turn_index >= ?').run(chat.id, fromTurn);
  db.prepare('DELETE FROM turns WHERE chat_id = ? AND turn_index >= ?').run(chat.id, fromTurn);
  res.json({ ok: true });
});

chatRouter.post('/improve', async (req, res) => {
  if (!requireUser(req, res)) return;
  try {
    const text = await improveText(String(req.body?.text || ''));
    res.json({ text });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

chatRouter.post('/translate', async (req, res) => {
  if (!requireUser(req, res)) return;
  try {
    const text = await translateText(String(req.body?.text || ''), req.body?.from, req.body?.to);
    res.json({ text });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

chatRouter.post('/extras', (req, res) => {
  if (!requireUser(req, res)) return;
  res.json({ followups: [] });
});

chatRouter.post('/inject', (req, res) => {
  if (!requireUser(req, res)) return;
  res.json({ injected: false });
});

chatRouter.post('/think-summary', (req, res) => {
  if (!requireUser(req, res)) return;
  const { chatId, turn, side } = req.body || {};
  const a = db.prepare('SELECT thinking FROM answers WHERE chat_id = ? AND turn_index = ? AND side = ?')
    .get(chatId, turn, side);
  res.json({ summary: a?.thinking || '' });
});

chatRouter.get('/profile', (req, res) => {
  const user = requireUser(req, res);
  if (!user) return;
  res.json(profileOf(user));
});

chatRouter.post('/profile', (req, res) => {
  const user = requireUser(req, res);
  if (!user) return;
  if (req.body?.instructions !== undefined) {
    db.prepare('UPDATE users SET instructions = ? WHERE id = ?')
      .run(String(req.body.instructions).slice(0, 1500), user.id);
  }
  if (req.body?.memoryOn !== undefined) {
    db.prepare('UPDATE users SET memory_on = ? WHERE id = ?').run(req.body.memoryOn ? 1 : 0, user.id);
  }
  if (req.body?.planFirst !== undefined) {
    db.prepare('UPDATE users SET plan_first = ? WHERE id = ?').run(req.body.planFirst ? 1 : 0, user.id);
  }
  res.json({ ok: true });
});

chatRouter.post('/profile/memory/delete', (req, res) => {
  const user = requireUser(req, res);
  if (!user) return;
  db.prepare('DELETE FROM memories WHERE id = ? AND user_id = ?').run(Number(req.body?.id), user.id);
  res.json({ ok: true });
});

chatRouter.post('/profile/memory/clear', (req, res) => {
  const user = requireUser(req, res);
  if (!user) return;
  db.prepare('DELETE FROM memories WHERE user_id = ?').run(user.id);
  res.json({ ok: true });
});

chatRouter.post('/profile/name', (req, res) => {
  if (!requireUser(req, res)) return;
  res.json({ ok: true });
});

chatRouter.get('/stats', (req, res) => {
  const user = requireUser(req, res);
  if (!user) return;
  const chats = db.prepare('SELECT COUNT(*) AS n FROM chats WHERE user_id = ? AND incognito = 0').get(user.id).n;
  const questions = db.prepare(`
    SELECT COUNT(*) AS n FROM turns t JOIN chats c ON c.id = t.chat_id WHERE c.user_id = ?
  `).get(user.id).n;
  const votes = db.prepare(`
    SELECT COUNT(*) AS n FROM votes v JOIN chats c ON c.id = v.chat_id WHERE c.user_id = ?
  `).get(user.id).n;
  const likes = db.prepare(`
    SELECT COUNT(*) AS n FROM answers a JOIN chats c ON c.id = a.chat_id WHERE c.user_id = ? AND a.feedback = 1
  `).get(user.id).n;
  const modeRows = db.prepare('SELECT mode, COUNT(*) AS n FROM chats WHERE user_id = ? GROUP BY mode').all(user.id);
  const modes = Object.fromEntries(modeRows.map((r) => [r.mode, r.n]));
  res.json({
    since: user.created,
    chats,
    questions,
    votes,
    likes,
    modes,
    usage: {},
    mostUsed: [],
  });
});

chatRouter.get('/ledger', (req, res) => {
  if (!requireUser(req, res)) return;
  res.json({ balance: 0, series: [], entries: [] });
});

chatRouter.post('/ledger/add', (req, res) => {
  if (!requireUser(req, res)) return;
  res.json({ ok: true });
});

chatRouter.post('/ledger/set', (req, res) => {
  if (!requireUser(req, res)) return;
  res.json({ ok: true });
});

chatRouter.post('/ledger/delete', (req, res) => {
  if (!requireUser(req, res)) return;
  res.json({ ok: true });
});

chatRouter.get('/leaderboard', (req, res) => {
  if (!requireUser(req, res)) return;
  res.json({ models: [] });
});

chatRouter.get('/announcements', (req, res) => {
  const user = requireUser(req, res);
  if (!user) return;
  const rows = db.prepare(`
    SELECT a.* FROM announcements a
    LEFT JOIN announcement_reads r ON r.announcement_id = a.id AND r.user_id = ?
    WHERE r.user_id IS NULL
    ORDER BY a.created DESC LIMIT 5
  `).all(user.id);
  res.json({ announcements: rows.map((a) => ({ id: a.id, title: a.title, body: a.body, created: a.created })) });
});

chatRouter.post('/announcements/read', (req, res) => {
  const user = requireUser(req, res);
  if (!user) return;
  db.prepare('INSERT OR IGNORE INTO announcement_reads (user_id, announcement_id) VALUES (?, ?)')
    .run(user.id, Number(req.body?.id));
  res.json({ ok: true });
});

chatRouter.get('/push', (req, res) => {
  if (!requireUser(req, res)) return;
  res.json({ supported: false, vapidPublicKey: null, reminders: [] });
});

chatRouter.post('/push/subscribe', (req, res) => {
  if (!requireUser(req, res)) return;
  res.json({ ok: true });
});

chatRouter.post('/push/unsubscribe', (req, res) => {
  if (!requireUser(req, res)) return;
  res.json({ ok: true });
});

chatRouter.post('/push/test', (req, res) => {
  if (!requireUser(req, res)) return;
  res.json({ ok: true });
});

chatRouter.post('/push/reminders/delete', (req, res) => {
  if (!requireUser(req, res)) return;
  res.json({ ok: true });
});

chatRouter.get('/sites', (req, res) => {
  if (!requireUser(req, res)) return;
  res.json({ sites: [] });
});

chatRouter.post('/sites/publish', (req, res) => {
  if (!requireUser(req, res)) return;
  res.status(400).json({ error: 'Sites-Publish ist in diesem Rebuild noch nicht aktiv.' });
});

chatRouter.post('/sites/unpublish', (req, res) => {
  if (!requireUser(req, res)) return;
  res.json({ ok: true });
});

chatRouter.get('/export', (req, res) => {
  const user = requireUser(req, res);
  if (!user) return;
  const chats = db.prepare('SELECT * FROM chats WHERE user_id = ?').all(user.id).map(serializeChat);
  res.json({ email: user.email, exportedAt: new Date().toISOString(), chats });
});

// Parametric routes last
chatRouter.get('/:id', (req, res) => {
  const user = requireUser(req, res);
  if (!user) return;
  const row = getChat(user.id, req.params.id);
  if (!row) return res.status(404).json({ error: 'Chat nicht gefunden.' });
  res.json(serializeChat(row));
});

chatRouter.delete('/:id', (req, res) => {
  const user = requireUser(req, res);
  if (!user) return;
  const row = getChat(user.id, req.params.id);
  if (!row) return res.status(404).json({ error: 'Chat nicht gefunden.' });
  db.prepare('DELETE FROM chats WHERE id = ?').run(row.id);
  res.json({ ok: true });
});

void cookieName;
