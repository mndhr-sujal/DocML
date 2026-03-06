import 'package:flutter/material.dart';

class RightChat extends StatefulWidget {
  const RightChat({super.key});

  @override
  State<RightChat> createState() => _RightChatState();
}

class _RightChatState extends State<RightChat> {
  final List<Map<String, String>> _messages = [
    {'sender': 'AI', 'message': 'Hello! I am currently under development.'},
  ];
  final TextEditingController _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      color: Color.fromARGB(255, 241, 233, 253),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            color: Color.fromARGB(255, 241, 233, 253),
            child: const Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blue,
                  child: Icon(Icons.chat, color: Colors.white),
                ),
                SizedBox(width: 12),
                Text(
                  'Doc Assistant',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          // Messages
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isAI = message['sender'] == 'AI';
                return Align(
                  alignment: isAI ? Alignment.centerLeft : Alignment.centerRight,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isAI ? Colors.blue[100] : Colors.green[100],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(message['message']!),
                  ),
                );
              },
            ),
          ),
          // Input
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color.fromARGB(255, 241, 233, 253),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(24)),
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () {
                    if (_controller.text.isNotEmpty) {
                      setState(() {
                        _messages.add({'sender': 'User', 'message': _controller.text});
                        _controller.clear();
                        // Simulate AI response
                        Future.delayed(const Duration(seconds: 1), () {
                          setState(() {
                            _messages.add({'sender': 'AI', 'message': 'That\'s a great question! I\'m still learning.'});
                          });
                        });
                      });
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}