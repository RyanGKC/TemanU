import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:temanu/theme.dart';
import 'package:temanu/api_service.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final XFile? image;

  ChatMessage({required this.text, required this.isUser, this.image});
}

class AssistantPage extends StatefulWidget {
  final VoidCallback? onBackTabPressed;
  final Map<String, dynamic> userData;

  const AssistantPage({
    super.key, 
    this.onBackTabPressed, 
    this.userData = const {}, 
  });

  @override
  State<AssistantPage> createState() => _AssistantPageState();
}

class _AssistantPageState extends State<AssistantPage> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker(); // Image picker instance
  
  XFile? _selectedImage; // State to hold the currently selected image

  late final List<ChatMessage> _messages = [
    ChatMessage(
      text: "Hi ${widget.userData['name'] ?? 'there'}! I'm your health assistant. What can I help you with today?", 
      isUser: false
    )
  ];
  
  bool _isTyping = false;
  List<Map<String, String>> _chatHistory = [];

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          _selectedImage = pickedFile;
        });
      }
    } catch (e) {
      debugPrint("Failed to pick image: $e");
    }
  }

  void _handleSubmitted() async {
    final text = _textController.text.trim();
    
    // Don't send if text is empty
    if (text.isEmpty) return;

    _textController.clear();
    
    setState(() {
      _selectedImage = null; // Clear preview
      _messages.add(ChatMessage(text: text, isUser: true));
      _isTyping = true;
    });
    
    _scrollToBottom();

    // Add to history before sending
    _chatHistory.add({"role": "user", "content": text});

    try {
      final reply = await ApiService.sendChatMessage(text, _chatHistory);

      if (reply != null) {
        // Add AI reply to history
        _chatHistory.add({"role": "assistant", "content": reply});
        setState(() {
          _isTyping = false;
          _messages.add(ChatMessage(text: reply, isUser: false));
        });
      } else {
        throw Exception("No reply from server");
      }
    } catch (e) {
      setState(() {
        _isTyping = false;
        _messages.add(ChatMessage(
          text: "Sorry, I had trouble connecting. Please try again.", 
          isUser: false
        ));
      });
      debugPrint('Chat error: $e');
    }

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: AppTheme.background, 
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: AppTheme.secondaryColor),
            onPressed: () {
              FocusScope.of(context).unfocus();
              if (widget.onBackTabPressed != null) {
                widget.onBackTabPressed!();
              } else {
                Navigator.maybePop(context);
              }
            },
          ),
          title: const Text(
            'AI Assistant',
            style: TextStyle(fontSize: 25, fontWeight: FontWeight.w600, color: AppTheme.secondaryColor)
          ),
          flexibleSpace: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
              child: Container(color: AppTheme.background.withValues(alpha: 0.5)),
            ),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(20.0),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    return _buildChatBubble(_messages[index]);
                  },
                ),
              ),
              
              if (_isTyping)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8.0, left: 20.0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Assistant is typing...",
                      style: TextStyle(
                        color: Colors.white54, 
                        fontStyle: FontStyle.italic
                      ),
                    ),
                  ),
                ),
                
              _buildMessageInput(),
              const SizedBox(height: 10), 
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatBubble(ChatMessage message) {
    bool isUser = message.isUser;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75, 
        ),
        decoration: BoxDecoration(
          color: isUser ? AppTheme.primaryColor : AppTheme.cardBackground,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: isUser ? const Radius.circular(20) : const Radius.circular(0),
            bottomRight: isUser ? const Radius.circular(0) : const Radius.circular(20),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Display Image if it exists
            if (message.image != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: kIsWeb
                      ? Image.network(message.image!.path, fit: BoxFit.cover)
                      : Image.file(File(message.image!.path), fit: BoxFit.cover),
                ),
              ),
            
            // Display Text if it's not empty
            if (message.text.isNotEmpty)
              MarkdownBody(
                data: message.text,
                styleSheet: MarkdownStyleSheet(
                  // Default text style (paragraphs)
                  p: TextStyle(
                    color: isUser ? AppTheme.textPrimary : Colors.white, 
                    fontSize: 16,
                  ),
                  // Bold text style (strong)
                  strong: TextStyle(
                    color: isUser ? AppTheme.textPrimary : Colors.white, 
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  // List item styles
                  listBullet: TextStyle(
                    color: isUser ? AppTheme.textPrimary : Colors.white,
                    fontSize: 16,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Padding(
      padding: const EdgeInsets.only(left: 15, right: 15, bottom: 10, top: 10), 
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // IMAGE PREVIEW AREA
          if (_selectedImage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10, left: 10),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    height: 80,
                    width: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: AppTheme.primaryColor, width: 2),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(13),
                      child: kIsWeb
                          ? Image.network(_selectedImage!.path, fit: BoxFit.cover)
                          : Image.file(File(_selectedImage!.path), fit: BoxFit.cover),
                    ),
                  ),
                  Positioned(
                    top: -8,
                    right: -8,
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedImage = null),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, color: Colors.white, size: 14),
                      ),
                    ),
                  )
                ],
              ),
            ),
            
          // TEXT INPUT BAR
          ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20), 
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1), 
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2), 
                    width: 1.5
                  ), 
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end, 
                  children: [
                    // THE PLUS BUTTON (Now wires up to Image Picker)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4.0, left: 6.0),
                      child: IconButton(
                        icon: const Icon(Icons.add_photo_alternate_outlined, color: AppTheme.primaryColor, size: 26),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 40, minHeight: 40), 
                        onPressed: () {
                          FocusScope.of(context).unfocus(); 
                          _pickImage();
                        },
                      ),
                    ),
                    
                    // THE TEXT FIELD 
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        minLines: 1, 
                        maxLines: 5, 
                        keyboardType: TextInputType.multiline, 
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: "Message...",
                          hintStyle: TextStyle(color: Colors.white54),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: true,
                          fillColor: Colors.transparent,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                        ),
                      ),
                    ),
                    
                    // THE SEND BUTTON
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4.0, right: 6.0, left: 4.0),
                      child: GestureDetector(
                        onTap: _handleSubmitted,
                        child: const SizedBox(
                          height: 40,
                          width: 40,
                          child: Icon(
                            Icons.send, 
                            color: AppTheme.primaryColor, 
                            size: 18
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}