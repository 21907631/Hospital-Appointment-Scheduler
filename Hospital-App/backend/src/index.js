import express from 'express';
import cors from 'cors';
import 'dotenv/config';

import authRoutes from './routes/auth.routes.js';

const app = express();
const PORT = process.env.PORT || 3001;

// Middleware
app.use(cors({ origin: process.env.FRONTEND_URL || 'http://localhost:5173', credentials: true }));
app.use(express.json());

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok', service: 'hospital-scheduler-api', timestamp: new Date().toISOString() });
});

// Routes
app.use('/api/auth', authRoutes);
// app.use('/api/doctors', doctorRoutes);            // milestone 2
// app.use('/api/appointments', appointmentRoutes);  // milestone 2
// app.use('/api/admin', adminRoutes);               // milestone 3

// 404
app.use((req, res) => {
  res.status(404).json({ error: 'Not found' });
});

// Error handler
app.use((err, req, res, next) => {
  console.error(err);
  res.status(500).json({ error: 'Internal server error' });
});

app.listen(PORT, () => {
  console.log(`API listening on http://localhost:${PORT}`);
});
