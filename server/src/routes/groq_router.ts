import { Router } from "express";
import { 
  generateGroqResponsesController, 
  uploadMiddleware
} from "../controllers/generate_response";


const groqRouter = Router();


groqRouter.post("/", uploadMiddleware, generateGroqResponsesController);

export default groqRouter;