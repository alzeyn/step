import express from 'express';
import cors from 'cors';
import authRoutes from './routes/auth.js';
import progressRoutes from './routes/progress.js';
import teacherRoutes from './routes/teacher.js';

const app = express();
const PORT = 3001;

app.use(cors({ origin: ['http://localhost:5173', 'http://127.0.0.1:5173'] }));
app.use(express.json());

app.use('/api/auth',     authRoutes);
app.use('/api/progress', progressRoutes);
app.use('/api/teacher',  teacherRoutes);

app.get('/api/health', (_req, res) =>
  res.json({ status: 'ok', time: new Date().toISOString() })
);

app.listen(PORT, () => {
  console.log('');
  console.log('  🤖 STEP CODE — Backend');
  console.log(`  http://localhost:${PORT}`);
  console.log('');
  console.log('  База данных: stepcode.db (создаётся автоматически)');
  console.log('');
});
