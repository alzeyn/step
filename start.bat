import { Router } from 'express';
import db from '../db.js';

const router = Router();

function getTeacher(req) {
  const token = req.headers.authorization?.replace('Bearer ', '');
  if (!token) return null;
  const session = db.prepare('SELECT * FROM sessions WHERE token = ?').get(token);
  if (!session) return null;
  const user = db.prepare('SELECT * FROM users WHERE id = ?').get(session.user_id);
  return user?.role === 'teacher' ? user : null;
}

// GET /api/teacher/students — list all students in same class
router.get('/students', (req, res) => {
  const teacher = getTeacher(req);
  if (!teacher) return res.status(403).json({ error: 'Teacher only' });

  const students = db.prepare(`
    SELECT
      u.id, u.name, u.created_at,
      COUNT(DISTINCT p.id)      AS tasks_done,
      COALESCE(SUM(p.hints_used), 0) AS total_hints
    FROM users u
    LEFT JOIN progress p ON p.user_id = u.id
    WHERE u.class_code = ? AND u.role = 'student'
    GROUP BY u.id
    ORDER BY tasks_done DESC, u.name ASC
  `).all(teacher.class_code);

  res.json(students);
});

// GET /api/teacher/student/:id — detailed progress for one student
router.get('/student/:id', (req, res) => {
  const teacher = getTeacher(req);
  if (!teacher) return res.status(403).json({ error: 'Teacher only' });

  const student = db.prepare('SELECT * FROM users WHERE id = ? AND class_code = ?')
    .get(req.params.id, teacher.class_code);
  if (!student) return res.status(404).json({ error: 'Not found' });

  const progress = db.prepare('SELECT * FROM progress WHERE user_id = ? ORDER BY completed_at').all(student.id);
  res.json({ student, progress });
});

// GET /api/teacher/stats — task-level stats across the whole class
router.get('/stats', (req, res) => {
  const teacher = getTeacher(req);
  if (!teacher) return res.status(403).json({ error: 'Teacher only' });

  const taskStats = db.prepare(`
    SELECT
      p.topic_id, p.level_id, p.task_idx,
      COUNT(DISTINCT p.user_id)  AS completions,
      AVG(p.hints_used)          AS avg_hints
    FROM progress p
    JOIN users u ON u.id = p.user_id
    WHERE u.class_code = ?
    GROUP BY p.topic_id, p.level_id, p.task_idx
    ORDER BY p.topic_id, p.level_id, p.task_idx
  `).all(teacher.class_code);

  const { count: studentCount } = db.prepare(`
    SELECT COUNT(*) AS count FROM users
    WHERE class_code = ? AND role = 'student'
  `).get(teacher.class_code);

  const { total_tasks: totalCompleted } = db.prepare(`
    SELECT COALESCE(COUNT(*), 0) AS total_tasks
    FROM progress p
    JOIN users u ON u.id = p.user_id
    WHERE u.class_code = ?
  `).get(teacher.class_code);

  res.json({ taskStats, studentCount, totalCompleted });
});

export default router;
