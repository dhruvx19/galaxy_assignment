import 'dart:convert';
import 'dart:io';
import 'package:chatgpt_galaxy_assignment/features/chat/model/chat_model.dart';
import 'package:chatgpt_galaxy_assignment/features/chat/provider/chat_provider.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  File? _selectedImage;
  bool _isDrawerOpen = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
  }

  void _clearSelectedImage() {
    setState(() {
      _selectedImage = null;
    });
  }

  Widget _buildWelcomeScreen() {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.chat_bubble_outline,
              size: 80,
              color: Colors.green,
            ),
            const SizedBox(height: 20),
            const Text(
              "Welcome to Groq",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: EdgeInsets.all(8),
              child: const Text(
                "Start a conversation by typing a message below",
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 30),
            Container(
              width: 300,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildExamplePrompt("Explain quantum computing"),
                  _buildExamplePrompt("Write a poem about AI"),
                  _buildExamplePrompt("How to learn Flutter?"),
                  _buildExamplePrompt("Upload an image and ask about it"),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExamplePrompt(String prompt) {
    return InkWell(
      onTap: () {
        _messageController.text = prompt;
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade700),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.chat, size: 16, color: Colors.grey),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                prompt,
                style: const TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: _buildChatHistoryDrawer(),
      body: Consumer<ChatProvider>(
        builder: (context, chatProvider, _) {
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _scrollToBottom());

          final screenWidth = MediaQuery.of(context).size.width;
          final isWideScreen = screenWidth > 900;

          return Row(
            children: [
              if (isWideScreen) _buildChatHistorySidebar(context, chatProvider),
              Expanded(
                child: Column(
                  children: [
                    _buildAppBar(context, chatProvider),
                    Expanded(
                      child: chatProvider.messages.isEmpty
                          ? _buildWelcomeScreen()
                          : _buildChatMessages(chatProvider),
                    ),
                    if (_selectedImage != null) _buildImagePreview(),
                    _buildMessageInput(chatProvider),
                    _buildFooter(),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, ChatProvider chatProvider) {
    final isWideScreen = MediaQuery.of(context).size.width > 900;

    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Groq",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          if (chatProvider.currentChatTitle != 'New Chat' &&
              chatProvider.messages.isNotEmpty)
            Text(
              chatProvider.currentChatTitle,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
        ],
      ),
      actions: [
        if (chatProvider.isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.0),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
        IconButton(
          icon: const Icon(Icons.add),
          tooltip: "New Chat",
          onPressed: () {
            chatProvider.startNewChat();
          },
        ),
        if (chatProvider.messages.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: "Clear Chat",
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text("Clear current chat?"),
                  content: const Text(
                      "This will remove all messages in the current conversation."),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("CANCEL"),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        chatProvider.startNewChat();
                      },
                      child: const Text("CLEAR"),
                    ),
                  ],
                ),
              );
            },
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade700),
            ),
            child: DropdownButton<String>(
              value: chatProvider.selectedModel,
              dropdownColor: Colors.grey[800],
              underline: Container(),
              icon: const Icon(Icons.arrow_drop_down, color: Colors.green),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  chatProvider.changeModel(newValue);
                }
              },
              items: chatProvider.models
                  .map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(
                    value,
                    style: const TextStyle(color: Colors.white),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
      leading: isWideScreen
          ? null
          : IconButton(
              icon: const Icon(Icons.menu),
              tooltip: "Chat History",
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            ),
    );
  }

  Widget _buildChatHistoryDrawer() {
    return Drawer(
      child: Consumer<ChatProvider>(
        builder: (context, chatProvider, _) {
          return _buildChatHistoryList(chatProvider, true);
        },
      ),
    );
  }

  Widget _buildChatHistorySidebar(
      BuildContext context, ChatProvider chatProvider) {
    return Container(
      width: 250,
      color: Colors.grey[900],
      child: _buildChatHistoryList(chatProvider, false),
    );
  }

  Widget _buildChatHistoryList(ChatProvider chatProvider, bool isDrawer) {
    return Column(
      children: [
        SizedBox(
          height: 20,
        ),
        Padding(
          padding: const EdgeInsets.all(30.0),
          child: ElevatedButton.icon(
            onPressed: () {
              chatProvider.startNewChat();
              if (isDrawer) {
                Navigator.pop(context);
              }
            },
            icon: const Icon(Icons.add),
            label: const Text("New Chat"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[800],
              minimumSize: const Size(double.infinity, 44),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(8.0),
          margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: Row(
            children: [
              const Icon(Icons.account_circle, color: Colors.white70),
              const SizedBox(width: 8.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Test User",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      chatProvider.userId,
                      style:
                          const TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: chatProvider.isLoadingHistory
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: () => chatProvider.fetchChatHistory(),
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    children: [
                      if (chatProvider.chatHistory.today.isNotEmpty) ...[
                        _buildHistorySection(
                            "Today",
                            chatProvider.chatHistory.today,
                            chatProvider,
                            isDrawer),
                      ],
                      if (chatProvider.chatHistory.yesterday.isNotEmpty) ...[
                        _buildHistorySection(
                            "Yesterday",
                            chatProvider.chatHistory.yesterday,
                            chatProvider,
                            isDrawer),
                      ],
                      if (chatProvider.chatHistory.previousWeek.isNotEmpty) ...[
                        _buildHistorySection(
                            "Previous 7 Days",
                            chatProvider.chatHistory.previousWeek,
                            chatProvider,
                            isDrawer),
                      ],
                      if (chatProvider
                          .chatHistory.previousMonth.isNotEmpty) ...[
                        _buildHistorySection(
                            "Previous 30 Days",
                            chatProvider.chatHistory.previousMonth,
                            chatProvider,
                            isDrawer),
                      ],
                      if (chatProvider.chatHistory.older.isNotEmpty) ...[
                        _buildHistorySection(
                            "Older",
                            chatProvider.chatHistory.older,
                            chatProvider,
                            isDrawer),
                      ],
                      if (chatProvider.chatHistory.allChats.isEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 20.0),
                          alignment: Alignment.center,
                          child: Column(
                            children: [
                              Icon(Icons.chat_bubble_outline,
                                  size: 48, color: Colors.grey[600]),
                              const SizedBox(height: 16),
                              Text(
                                "No chat history yet",
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildHistorySection(String title, List<ChatHistoryModel> chats,
      ChatProvider chatProvider, bool isDrawer) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
        ),
        ...chats
            .map((chat) => _buildChatHistoryItem(chat, chatProvider, isDrawer))
            .toList(),
        const Divider(color: Colors.grey),
      ],
    );
  }

  Widget _buildChatHistoryItem(
      ChatHistoryModel chat, ChatProvider chatProvider, bool isDrawer) {
    final isSelected = chatProvider.currentSessionId == chat.sessionId;

    return Container(
      margin: const EdgeInsets.only(bottom: 8.0),
      decoration: BoxDecoration(
        color: isSelected ? Colors.green.withOpacity(0.2) : Colors.transparent,
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        title: Text(
          chat.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: chat.latestMessage != null
            ? Text(
                chat.latestMessage!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: Colors.grey[400]),
              )
            : null,
        leading: Icon(
          isSelected ? Icons.chat : Icons.chat_bubble_outline,
          color: isSelected ? Colors.green : Colors.grey,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _formatDate(chat.updatedAt),
              style: TextStyle(fontSize: 10, color: Colors.grey[400]),
            ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: Colors.grey[400], size: 16),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'rename',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 16),
                      SizedBox(width: 8),
                      Text('Rename'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 16),
                      SizedBox(width: 8),
                      Text('Delete'),
                    ],
                  ),
                ),
              ],
              onSelected: (value) async {
                if (value == 'rename') {
                  _showRenameChatDialog(context, chat, chatProvider);
                } else if (value == 'delete') {
                  _showDeleteChatDialog(context, chat, chatProvider);
                }
              },
            ),
          ],
        ),
        onTap: () {
          if (!chatProvider.isLoading) {
            chatProvider.loadChatSession(chat.sessionId);

            if (isDrawer) {
              Navigator.pop(context);
            }

            if (_selectedImage != null) {
              _clearSelectedImage();
            }
          }
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final chatDate = DateTime(date.year, date.month, date.day);

    if (chatDate == today) {
      return DateFormat('h:mm a').format(date);
    } else {
      return DateFormat('MMM d').format(date);
    }
  }

  void _showRenameChatDialog(
      BuildContext context, ChatHistoryModel chat, ChatProvider chatProvider) {
    final TextEditingController titleController =
        TextEditingController(text: chat.title);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Rename Chat"),
        content: TextField(
          controller: titleController,
          decoration: const InputDecoration(
            hintText: "Enter new title",
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCEL"),
          ),
          TextButton(
            onPressed: () {
              final newTitle = titleController.text.trim();
              if (newTitle.isNotEmpty) {
                chatProvider.updateChatTitle(newTitle);
              }
              Navigator.pop(context);
            },
            child: const Text("SAVE"),
          ),
        ],
      ),
    );
  }

  void _showDeleteChatDialog(
      BuildContext context, ChatHistoryModel chat, ChatProvider chatProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Chat?"),
        content: Text("Are you sure you want to delete '${chat.title}'?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCEL"),
          ),
          TextButton(
            onPressed: () {
              chatProvider.deleteChat(chat.sessionId);
              Navigator.pop(context);
            },
            child: const Text("DELETE"),
          ),
        ],
      ),
    );
  }

  Widget _buildChatMessages(ChatProvider chatProvider) {
    if (chatProvider.isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text("Loading chat messages..."),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(top: 12),
      itemCount:
          chatProvider.messages.length + (chatProvider.isStreaming ? 1 : 0),
      itemBuilder: (context, index) {
        if (chatProvider.isStreaming && index == chatProvider.messages.length) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CircleAvatar(
                      backgroundColor: Colors.grey,
                      child: Icon(
                        Icons.smart_toy,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Assistant",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            chatProvider.currentStreamResponse,
                            style: const TextStyle(fontSize: 16),
                          ),
                          const Padding(
                            padding: EdgeInsets.only(top: 8.0),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }

        final message = chatProvider.messages[index];
        final bool isUserMessage = message.role == 'user';

        return Container(
          decoration: BoxDecoration(
            color: isUserMessage ? Colors.transparent : Colors.grey[800],
          ),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: isUserMessage ? Colors.green : Colors.grey,
                child: Icon(
                  isUserMessage ? Icons.person : Icons.smart_toy,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isUserMessage ? "You" : "Assistant",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (message.imageUrl != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            message.imageUrl!,
                            height: 200,
                            width: double.infinity,
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                height: 200,
                                width: double.infinity,
                                alignment: Alignment.center,
                                color: Colors.grey[800],
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes !=
                                          null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                height: 100,
                                width: double.infinity,
                                alignment: Alignment.center,
                                color: Colors.grey[800],
                                child: const Text('Error loading image'),
                              );
                            },
                          ),
                        ),
                      ),
                    SelectableText(
                      message.content,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildImagePreview() {
    return Container(
      padding: const EdgeInsets.all(8),
      height: 120,
      child: Stack(
        children: [
          Image.file(
            _selectedImage!,
            height: 100,
            width: 100,
            fit: BoxFit.cover,
          ),
          Positioned(
            right: 0,
            top: 0,
            child: IconButton(
              icon: const Icon(
                Icons.close,
                color: Colors.white,
                size: 20,
              ),
              onPressed: _clearSelectedImage,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput(ChatProvider chatProvider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(8),
      ),
      margin: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.image),
            onPressed: _pickImage,
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                hintText: "Ask anything...",
                border: InputBorder.none,
              ),
              maxLines: null,
              onSubmitted: (text) {
                if (text.trim().isNotEmpty || _selectedImage != null) {
                  chatProvider.sendMessage(text, imageFile: _selectedImage);
                  _messageController.clear();
                  _clearSelectedImage();
                }
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: () {
              if (_messageController.text.trim().isNotEmpty ||
                  _selectedImage != null) {
                chatProvider.sendMessage(_messageController.text,
                    imageFile: _selectedImage);
                _messageController.clear();
                _clearSelectedImage();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      color: Colors.black12,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Row(
              children: [
                Icon(Icons.bolt, size: 14, color: Colors.green),
                SizedBox(width: 4),
                Text(
                  "Powered by Groq API",
                  style: TextStyle(color: Colors.green),
                ),
              ],
            ),
          ),
          const Spacer(),
          Consumer<ChatProvider>(
            builder: (context, chatProvider, _) {
              return Text(
                "Model: ${chatProvider.selectedModel}",
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              );
            },
          ),
        ],
      ),
    );
  }
}
