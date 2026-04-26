import { Router } from 'express';
import db from '../db.js';

const router = Router();

function getUser(req) {
  const token = req.headers.authorization?.replace('Bearer ', '');
  if (!token) return null;
  const session = db.prepare('SELECT * FROM sessions WHERE token = ?').get(token);
  if (!session) return null;
  return db.prepare('SELECT * FROM users WHERE id = ?').get(session.user_id);
}

// GET /api/progress — load all progress for current user
router.get('/', (req, res) => {
  const user = getUser(req);
  if (!user) return res.status(401).json({ error: 'Unauthorized' });

  const rows = db.prepare('SELECT * FROM progress WHERE user_id = ?').all(user.id);

  // Convert to nested object: { topicId: { levelId: [bool, bool, bool] } }
  const progress = {};
  for (const row of rows) {
    if (!progress[row.topic_id]) progress[row.topic_id] = {};
    if (!progress[row.topic_id][row.level_id]) progress[row.topic_id][row.level_id] = [];
    progress[row.topic_id][row.level_id][row.task_idx] = true;
  }

  res.json(progress);
});

// POST /api/progress — save a completed task
router.post('/', (req, res) => {
  const user = getUser(req);
  if (!user) return res.status(401).json({ error: 'Unauthorized' });

  const { topicId, levelId, taskIdx, hintsUsed = 0 } = req.body;
  if (topicId === undefined || levelId === undefined || taskIdx === undefined)
    return res.status(400).json({ error: 'Missing fields' });

  db.prepare(`
    INSERT INTO progress (user_id, topic_id, level_id, task_idx, hints_used)
    VALUES (?, ?, ?, ?, ?)
    ON CONFLICT(user_id, topic_id, level_id, task_idx)
    DO UPDATE SET hints_used = excluded.hints_used
  `).run(user.id, topicId, levelId, taskIdx, hintsUsed);

  res.json({ ok: true });
});

export default router;
