import { Request, Response } from 'express';
import { uploadImage } from '../services/cloudnaryServices';

/**

 * @param req 
 * @param res 
 */
export const uploadImageController = async (req: Request, res: Response): Promise<void> => {
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