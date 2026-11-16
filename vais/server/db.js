import { DatabaseSync } from 'node:sqlite';
import fs from 'node:fs';
import path from 'node:path';

const dataDir = process.env.DATA_DIR || path.join(process.cwd(), 'data');
fs.mkdirSync(dataDir, { recursive: true });

const dbPath = process.env.SQLITE_PATH || path.join(dataDir, 'vais.db');
export const db = new DatabaseSync(dbPath);
db.exec('PRAGMA journal_mode = WAL; PRAGMA foreign_keys = ON;');

db.exec(`
CREATE TABLE IF NOT EXISTS users (
  id TEXT PRIMARY KEY,
  email TEXT NOT NULL UNIQUE COLLATE NOCASE,
  password_hash TEXT NOT NULL,
  verified INTEGER NOT NULL DEFAULT 0,
  admin INTEGER NOT NULL DEFAULT 0,
  mod INTEGER NOT NULL DEFAULT 0,
  blocked INTEGER NOT NULL DEFAULT 0,
  welcomed INTEGER NOT NULL DEFAULT 0,
  created INTEGER NOT NULL,
  instructions TEXT NOT NULL DEFAULT '',
  memory_on INTEGER NOT NULL DEFAULT 1,
  plan_first INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE IF NOT EXISTS sessions (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token TEXT NOT NULL UNIQUE,
  device TEXT NOT NULL DEFAULT 'Browser',
  created INTEGER NOT NULL,
  last_seen INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS auth_codes (
  id TEXT PRIMARY KEY,
  email TEXT NOT NULL COLLATE NOCASE,
  purpose TEXT NOT NULL,
  code TEXT NOT NULL,
  created INTEGER NOT NULL,
  expires INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS chats (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  mode TEXT NOT NULL,
  modality TEXT NOT NULL DEFAULT 'auto',
  title TEXT NOT NULL,
  labels_json TEXT NOT NULL,
  model_ids_json TEXT NOT NULL,
  winner TEXT,
  shared INTEGER NOT NULL DEFAULT 0,
  share_id TEXT,
  pinned INTEGER NOT NULL DEFAULT 0,
  folder TEXT,
  incognito INTEGER NOT NULL DEFAULT 0,
  created INTEGER NOT NULL,
  updated INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS turns (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  chat_id TEXT NOT NULL REFERENCES chats(id) ON DELETE CASCADE,
  turn_index INTEGER NOT NULL,
  user_text TEXT NOT NULL DEFAULT '',
  attachments_json TEXT NOT NULL DEFAULT '[]',
  UNIQUE(chat_id, turn_index)
);

CREATE TABLE IF NOT EXISTS answers (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  chat_id TEXT NOT NULL REFERENCES chats(id) ON DELETE CASCADE,
  turn_index INTEGER NOT NULL,
  side INTEGER NOT NULL,
  text TEXT NOT NULL DEFAULT '',
  status TEXT NOT NULL DEFAULT 'done',
  error TEXT,
  thinking TEXT NOT NULL DEFAULT '',
  think_ms INTEGER NOT NULL DEFAULT 0,
  images_json TEXT NOT NULL DEFAULT '[]',
  sources_json TEXT NOT NULL DEFAULT '[]',
  steps_json TEXT NOT NULL DEFAULT '[]',
  reaction TEXT,
  feedback INTEGER,
  reasons_json TEXT NOT NULL DEFAULT '[]',
  auto_json TEXT,
  build_ms INTEGER NOT NULL DEFAULT 0,
  UNIQUE(chat_id, turn_index, side)
);

CREATE TABLE IF NOT EXISTS memories (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  text TEXT NOT NULL,
  created INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS announcements (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  created INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS announcement_reads (
  user_id TEXT NOT NULL,
  announcement_id INTEGER NOT NULL,
  PRIMARY KEY (user_id, announcement_id)
);

CREATE TABLE IF NOT EXISTS votes (
  chat_id TEXT PRIMARY KEY,
  winner TEXT NOT NULL,
  created INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS feedback (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  chat_id TEXT NOT NULL,
  turn_index INTEGER NOT NULL,
  side INTEGER NOT NULL,
  value INTEGER NOT NULL,
  reasons_json TEXT NOT NULL DEFAULT '[]',
  created INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS shares (
  id TEXT PRIMARY KEY,
  chat_id TEXT NOT NULL UNIQUE,
  created INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_chats_user ON chats(user_id, updated DESC);
CREATE INDEX IF NOT EXISTS idx_sessions_token ON sessions(token);
CREATE INDEX IF NOT EXISTS idx_auth_codes_email ON auth_codes(email, purpose);
`);

export function now() {
  return Date.now();
}
