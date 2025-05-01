import 'dart:convert';
import 'dart:io';
import 'package:chatgpt_galaxy_assignment/features/chat/model/chat_model.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter/material.dart';

class ChatRepository {
  final String apiBaseUrl = 'https://galaxy-ai-assignment.onrender.com/api/v1';

  Future<String?> uploadImage(File imageFile) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$apiBaseUrl/upload'),
      );

      String fileExtension = imageFile.path.split('.').last.toLowerCase();
      String mimeType;

      switch (fileExtension) {
        case 'jpg':
        case 'jpeg':
          mimeType = 'image/jpeg';
          break;
        case 'png':
          mimeType = 'image/png';
          break;
        case 'gif':
          mimeType = 'image/gif';
          break;
        default:
          mimeType = 'image/jpeg';
      }

      request.files.add(
        await http.MultipartFile.fromPath(
          'image',
          imageFile.path,
          contentType: MediaType.parse(mimeType),
        ),
      );

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        Map<String, dynamic> responseData = json.decode(response.body);
        return responseData['imageUrl'];
      } else {
        throw Exception(
            'Failed to upload image. Status: ${response.statusCode}');
      }
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }

  Stream<http.Response> getChatResponse({
    required List<ChatMessageModel> messages,
    required String model,
    required String userId,
    required String sessionId,
    File? imageFile,
    String? title,
  }) async* {
    final client = http.Client();
    String? imageUrl;

    try {
      if (imageFile != null) {
        imageUrl = await uploadImage(imageFile);
        if (imageUrl != null &&
            messages.isNotEmpty &&
            messages.last.role == 'user') {
          int lastIndex = messages.length - 1;
          messages[lastIndex] = ChatMessageModel(
            role: messages[lastIndex].role,
            content: messages[lastIndex].content,
            imageUrl: imageUrl,
          );
        }
      }

      final requestBody = {
        "model": model,
        "messages": messages.map((e) => e.toMap()).toList(),
        "userId": userId,
        "sessionId": sessionId,
      };
      if (title != null && title.isNotEmpty) {
        requestBody["title"] = title;
      }
      final request = http.Request(
        "POST",
        Uri.parse("$apiBaseUrl/generate_response"),
      )
        ..headers.addAll({
          "Accept": "text/event-stream",
          "Cache-Control": "no-cache",
          "Content-Type": "application/json",
        })
        ..body = jsonEncode(requestBody);

      final streamedResponse = await client.send(request);

      if (streamedResponse.statusCode != 200) {
        yield http.Response(
            jsonEncode({
              "error":
                  "Server returned status code: ${streamedResponse.statusCode}"
            }),
            streamedResponse.statusCode);
        return;
      }

      var stream = streamedResponse.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      await for (var line in stream) {
        if (line.trim().isEmpty) continue;

        if (line.startsWith('data: ')) {
          yield http.Response(line, 200);
        } else {
          yield http.Response(jsonEncode({"error": "Invalid SSE format"}), 400);
        }
      }
    } catch (e) {
      print('Error in chat stream: $e');
      yield http.Response(jsonEncode({"error": e.toString()}), 500);
    } finally {
      client.close();
    }
  }

  Future<Map<String, dynamic>> createNewChat({
    required String userId,
    String? title,
    String? model,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/chat/new'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          if (title != null) 'title': title,
          if (model != null) 'model': model,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to create chat: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error creating chat: $e');
      throw Exception('Failed to create chat: $e');
    }
  }

  Future<bool> updateChatTitle({
    required String sessionId,
    required String title,
    required String userId,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$apiBaseUrl/chat/$sessionId/title'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'title': title,
          'userId': userId,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error updating chat title: $e');
      return false;
    }
  }

  Future<bool> deleteChat({
    required String sessionId,
    required String userId,
  }) async {
    try {
      final response = await http.delete(
        Uri.parse('$apiBaseUrl/chat/$sessionId?userId=$userId'),
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error deleting chat: $e');
      return false;
    }
  }

  Future<GroupedChatHistory> getChatHistory(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/chats/$userId'),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return GroupedChatHistory.fromMap(data['chats']);
      } else {
        throw Exception('Failed to load chat history');
      }
    } catch (e) {
      debugPrint('Error fetching chat history: $e');
      return GroupedChatHistory(
        today: [],
        yesterday: [],
        previousWeek: [],
        previousMonth: [],
        older: [],
      );
    }
  }

  /// Fetches latest messages for a user
  Future<List<ChatHistoryModel>> getLatestMessages(String userId,
      {int limit = 5}) async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/latest-messages/$userId?limit=$limit'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return (data['latestMessages'] as List)
            .map((x) => ChatHistoryModel.fromMap(x))
            .toList();
      } else {
        throw Exception('Failed to load latest messages');
      }
    } catch (e) {
      debugPrint('Error fetching latest messages: $e');
      return [];
    }
  }

  /// Fetches a specific chat session
  Future<Map<String, dynamic>> getChat({
    required String sessionId,
    required String userId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/chat/$sessionId?userId=$userId'),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load chat: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching chat: $e');
      throw Exception('Failed to fetch chat: $e');
    }
  }
}
