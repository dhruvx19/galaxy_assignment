import { Request, Response } from "express";
import { Groq } from "groq-sdk";
import { uploadImage } from '../services/cloudnaryServices';
import multer from "multer";
import Chat, { IChat } from '../models/chat'


const storage = multer.memoryStorage();
const upload = multer({ 
  storage,
  limits: { fileSize: 10 * 1024 * 1024 } // 10MB limit
});

export const uploadMiddleware = upload.single('image');

const DEFAULT_TEST_USER = "test-user-123";


export const createNewChatController = async (
  req: Request,
  res: Response
): Promise<void> => {
  try {
    const { title = "New Chat", model = "llama3-70b-8192" } = req.body;
    const userId = req.body.userId || DEFAULT_TEST_USER;
    
    const sessionId = `chat-${Date.now()}-${Math.random().toString(36).substring(2, 9)}`;
    
    const newChat = new Chat({
      sessionId,
      userId,
      title,
      model,
      messages: [],
      createdAt: new Date(),
      updatedAt: new Date()
    });
    
    // Save the chat
    await newChat.save();
    
    res.status(201).json({ 
      success: true, 
      chat: {
        sessionId: newChat.sessionId,
        title: newChat.title,
        model: newChat.model,
        createdAt: newChat.createdAt,
        updatedAt: newChat.updatedAt
      }
    });
  } catch (error) {
    console.error('Error creating new chat:', error);
    res.status(500).json({ error: "Failed to create new chat" });
  }
};

export const generateGroqResponsesController = async (
  req: Request,
  res: Response
): Promise<void> => {
  try {
    let { 
      messages, 
      model = "llama3-70b-8192", 
      sessionId, 
      userId = DEFAULT_TEST_USER,
      title = "New Chat"
    } = req.body;

    if (!messages || !Array.isArray(messages)) {
      res.status(400).json({ error: "Messages are required and must be an array" });
      return;
    }
    if (!sessionId) {
      sessionId = Date.now().toString(); // simple sessionId using timestamp
    }
    
    const validModels = [
      "llama3-70b-8192",
      "llama3-8b-8192",
      "mixtral-8x7b-32768",
      "gemma-7b-it"
    ];
    
    if (!validModels.includes(model)) {
      res.status(400).json({ 
        error: "Invalid model specified", 
        validModels: validModels 
      });
      return;
    }

    if (req.file) {
      try {
        const imageUrl = await uploadImage(req.file.buffer);
        
        if (messages.length > 0 && messages[messages.length - 1].role === 'user') {
          messages[messages.length - 1].imageUrl = imageUrl;
        }
      } catch (error) {
        console.error('Error uploading image:', error);
        res.status(500).json({ error: 'Failed to upload image' });
        return;
      }
    }

  
    const groq = new Groq({
      apiKey: process.env.GROQ_API_KEY,
    });

    const apiMessages = messages.map(msg => {
      const apiMessage: any = {
        role: msg.role,
        content: msg.content
      };
      
      if (msg.imageUrl) {
        apiMessage.content += `\n\n[This message contains an image: ${msg.imageUrl}]`;
      }
      
      return apiMessage;
    });

    const apiParams = {
      model,
      messages: apiMessages,
      temperature: req.body.temperature || 1,
      max_tokens: req.body.max_tokens || 1024,
      top_p: req.body.top_p || 1,
      frequency_penalty: req.body.frequency_penalty || 0,
      presence_penalty: req.body.presence_penalty || 0,
      stream: true,
    };

    res.set({
      "Content-Type": "text/event-stream",
      "Cache-Control": "no-cache",
      "Connection": "keep-alive",
    });

    let fullAssistantResponse = '';

    try {
      const stream = await groq.chat.completions.create(apiParams) as unknown as AsyncIterable<{
        choices: Array<{ 
          delta: { 
            content: string | null 
          } 
        }>
      }>;

      for await (const chunk of stream) {
        const data = chunk.choices[0].delta.content || "";
        fullAssistantResponse += data;
        const formattedData = `data: ${JSON.stringify({ data })}\n\n`;
        res.write(formattedData);
      }

      const assistantMessage = {
        role: 'assistant',
        content: fullAssistantResponse,
        timestamp: new Date()
      };
      messages.push(assistantMessage);

      const messagesWithTimestamps = messages.map(msg => {
        if (!msg.timestamp) {
          return { ...msg, timestamp: new Date() };
        }
        return msg;
      });

      try {
        await Chat.findOneAndUpdate(
          { sessionId, userId },
          { 
            sessionId, 
            userId, 
            title, 
            messages: messagesWithTimestamps, 
            model,
            updatedAt: new Date()
          },
          { upsert: true, new: true } 
        );
      } catch (dbError) {
        console.error('Error saving chat to database:', dbError);
      }

      res.end();
    } catch (error) {
      console.error('Error streaming from Groq:', error);
      res.write(`data: ${JSON.stringify({ error: 'Error communicating with AI model' })}\n\n`);
      res.end();
    }
  } catch (error) {
    console.error('Error in Groq controller:', error);
    res.status(500).json({ error: "An error occurred while processing your request" });
  }
};

