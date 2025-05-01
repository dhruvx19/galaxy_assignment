"use strict";
var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.deleteImage = exports.uploadImage = void 0;
// services/cloudinaryService.ts
const cloudinary_1 = require("cloudinary");
const stream_1 = require("stream");
// Configure Cloudinary
cloudinary_1.v2.config({
    cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
    api_key: process.env.CLOUDINARY_API_KEY,
    api_secret: process.env.CLOUDINARY_API_SECRET,
});
/**
 * Uploads an image buffer to Cloudinary
 * @param buffer - The image buffer
 * @param folder - The folder to upload to in Cloudinary
 * @returns The Cloudinary image URL
 */
const uploadImage = (buffer_1, ...args_1) => __awaiter(void 0, [buffer_1, ...args_1], void 0, function* (buffer, folder = 'chat-images') {
    return new Promise((resolve, reject) => {
        const uploadStream = cloudinary_1.v2.uploader.upload_stream({ folder }, (error, result) => {
            if (error)
                return reject(error);
            if (!result)
                return reject(new Error('No result from Cloudinary'));
            resolve(result.secure_url);
        });
        // Convert buffer to stream and pipe to Cloudinary
        const stream = stream_1.Readable.from(buffer);
        stream.pipe(uploadStream);
    });
});
exports.uploadImage = uploadImage;
/**
 * Deletes an image from Cloudinary
 * @param url - The Cloudinary URL of the image to delete
 */
const deleteImage = (url) => __awaiter(void 0, void 0, void 0, function* () {
    var _a;
    // Extract the public_id from the URL
    const publicId = (_a = url.split('/').pop()) === null || _a === void 0 ? void 0 : _a.split('.')[0];
    if (!publicId)
        throw new Error('Invalid Cloudinary URL');
    yield cloudinary_1.v2.uploader.destroy(publicId);
});
exports.deleteImage = deleteImage;
