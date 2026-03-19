enum MessageSender { user, ai }

class ChatMessage {
  final MessageSender sender;
  final String text;
  final List<String> sources;
  final DateTime timestamp;

  ChatMessage({
    required this.sender,
    required this.text,
    this.sources = const [],
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  bool get isAI => sender == MessageSender.ai;
  bool get isUser => sender == MessageSender.user;
}
