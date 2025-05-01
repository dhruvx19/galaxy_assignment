import mongoose, { Document, Schema } from 'mongoose';

interface IMessage {
  role: 'user' | 'assistant';
  content: string;
  imageUrl?: string;
  timestamp: Date;
}


export interface IChat extends Document {
    sessionId: string;
    userId: string;
    title: string;
    messages: IMessage[];
    modelName: string; 
    createdAt: Date;
    updatedAt: Date;
  }
  

const MessageSchema = new Schema<IMessage>({
  role: { 
    type: String, 
    required: true, 
    enum: ['user', 'assistant'] 
  },
  content: { 
    type: String, 
    required: true 
  },
  imageUrl: { 
    type: String 
  },
  timestamp: { 
    type: Date, 
    default: Date.now 
  }
});

const ChatSchema = new Schema<IChat>({
    sessionId: { type: String, required: true, index: true },
    userId: { type: String, required: true, index: true },
    title: { type: String, default: 'New Chat' },
    messages: [MessageSchema],
    modelName: { type: String, default: 'llama3-70b-8192' }, 
    createdAt: { type: Date, default: Date.now },
    updatedAt: { type: Date, default: Date.now }
  });
  

ChatSchema.index({ sessionId: 1, userId: 1 }, { unique: true });

export default mongoose.model<IChat>('Chat', ChatSchema);