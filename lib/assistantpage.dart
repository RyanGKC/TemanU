import 'dart:ui';
import 'package:flutter/material.dart';

class ChatMessage {
  final String text;
  final bool isUser;

  ChatMessage({required this.text, required this.isUser});
}

class AssistantPage extends StatefulWidget {
  // ADDED: An optional function to handle tab navigation
  final VoidCallback? onBackTabPressed;

  const AssistantPage({super.key, this.onBackTabPressed});

  @override
  State<AssistantPage> createState() => _AssistantPageState();
}

class _AssistantPageState extends State<AssistantPage> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  final List<ChatMessage> _messages = [
    ChatMessage(
      text: "Hi James! I'm your health assistant. What can I help you with today?", 
      isUser: false
    )
  ];
  
  bool _isTyping = false;

  void _handleSubmitted(String text) async {
    if (text.trim().isEmpty) return;

    _textController.clear();
    
    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _isTyping = true;
    });
    
    _scrollToBottom();

    await Future.delayed(const Duration(seconds: 2));

    setState(() {
      _isTyping = false;
      _messages.add(ChatMessage(
        text: "That's a great question! I am a simulated AI right now, but once you connect me to an API, I'll be able to give you real insights about your health data.", 
        isUser: false
      ));
    });

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
        backgroundColor: const Color(0xff040F31), 
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            onPressed: () {
              FocusScope.of(context).unfocus();
              
              // NEW LOGIC: If it's a tab, switch back to home. Otherwise, pop the page!
              if (widget.onBackTabPressed != null) {
                widget.onBackTabPressed!();
              } else {
                Navigator.maybePop(context);
              }
            },
          ),
          title: const Text(
            'AI Assistant',
            style: TextStyle(fontSize: 25, fontWeight: FontWeight.w600, color: Color(0xff00E5FF))
          ),
          flexibleSpace: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
              child: Container(color: Colors.white.withValues(alpha: 0.25)),
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
          color: isUser ? const Color(0xff00E5FF) : const Color(0xff1A3F6B),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: isUser ? const Radius.circular(20) : const Radius.circular(0),
            bottomRight: isUser ? const Radius.circular(0) : const Radius.circular(20),
          ),
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: isUser ? const Color(0xff040F31) : Colors.white, 
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Padding(
      padding: const EdgeInsets.only(left: 15, right: 15, bottom: 10, top: 10), 
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20), 
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1), 
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2), 
                width: 1.5
              ), 
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end, 
              children: [
                // THE PLUS BUTTON
                Padding(
                  // FIXED: Changed bottom to 4.0 for perfect mathematical centering
                  padding: const EdgeInsets.only(bottom: 4.0, left: 6.0),
                  child: IconButton(
                    icon: const Icon(Icons.add, color: Color(0xff00E5FF), size: 28),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 40, minHeight: 40), 
                    onPressed: () {
                      FocusScope.of(context).unfocus(); 
                      print("Plus button pressed");
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
                      // The vertical: 14 here dictates the overall height (approx 48px)
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                    ),
                  ),
                ),
                
                // THE SEND BUTTON
                Padding(
                  // FIXED: Changed bottom to 4.0 for perfect mathematical centering
                  padding: const EdgeInsets.only(bottom: 4.0, right: 6.0, left: 4.0),
                  child: GestureDetector(
                    onTap: () => _handleSubmitted(_textController.text),
                    child: Container(
                      height: 40,
                      width: 40,
                      child: const Icon(
                        Icons.send, 
                        color: Color(0xff00E5FF), 
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
    );
  }
}