import { Request, Response } from "express";
import { Groq } from "groq-sdk";
import { uploadImage } from '../services/cloudnaryServices';
import multer from "multer";


const storage = multer.memoryStorage();
const upload = multer({ 
  storage,
  limits: { fileSize: 10 * 1024 * 1024 } 
});

export const uploadMiddleware = upload.single('image');
export const generateGroqResponsesController = async (
  req: Request,
  res: Response
): Promise<void> => {
  try {
    let { 
      messages, 
      model = "llama3-70b-8192", 
      sessionId, 
      userId,
      title
    } = req.body;

    if (!messages || !Array.isArray(messages)) {
      res.status(400).json({ error: "Messages are required and must be an array" });
      return;
    }
    
    if (!userId) {
      userId = "default-test-user";
    }

    if (!sessionId) {
      sessionId = Date.now().toString(); 
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

    // Handle image upload if present in the request
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
        content: fullAssistantResponse
      };
      messages.push(assistantMessage);

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



