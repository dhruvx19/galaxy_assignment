import { v2 as cloudinary } from 'cloudinary';
import { Readable } from 'stream';


cloudinary.config({
  cloud_name: process.env.CLOUDINARY_CLOUD_NAME || '',
  api_key: process.env.CLOUDINARY_API_KEY || '',
  api_secret: process.env.CLOUDINARY_API_SECRET || '',
});

/**
 * 
 * @param buffer 
 * @param folder 
 * @returns 
 */
export const uploadImage = async (buffer: Buffer, folder = 'chat-images'): Promise<string> => {
  return new Promise((resolve, reject) => {
    const uploadStream = cloudinary.uploader.upload_stream(
      { folder },
      (error, result) => {
        if (error) return reject(error);
        if (!result) return reject(new Error('No result from Cloudinary'));
        resolve(result.secure_url);
      }
    );

    const stream = Readable.from(buffer);
    stream.pipe(uploadStream);
  });
};

/**
 * 
 * @param url 
 */
export const deleteImage = async (url: string): Promise<void> => {
  try {
    const urlParts = url.split('/');
    const filenamePart = urlParts[urlParts.length - 1];
    const publicId = filenamePart.split('.')[0];
  
    const folderIndex = urlParts.indexOf('upload') + 1;
    if (folderIndex < urlParts.length - 1) {
      const folder = urlParts.slice(folderIndex, urlParts.length - 1).join('/');
      await cloudinary.uploader.destroy(`${folder}/${publicId}`);
    } else {
      await cloudinary.uploader.destroy(publicId);
    }
  } catch (error) {
    console.error('Error deleting image from Cloudinary:', error);
    throw error;
  }
};