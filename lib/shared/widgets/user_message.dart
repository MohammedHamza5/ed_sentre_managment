import 'package:flutter/material.dart';

/// Unified user message widget
/// مكون رسائل المستخدم الموحد

class UserMessage extends StatelessWidget {
  final String message;
  final MessageType type;
  final VoidCallback? onRetry;
  final Duration duration;

  const UserMessage({
    super.key,
    required this.message,
    this.type = MessageType.info,
    this.onRetry,
    this.duration = const Duration(seconds: 4),
  });

  @override
  Widget build(BuildContext context) {
    final color = _getColorByType(type);
    final icon = _getIconByType(type);

    return Card(
      margin: const EdgeInsets.all(8.0),
      color: color.withValues(alpha: 0.1),
      elevation: 2,
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(message, style: TextStyle(color: color)),
        trailing: onRetry != null
            ? TextButton(
                onPressed: onRetry,
                child: const Text('إعادة المحاولة'),
              )
            : null,
      ),
    );
  }

  Color _getColorByType(MessageType type) {
    switch (type) {
      case MessageType.success:
        return Colors.green;
      case MessageType.error:
        return Colors.red;
      case MessageType.warning:
        return Colors.orange;
      case MessageType.info:
        return Colors.blue;
    }
  }

  IconData _getIconByType(MessageType type) {
    switch (type) {
      case MessageType.success:
        return Icons.check_circle;
      case MessageType.error:
        return Icons.error;
      case MessageType.warning:
        return Icons.warning;
      case MessageType.info:
        return Icons.info;
    }
  }
}

enum MessageType { success, error, warning, info }


