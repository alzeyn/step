import { Router } from 'express';
import { randomBytes } from 'crypto';
import db from '../db.js';

const router = Router();

// Join (register or login — no password, just name + class code)
router.post('/join', (req, res) => {
  const { name, classCode, role = 'student' } = req.body;
  if (!name?.trim() || !classCode?.trim())
    return res.status(400).json({ error: 'Заполни имя и код класса' });

  const safeName = name.trim();
  const safeCode = classCode.trim().toUpperCase();

  // Find or create user
  let user = db
    .prepare('SELECT * FROM users WHERE name = ? AND class_code = ?')
    .get(safeName, safeCode);

  if (!user) {
    const r = db
      .prepare('INSERT INTO users (name, role, class_code) VALUES (?, ?, ?)')
      .run(safeName, role, safeCode);
    user = db.prepare('SELECT * FROM users WHERE id = ?').get(r.lastInsertRowid);
  }

  // Create session token
  const token = randomBytes(32).toString('hex');
  db.prepare('INSERT INTO sessions (user_id, token) VALUES (?, ?)').run(user.id, token);

  res.json({
    token,
    user: { id: user.id, name: user.name, role: user.role, classCode: user.class_code },
  });
});

// Get current user from token
router.get('/me', (req, res) => {
  const token = req.headers.authorization?.replace('Bearer ', '');
  if (!token) return res.status(401).json({ error: 'No token' });

  const session = db.prepare('SELECT * FROM sessions WHERE token = ?').get(token);
  if (!session) return res.status(401).json({ error: 'Invalid token' });

  const user = db.prepare('SELECT * FROM users WHERE id = ?').get(session.user_id);
  res.json({ id: user.id, name: user.name, role: user.role, classCode: user.class_code });
});

// Logout
router.post('/logout', (req, res) => {
  const token = req.headers.authorization?.replace('Bearer ', '');
  if (token) db.prepare('DELETE FROM sessions WHERE token = ?').run(token);
  res.json({ ok: true });
});

export default router;
