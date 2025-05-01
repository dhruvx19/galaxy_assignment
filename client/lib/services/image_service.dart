import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:image_picker/image_picker.dart';

class ImageService {
  static const String baseUrl = 'https://galaxy-ai-assignment.onrender.com/api/v1'; 

  static Future<String?> uploadImage(File imageFile) async {
    try {
      final uri = Uri.parse('$baseUrl/upload');
      var request = http.MultipartRequest('POST', uri);
      
      var stream = http.ByteStream(imageFile.openRead());
      var length = await imageFile.length();
      var multipartFile = http.MultipartFile(
        'image',
        stream,
        length,
        filename: imageFile.path.split('/').last
      );
      request.files.add(multipartFile);

      var response = await request.send();
      var responseData = await response.stream.bytesToString();
      var jsonResponse = json.decode(responseData);

      if (response.statusCode == 200) {
        return jsonResponse['imageUrl'];
      }
      return null;
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }

  static Future<File?> pickImage({bool fromCamera = false}) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 80,
    );

    if (image != null) {
      return File(image.path);
    }
    return null;
  }
}
