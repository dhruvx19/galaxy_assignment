import 'dart:convert';

import 'package:intl/intl.dart';

class ChatMessageModel {
  final String role;
  final String content;
  final String? imageUrl;

  ChatMessageModel({
    required this.role,
    required this.content,
    this.imageUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'role': role,
      'content': content,
      if (imageUrl != null) 'imageUrl': imageUrl,
    };
  }

  factory ChatMessageModel.fromMap(Map<String, dynamic> map) {
    return ChatMessageModel(
      role: map['role'] ?? '',
      content: map['content'] ?? '',
      imageUrl: map['imageUrl'],
    );
  }

  String toJson() => json.encode(toMap());

  factory ChatMessageModel.fromJson(String source) =>
      ChatMessageModel.fromMap(json.decode(source));
}

class ChatHistoryModel {
  final String sessionId;
  final String title;
  final String model;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? latestMessage;

  ChatHistoryModel({
    required this.sessionId,
    required this.title,
    required this.model,
    required this.createdAt,
    required this.updatedAt,
    this.latestMessage,
  });

  factory ChatHistoryModel.fromMap(Map<String, dynamic> map) {
    return ChatHistoryModel(
      sessionId: map['sessionId'] ?? '',
      title: map['title'] ?? 'Untitled Chat',
      model: map['model'] ?? 'llama3-70b-8192',
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'])
          : DateTime.now(),
      latestMessage: map['message'] != null ? map['message']['content'] : null,
    );
  }
}

class GroupedChatHistory {
  final List<ChatHistoryModel> today;
  final List<ChatHistoryModel> yesterday;
  final List<ChatHistoryModel> previousWeek;
  final List<ChatHistoryModel> previousMonth;
  final List<ChatHistoryModel> older;

  GroupedChatHistory({
    required this.today,
    required this.yesterday,
    required this.previousWeek,
    required this.previousMonth,
    required this.older,
  });

  factory GroupedChatHistory.fromMap(Map<String, dynamic> map) {
    return GroupedChatHistory(
      today: List<ChatHistoryModel>.from(
          (map['today'] ?? []).map((x) => ChatHistoryModel.fromMap(x))),
      yesterday: List<ChatHistoryModel>.from(
          (map['yesterday'] ?? []).map((x) => ChatHistoryModel.fromMap(x))),
      previousWeek: List<ChatHistoryModel>.from(
          (map['previousWeek'] ?? []).map((x) => ChatHistoryModel.fromMap(x))),
      previousMonth: List<ChatHistoryModel>.from(
          (map['previousMonth'] ?? []).map((x) => ChatHistoryModel.fromMap(x))),
      older: List<ChatHistoryModel>.from(
          (map['older'] ?? []).map((x) => ChatHistoryModel.fromMap(x))),
    );
  }

  List<ChatHistoryModel> get allChats {
    return [
      ...today,
      ...yesterday,
      ...previousWeek,
      ...previousMonth,
      ...older
    ];
  }

  static String getFormattedDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final chatDate = DateTime(date.year, date.month, date.day);

    if (chatDate == today) {
      return 'Today';
    } else if (chatDate == yesterday) {
      return 'Yesterday';
    } else {
      return DateFormat('MMM d, yyyy').format(date);
    }
  }
}
