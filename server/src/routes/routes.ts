
import { Router } from "express";
import { 
  generateGroqResponsesController, 
  getUserChatsController,
  getChatByIdController,
  uploadImageController,
  updateChatTitleController,
  deleteChatController,
  getLatestMessagesController,
  createNewChatController,
  uploadMiddleware 
} from "../controllers/chat_controller";

const router = Router();

router.post("/chat/new", createNewChatController);
router.post("/generate_response", uploadMiddleware, generateGroqResponsesController);

router.get("/chats/:userId", getUserChatsController);
router.get("/chat/:sessionId", getChatByIdController);
router.get("/latest-messages/:userId", getLatestMessagesController);

router.put("/chat/:sessionId/title", updateChatTitleController);
router.delete("/chat/:sessionId", deleteChatController);

router.post("/upload", uploadMiddleware, uploadImageController);

router.get('/health', (req, res) => {
  res.status(200).send('OK');
});

export default router;