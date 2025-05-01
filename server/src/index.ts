import express, { Express } from "express";
import http from 'http';
import cors from 'cors';
import dotenv from "dotenv";
import bodyParser from 'body-parser';
import router from "./routes/routes";
import groqRouter from "./routes/groq_router";
import uploadRouter from "./routes/upload_router";
import { connectDB } from "./db"; 

dotenv.config();

connectDB();

const app: Express = express();
const server = http.createServer(app);
app.use(cors({
  origin: '*', 
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With'],
  credentials: true,
  maxAge: 86400 
}));

app.use(bodyParser.json({ limit: '50mb' })); 
app.use(bodyParser.urlencoded({ extended: true, limit: '50mb' }));

const PORT = process.env.PORT || 3000;

app.use("/api/v1", router);
app.use("/", uploadRouter);

app.get('/health', (req, res) => {
  res.status(200).send('OK');
});

try {
  server.listen(PORT, (): void => {
    console.log(`Server is running on port ${PORT}`);
  });
} catch (error) {
  console.log("Server error:", error);
}

export default server;