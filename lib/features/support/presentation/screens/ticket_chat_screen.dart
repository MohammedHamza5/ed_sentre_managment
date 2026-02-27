import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' as intl; 
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../data/repositories/support_repository.dart';
import '../../../../core/supabase/supabase_client.dart';

class TicketChatScreen extends StatefulWidget {
  final String ticketId;

  const TicketChatScreen({super.key, required this.ticketId});

  @override
  State<TicketChatScreen> createState() => _TicketChatScreenState();
}

class _TicketChatScreenState extends State<TicketChatScreen> {
  final _repository = SupportRepository();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  
  bool _isLoading = true;
  bool _isSending = false;
  Map<String, dynamic>? _ticketDetails;
  List<dynamic> _messages = [];

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    setState(() => _isLoading = true);
    try {
      final details = await _repository.getTicketDetails(widget.ticketId);
      if (mounted) {
        setState(() {
          _ticketDetails = details;
          _messages = (details['messages'] as List?) ?? [];
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل في جلب التفاصيل: $e')),
        );
      }
    }
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

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);

    try {
      await _repository.addTicketReply(
        ticketId: widget.ticketId,
        message: text,
      );

      _messageController.clear();
      // Optimistic update or refresh
      await _fetchDetails();
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل الإرسال: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: Text(_ticketDetails?['subject'] ?? 'المحادثة'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Info Header
                _buildTicketInfoBanner(isDark),
                
                // Messages List
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      return _buildMessageBubble(msg, isDark);
                    },
                  ),
                ),

                // Input Area
                if (_ticketDetails?['status'] != 'closed')
                  _buildInputArea(isDark),
              ],
            ),
    );
  }

  Widget _buildTicketInfoBanner(bool isDark) {
    if (_ticketDetails == null) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      color: isDark ? AppColors.darkSurface : Colors.grey.shade100,
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 20, color: Colors.blue),
          const SizedBox(width: 8),
          Text('الحالة: ${_ticketDetails!['status']}'),
          const Spacer(),
          Text('رقم التذكرة: #${widget.ticketId.substring(0, 8)}'),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg, bool isDark) {
    final currentUserId = SupabaseClientManager.currentUser?.id;
    final isMe = msg['sender_id'] == currentUserId;
    final isAdminReply = msg['is_admin_reply'] == true;
    final createdAt = DateTime.tryParse(msg['created_at'] ?? '');

    // User messages (Right, Blue), Admin messages (Left, Grey)
    // Note: If I am the user, my messages are right. 
    // If I am admin (unlikely here), logic holds.
    


    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        decoration: BoxDecoration(
          color: isMe 
              ? AppColors.primary 
              : isDark ? AppColors.darkSurfaceVariant : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
            bottomRight: isMe ? Radius.zero : const Radius.circular(16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sender Name (if not me)
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  isAdminReply ? 'الدعم الفني' : (msg['sender_name'] ?? 'مستخدم'),
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isAdminReply ? Colors.orange : Colors.grey.shade600,
                  ),
                ),
              ),
              
            // Message Body
            Text(
              msg['message'] ?? '',
              style: TextStyle(
                color: isMe ? Colors.white : (isDark ? Colors.white : const Color(0xFF1E293B)),
                fontSize: 14,
              ),
            ),
            
            // Time
            if (createdAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  intl.DateFormat('hh:mm a').format(createdAt),
                  style: TextStyle(
                    fontSize: 10,
                    color: isMe 
                        ? Colors.white.withValues(alpha: 0.7) 
                        : Colors.grey.shade500,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'اكتب ردك هنا...',
                filled: true,
                fillColor: isDark ? AppColors.darkBackground : Colors.grey.shade500.withValues(alpha:0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              maxLines: null,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _isSending ? null : _sendMessage,
            icon: _isSending 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.send_rounded, color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}