export const getUserChatsController = async (
  req: Request,
  res: Response
): Promise<void> => {
  try {
    const userId = req.params.userId || DEFAULT_TEST_USER;

    const chats: IChat[] = await Chat.find({ userId })
      .sort({ updatedAt: -1 })
      .select('sessionId title model createdAt updatedAt')
      .lean<IChat[]>();

    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const yesterday = new Date(today);
    yesterday.setDate(yesterday.getDate() - 1);

    const lastWeek = new Date(today);
    lastWeek.setDate(lastWeek.getDate() - 7);

    const lastMonth = new Date(today);
    lastMonth.setDate(lastMonth.getDate() - 30);

    const chatsByDate: {
      today: IChat[],
      yesterday: IChat[],
      previousWeek: IChat[],
      previousMonth: IChat[],
      older: IChat[]
    } = {
      today: [],
      yesterday: [],
      previousWeek: [],
      previousMonth: [],
      older: []
    };

    chats.forEach((chat: IChat) => {
      const chatDate = new Date(chat.updatedAt);
      chatDate.setHours(0, 0, 0, 0);

      if (chatDate.getTime() === today.getTime()) {
        chatsByDate.today.push(chat);
      } else if (chatDate.getTime() === yesterday.getTime()) {
        chatsByDate.yesterday.push(chat);
      } else if (chatDate >= lastWeek) {
        chatsByDate.previousWeek.push(chat);
      } else if (chatDate >= lastMonth) {
        chatsByDate.previousMonth.push(chat);
      } else {
        chatsByDate.older.push(chat);
      }
    });

    res.status(200).json({
      chats: chatsByDate,
      allChats: chats
    });
  } catch (error) {
    console.error('Error retrieving user chats:', error);
    res.status(500).json({ error: 'Failed to retrieve chats' });
  }
};


export const getChatByIdController = async (
  req: Request, 
  res: Response
): Promise<void> => {
  try {
    const { sessionId } = req.params;
    const userId = req.query.userId as string || DEFAULT_TEST_USER;
    
    if (!sessionId) {
      res.status(400).json({ error: "Session ID is required" });
      return;
    }
    
    const chat = await Chat.findOne({ sessionId, userId });
    
    if (!chat) {
      res.status(404).json({ error: "Chat not found" });
      return;
    }
    
    res.status(200).json({ chat });
  } catch (error) {
    console.error('Error retrieving chat:', error);
    res.status(500).json({ error: "Failed to retrieve chat" });
  }
};


export const uploadImageController = async (
  req: Request,
  res: Response
): Promise<void> => {
  try {
    if (!req.file) {
      res.status(400).json({ error: 'No image file provided' });
      return;
    }

    const imageUrl = await uploadImage(req.file.buffer);

    res.status(200).json({ imageUrl });
  } catch (error) {
    console.error('Error uploading image:', error);
    res.status(500).json({ error: 'Failed to upload image' });
  }
};

export const updateChatTitleController = async (
  req: Request,
  res: Response
): Promise<void> => {
  try {
    const { sessionId } = req.params;
    const { title } = req.body;
    const userId = req.body.userId || DEFAULT_TEST_USER;
    
    if (!sessionId) {
      res.status(400).json({ error: "Session ID is required" });
      return;
    }
    
    if (!title || typeof title !== 'string') {
      res.status(400).json({ error: "Title is required and must be a string" });
      return;
    }
    
    const updatedChat = await Chat.findOneAndUpdate(
      { sessionId, userId },
      { title, updatedAt: new Date() },
      { new: true }
    );
    
    if (!updatedChat) {
      res.status(404).json({ error: "Chat not found" });
      return;
    }
    
    res.status(200).json({ success: true, chat: updatedChat });
  } catch (error) {
    console.error('Error updating chat title:', error);
    res.status(500).json({ error: "Failed to update chat title" });
  }
};


export const deleteChatController = async (
  req: Request,
  res: Response
): Promise<void> => {
  try {
    const { sessionId } = req.params;
    const userId = req.query.userId as string || DEFAULT_TEST_USER;
    
    if (!sessionId) {
      res.status(400).json({ error: "Session ID is required" });
      return;
    }
    
    // Find and delete the chat
    const result = await Chat.deleteOne({ sessionId, userId });
    
    if (result.deletedCount === 0) {
      res.status(404).json({ error: "Chat not found" });
      return;
    }
    
    res.status(200).json({ success: true, message: "Chat deleted successfully" });
  } catch (error) {
    console.error('Error deleting chat:', error);
    res.status(500).json({ error: "Failed to delete chat" });
  }
};


export const getLatestMessagesController = async (
  req: Request,
  res: Response
): Promise<void> => {
  try {
    const userId = req.params.userId || DEFAULT_TEST_USER;
    const limit = parseInt(req.query.limit as string) || 5;
    
    const latestChats = await Chat.find({ userId })
      .sort({ updatedAt: -1 })
      .limit(limit);
    
    const latestMessages = latestChats.map(chat => {
      const lastMessage = chat.messages[chat.messages.length - 1];
      return {
        sessionId: chat.sessionId,
        title: chat.title,
        message: lastMessage ? {
          role: lastMessage.role,
          content: lastMessage.content.substring(0, 100) + (lastMessage.content.length > 100 ? '...' : ''),
          timestamp: lastMessage.timestamp
        } : null,
        updatedAt: chat.updatedAt
      };
    });
    
    res.status(200).json({ latestMessages });
  } catch (error) {
    console.error('Error retrieving latest messages:', error);
    res.status(500).json({ error: "Failed to retrieve latest messages" });
  }
};