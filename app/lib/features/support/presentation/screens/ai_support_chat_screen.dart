import 'package:flutter/material.dart';
import '../../data/models/ai_after_sales_model.dart';
import '../../data/support_service.dart';

/// Screen displaying Member 05 After-Sales Service Agent & Service Requests.
/// Matches UI 8 (ui8.png) and the updated Service Request workflow in PCForge.
class AiSupportChatScreen extends StatefulWidget {
  final int? orderId;

  const AiSupportChatScreen({
    super.key,
    this.orderId,
  });

  @override
  State<AiSupportChatScreen> createState() => _AiSupportChatScreenState();
}

class _AiSupportChatScreenState extends State<AiSupportChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<AiAfterSalesChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isServiceRequestMode = false;
  late final String _sessionId;

  final List<String> _quickPrompts = [
    "My PC won't turn on",
    "My screen is black",
    "My PC keeps restarting",
    "My computer is slow",
    "My PC is making a strange noise",
  ];

  List<String> get _currentQuickPrompts {
    if (_isServiceRequestMode) {
      return [
        "My Order ID is 1",
        "Tomorrow at 10:00 AM",
        "Next Monday at 11:00 AM",
      ];
    }
    return _quickPrompts;
  }

  @override
  void initState() {
    super.initState();
    _sessionId = 'after_sales_session_${DateTime.now().millisecondsSinceEpoch}';
    // Initial welcome greeting matching Requirement 19
    _messages.add(
      AiAfterSalesChatMessage(
        text: "Hi! I'm your PCForge After-Sales Service Assistant. How can we help you today with your PC or component?",
        isUser: false,
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 120,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleSendMessage(String text) async {
    final clean = text.trim();
    if (clean.isEmpty) return;

    _textController.clear();
    setState(() {
      _messages.add(AiAfterSalesChatMessage(text: clean, isUser: true));
      _isLoading = true;
    });
    _scrollToBottom();

    final result = await SupportService.instance.sendAfterSalesChatMessage(
      clean,
      orderId: widget.orderId,
      sessionId: _sessionId,
    );

    if (!mounted) return;

    final isSrModeNow = result.serviceRequestMode || _isServiceRequestMode || result.serviceRequest != null;

    setState(() {
      _isLoading = false;
      _isServiceRequestMode = isSrModeNow;
      _messages.add(
        AiAfterSalesChatMessage(
          text: result.reply,
          isUser: false,
          ticket: result.ticket,
          serviceRequest: result.serviceRequest,
          attemptCount: result.attemptCount,
          problemCategory: result.problemCategory,
          isError: !result.success,
          serviceRequestMode: isSrModeNow,
        ),
      );
    });
    _scrollToBottom();
  }

  void _handleAttachPhoto(String srNumber) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Attach Photo to $srNumber',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Take a photo of the faulty component or screen artifact for technician inspection.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: Color(0xFF5B4DFF)),
                title: const Text('Take Photo with Camera', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: const Color(0xFF10B981),
                      content: Text('Photo attached to $srNumber!'),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: Color(0xFF5B4DFF)),
                title: const Text('Choose from Gallery', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: const Color(0xFF10B981),
                      content: Text('Image uploaded and linked to $srNumber!'),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF5B4DFF),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'After-Sales Support',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                color: Colors.white,
              ),
            ),
            if (_isServiceRequestMode)
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'SERVICE REQUEST INTAKE MODE',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFB45309),
                    letterSpacing: 0.3,
                  ),
                ),
              ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Quick Suggestion Chips
            _buildQuickPromptChips(),

            // Message Thread
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                itemCount: _messages.length + (_isLoading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _messages.length && _isLoading) {
                    return _buildLoadingBubble();
                  }
                  final msg = _messages[index];
                  return _buildMessageItem(msg);
                },
              ),
            ),

            // Bottom Input Bar
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickPromptChips() {
    final prompts = _currentQuickPrompts;
    return Container(
      height: 48,
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: prompts.length,
        separatorBuilder: (_, index) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final prompt = prompts[i];
          return ActionChip(
            label: Text(
              prompt,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF4338CA),
              ),
            ),
            backgroundColor: const Color(0xFFEEF2FF),
            side: const BorderSide(color: Color(0xFFC7D2FE)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onPressed: () => _handleSendMessage(prompt),
          );
        },
      ),
    );
  }

  Widget _buildMessageItem(AiAfterSalesChatMessage msg) {
    if (msg.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 14, left: 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF5B4DFF),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(4),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF5B4DFF).withValues(alpha: 0.25),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Text(
            msg.text,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w500,
              color: Colors.white,
              height: 1.35,
            ),
          ),
        ),
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.only(bottom: 12, right: 36),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                  bottomLeft: Radius.circular(4),
                ),
                border: Border.all(color: const Color(0xFFE0E7FF)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (msg.attemptCount > 0) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFC7D2FE),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Troubleshooting Step ${msg.attemptCount} of 5',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF312E81),
                        ),
                      ),
                    ),
                  ],
                  Text(
                    msg.text,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1E293B),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Action button to stop chatting and transition directly to Service Request mode
          if (!_isServiceRequestMode && msg.serviceRequest == null && msg.ticket == null && !msg.isError) ...[
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 12),
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : () => _handleSendMessage("Create Service Request"),
                icon: const Icon(Icons.build_circle_outlined, size: 16, color: Color(0xFF5B4DFF)),
                label: const Text(
                  'Stop Chat & Create Service Request',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF5B4DFF),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: const Color(0xFFF5F3FF),
                  side: const BorderSide(color: Color(0xFFC4B5FD)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
              ),
            ),
          ],

          // Service Request Confirmation Card
          if (msg.serviceRequest != null) ...[
            _buildServiceRequestCard(msg.serviceRequest!),
            const SizedBox(height: 16),
          ] else if (msg.ticket != null) ...[
            _buildLegacyTicketCard(msg.ticket!),
            const SizedBox(height: 16),
          ],
        ],
      );
    }
  }

  Widget _buildServiceRequestCard(ServiceRequestModel sr) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Service Request #${sr.serviceRequestNumber}',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.3,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  sr.status,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFB45309),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          _buildTicketRow(
            label: 'Product',
            value: sr.productName ?? 'PC Hardware Component',
            isBold: true,
          ),
          const SizedBox(height: 8),

          _buildTicketRow(
            label: 'Warranty',
            value: sr.warrantyStatus,
            valueColor: sr.warrantyStatus == 'Active' ? const Color(0xFF10B981) : const Color(0xFFEF4444),
            isBold: true,
          ),
          const SizedBox(height: 8),

          if (sr.preferredDate != null) ...[
            _buildTicketRow(
              label: 'Appointment',
              value: '${sr.preferredDate} (${sr.preferredTime ?? "10:00 AM"})',
              isBold: true,
            ),
            const SizedBox(height: 8),
          ],

          const Text(
            'Please bring your PC or affected component to our service center for technician inspection.',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
          ),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton(
              onPressed: () => _handleAttachPhoto(sr.serviceRequestNumber),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF5B4DFF),
                side: const BorderSide(color: Color(0xFF5B4DFF), width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Attach Photo Proof', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegacyTicketCard(AiRmaTicketModel ticket) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Service Request #${ticket.rmaNumber}',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 12),
          _buildTicketRow(label: 'Component', value: ticket.componentName, isBold: true),
          const SizedBox(height: 8),
          _buildTicketRow(label: 'Issue Category', value: ticket.issueType, isBold: true),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton(
              onPressed: () => _handleAttachPhoto(ticket.rmaNumber),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF5B4DFF),
                side: const BorderSide(color: Color(0xFF5B4DFF), width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Attach Photo', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketRow({
    required String label,
    required String value,
    bool isBold = false,
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13.5, color: Color(0xFF64748B)),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            color: valueColor ?? const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingBubble() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFEEF2FF),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF5B4DFF)),
            ),
            SizedBox(width: 10),
            Text(
              'After-Sales Agent is thinking...',
              style: TextStyle(fontSize: 13, color: Color(0xFF4338CA), fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              decoration: InputDecoration(
                hintText: _isServiceRequestMode
                    ? 'Enter Order ID (e.g. 1) or preferred appointment...'
                    : 'Describe your issue (e.g. PC won\'t turn on)...',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              ),
              onSubmitted: _handleSendMessage,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => _handleSendMessage(_textController.text),
            icon: const Icon(Icons.send_rounded, color: Color(0xFF5B4DFF)),
          ),
        ],
      ),
    );
  }
}
