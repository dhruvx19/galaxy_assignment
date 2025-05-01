import 'dart:convert';
import 'dart:io';
import 'package:chatgpt_galaxy_assignment/features/chat/model/chat_model.dart';
import 'package:chatgpt_galaxy_assignment/features/chat/repo/chat_repo.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class ChatProvider extends ChangeNotifier {
  final ChatRepository _repository = ChatRepository();
  String _selectedModel = 'llama3-70b-8192';

  final List<String> _models = [
    'llama3-70b-8192',
    'llama3-8b-8192',
    'mixtral-8x7b-32768',
    'gemma-7b-it',
  ];
  List<ChatMessageModel> _messages = [];
  final String _userId = 'test-user-123';
  String? _currentSessionId;
  String _currentChatTitle = 'New Chat';
  GroupedChatHistory _chatHistory = GroupedChatHistory(
    today: [],
    yesterday: [],
    previousWeek: [],
    previousMonth: [],
    older: [],
  );

  bool _isLoading = false;
  bool _isStreaming = false;
  bool _isUploadingImage = false;
  bool _isLoadingHistory = false;
  String _currentStreamResponse = '';
  String get selectedModel => _selectedModel;
  List<String> get models => _models;
  List<ChatMessageModel> get messages => _messages;
  bool get isLoading => _isLoading;
  bool get isStreaming => _isStreaming;
  bool get isUploadingImage => _isUploadingImage;
  bool get isLoadingHistory => _isLoadingHistory;
  String get currentStreamResponse => _currentStreamResponse;
  String get userId => _userId;
  String? get currentSessionId => _currentSessionId;
  String get currentChatTitle => _currentChatTitle;
  GroupedChatHistory get chatHistory => _chatHistory;

  ChatProvider() {
    _loadSelectedModel();
    fetchChatHistory();
  }
  Future<void> _loadSelectedModel() async {
    final prefs = await SharedPreferences.getInstance();
    _selectedModel = prefs.getString('selectedModel') ?? 'llama3-70b-8192';
    notifyListeners();
  }

  Future<void> fetchChatHistory() async {
    _isLoadingHistory = true;
    notifyListeners();

    try {
      _chatHistory = await _repository.getChatHistory(_userId);
    } catch (e) {
      debugPrint('Error fetching chat history: $e');
    } finally {
      _isLoadingHistory = false;
      notifyListeners();
    }
  }

  Future<void> loadChatSession(String sessionId) async {
    if (sessionId == _currentSessionId && _messages.isNotEmpty) {
      return;
    }

    _isLoading = true;
    _messages = [];
    _currentSessionId = sessionId;
    notifyListeners();

    try {
      final chatData = await _repository.getChat(
        sessionId: sessionId,
        userId: _userId,
      );

      if (chatData.containsKey('chat')) {
        final chat = chatData['chat'];
        _currentChatTitle = chat['title'] ?? 'Chat';

        if (chat.containsKey('messages') && chat['messages'] is List) {
          _messages = (chat['messages'] as List)
              .map((msg) => ChatMessageModel.fromMap(msg))
              .toList();
        }

        if (chat.containsKey('model') && chat['model'] is String) {
          _selectedModel = chat['model'];
          await _saveSelectedModel(_selectedModel);
        }
      }
    } catch (e) {
      debugPrint('Error loading chat session: $e');
      _messages.add(ChatMessageModel(
        role: 'assistant',
        content:
            'Error: Unable to load this chat session. Please try again later.',
      ));
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _saveSelectedModel(String model) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedModel', model);
  }

  void changeModel(String model) {
    _selectedModel = model;
    _saveSelectedModel(model);
    notifyListeners();
  }

  String _deriveTitleFromFirstMessage(String content) {
    if (content.isEmpty) return 'New Chat';

    String title = '';
    if (content.contains('.')) {
      title = content.split('.').first;
    } else if (content.contains('?')) {
      title = content.split('?').first + '?';
    } else if (content.contains('!')) {
      title = content.split('!').first + '!';
    } else {
      title = content;
    }

    if (title.length > 40) {
      title = title.substring(0, 37) + '...';
    }

    return title;
  }

  Future<void> updateChatTitle(String title) async {
    if (_currentSessionId == null) return;

    try {
      final success = await _repository.updateChatTitle(
        sessionId: _currentSessionId!,
        title: title,
        userId: _userId,
      );

      if (success) {
        _currentChatTitle = title;
        await fetchChatHistory();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error updating chat title: $e');
    }
  }

  Future<void> deleteChat(String sessionId) async {
    try {
      final success = await _repository.deleteChat(
        sessionId: sessionId,
        userId: _userId,
      );

      if (success) {
        if (sessionId == _currentSessionId) {
          startNewChat();
        }
        await fetchChatHistory();
      }
    } catch (e) {
      debugPrint('Error deleting chat: $e');
    }
  }

  Future<void> startNewChat() async {
    _messages = [];
    _currentChatTitle = 'New Chat';

    try {
      final result = await _repository.createNewChat(
        userId: _userId,
        title: _currentChatTitle,
        model: _selectedModel,
      );

      if (result['success'] == true && result.containsKey('chat')) {
        _currentSessionId = result['chat']['sessionId'];
      } else {
        _currentSessionId =
            'chat-${DateTime.now().millisecondsSinceEpoch}-${_getRandomString(6)}';
      }

      await fetchChatHistory();
    } catch (e) {
      _currentSessionId =
          'chat-${DateTime.now().millisecondsSinceEpoch}-${_getRandomString(6)}';
      debugPrint('Error creating new chat: $e');
    }

    notifyListeners();
  }

  Future<void> sendMessage(String content, {File? imageFile}) async {
    if (content.trim().isEmpty && imageFile == null) return;

    try {
      if (_currentSessionId == null) {
        await startNewChat();
      }

      final userMessage = ChatMessageModel(
        role: 'user',
        content: content,
      );
      _messages.add(userMessage);
      notifyListeners();

      if (_messages.length == 1 && _currentChatTitle == 'New Chat') {
        _currentChatTitle = _deriveTitleFromFirstMessage(content);
        await updateChatTitle(_currentChatTitle);
      }

      _isStreaming = true;
      _currentStreamResponse = '';
      notifyListeners();
      final messageStream = _repository.getChatResponse(
        messages: _messages,
        model: _selectedModel,
        userId: _userId,
        sessionId: _currentSessionId!,
        imageFile: imageFile,
        title: _currentChatTitle,
      );

      await for (final response in messageStream) {
        if (response.statusCode == 200) {
          final line = response.body;

          if (line.startsWith('data: ')) {
            try {
              var jsonData = json.decode(line.substring(6));
              if (jsonData['data'] != null) {
                _currentStreamResponse += jsonData['data'];
                notifyListeners();
              }
            } catch (e) {
              debugPrint('Error parsing streaming response: $e');
            }
          }
        } else {
          debugPrint(
              'Error in stream response: ${response.statusCode} - ${response.body}');
        }
      }

      if (_currentStreamResponse.isNotEmpty) {
        _messages.add(ChatMessageModel(
          role: 'assistant',
          content: _currentStreamResponse,
        ));
        await fetchChatHistory();
      }
    } catch (e) {
      debugPrint('Error sending message: $e');
      _messages.add(ChatMessageModel(
        role: 'assistant',
        content: 'Error: Unable to get a response. Please try again later.',
      ));
    } finally {
      _isStreaming = false;
      _currentStreamResponse = '';
      notifyListeners();
    }
  }

  String _getRandomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = StringBuffer();
    for (var i = 0; i < length; i++) {
      random.write(chars[DateTime.now().microsecondsSinceEpoch % chars.length]);
    }
    return random.toString();
  }
}
