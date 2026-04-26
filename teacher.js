import express from 'express';
import cors from 'cors';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import authRoutes     from './routes/auth.js';
import progressRoutes from './routes/progress.js';
import teacherRoutes  from './routes/teacher.js';

const app = express();
const PORT = process.env.PORT || 3001;
const __dirname = dirname(fileURLToPath(import.meta.url));

app.use(cors());
app.use(express.json());

// API routes
app.use('/api/auth',     authRoutes);
app.use('/api/progress', progressRoutes);
app.use('/api/teacher',  teacherRoutes);
app.get('/api/health', (_req, res) => res.json({ status: 'ok' }));

// Serve built React app (production)
const distPath = join(__dirname, '../dist');
app.use(express.static(distPath));
app.get('*', (_req, res) => {
  res.sendFile(join(distPath, 'index.html'));
});

app.listen(PORT, () => {
  console.log(`\n  🤖 STEP CODE running on port ${PORT}\n`);
});
