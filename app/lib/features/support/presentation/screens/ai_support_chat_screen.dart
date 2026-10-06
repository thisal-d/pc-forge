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
        "Tomorrow at 2:00 PM",
        "Tomorrow",
        "2:00 PM",
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
    if (clean.isEmpty || _isLoading) return;

    _textController.clear();
    setState(() {
      _messages.add(AiAfterSalesChatMessage(text: clean, isUser: true));
      _isLoading = true;
    });
    _scrollToBottom();

    try {
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
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _messages.add(
          AiAfterSalesChatMessage(
            text: "Sorry, I encountered an issue connecting to the service. Please try again.",
            isUser: false,
            isError: true,
          ),
        );
      });
      _scrollToBottom();
    }
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
            onPressed: _isLoading ? null : () => _handleSendMessage(prompt),
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
            _buildServiceRequestCard(msg, msg.serviceRequest!),
            const SizedBox(height: 16),
          ] else if (msg.ticket != null) ...[
            _buildRmaServiceRequestCard(msg.ticket!),
            const SizedBox(height: 16),
          ],
        ],
      );
    }
  }

  Widget _buildServiceRequestCard(AiAfterSalesChatMessage msg, ServiceRequestModel sr) {
    final isDraft = sr.status.toUpperCase() == 'DRAFT';
    if (isDraft) {
      return _buildDraftConfirmationCard(msg, sr);
    }
    return _buildConfirmedServiceRequestCard(msg, sr);
  }

  Widget _buildDraftConfirmationCard(AiAfterSalesChatMessage msg, ServiceRequestModel sr) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFC7D2FE), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5B4DFF).withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Review Service Request',
                style: TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.3,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFC7D2FE)),
                ),
                child: const Text(
                  'Pending Confirmation',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF4338CA),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Generated from your troubleshooting conversation. Please review or edit before confirming:',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 12),

          // Generated Title & Description Container
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'TITLE',
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5),
                    ),
                    InkWell(
                      onTap: _isLoading ? null : () => _showEditDraftDialog(msg, sr),
                      child: const Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 14, color: Color(0xFF5B4DFF)),
                          SizedBox(width: 4),
                          Text('Edit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF5B4DFF))),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  sr.title,
                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                ),
                if (sr.description != null && sr.description!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Text(
                    'DESCRIPTION',
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    sr.description!,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.35),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),

          if (sr.preferredDate != null) ...[
            _buildServiceRequestRow(
              label: 'Preferred Appointment',
              value: '${sr.preferredDate} at ${sr.preferredTime ?? "10:00 AM"}',
              isBold: true,
            ),
            const SizedBox(height: 8),
          ],

          _buildServiceRequestRow(
            label: 'Initial Status',
            value: 'Pending',
            isBold: true,
            valueColor: const Color(0xFFB45309),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : () => _showEditDraftDialog(msg, sr),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF5B4DFF),
                      side: const BorderSide(color: Color(0xFFC7D2FE), width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    child: const Text('Edit Details', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : () => _handleConfirmAndSubmitDraft(msg, sr),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5B4DFF),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    child: const Text('Confirm & Create', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmedServiceRequestCard(AiAfterSalesChatMessage msg, ServiceRequestModel sr) {
    Color statusBg;
    Color statusFg;
    final st = sr.status.toUpperCase();
    if (st == 'PENDING') {
      statusBg = const Color(0xFFFEF3C7);
      statusFg = const Color(0xFFB45309);
    } else if (st == 'IN PROGRESS' || st == 'IN_PROGRESS') {
      statusBg = const Color(0xFFDBEAFE);
      statusFg = const Color(0xFF1D4ED8);
    } else if (st == 'COMPLETED') {
      statusBg = const Color(0xFFD1FAE5);
      statusFg = const Color(0xFF065F46);
    } else if (st == 'NO SHOW' || st == 'NO_SHOW') {
      statusBg = const Color(0xFFF1F5F9);
      statusFg = const Color(0xFF475569);
    } else if (st == 'CANCELLED' || st == 'CANCELED') {
      statusBg = const Color(0xFFFEE2E2);
      statusFg = const Color(0xFF991B1B);
    } else {
      statusBg = const Color(0xFFFEF3C7);
      statusFg = const Color(0xFFB45309);
    }

    final isPending = st == 'PENDING';

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
                  color: statusBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  sr.status,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: statusFg,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (sr.title.isNotEmpty) ...[
            Text(
              sr.title,
              style: const TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
            if (sr.description != null && sr.description!.isNotEmpty && sr.description != sr.title) ...[
              const SizedBox(height: 4),
              Text(
                sr.description!,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                  height: 1.35,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 12),
          ],

          _buildServiceRequestRow(
            label: 'Product',
            value: sr.productName ?? 'PC Hardware Component',
            isBold: true,
          ),
          const SizedBox(height: 8),

          _buildServiceRequestRow(
            label: 'Warranty',
            value: sr.warrantyStatus,
            valueColor: sr.warrantyStatus == 'Active' ? const Color(0xFF10B981) : const Color(0xFFEF4444),
            isBold: true,
          ),
          const SizedBox(height: 8),

          if (sr.preferredDate != null) ...[
            _buildServiceRequestRow(
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

          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: OutlinedButton(
                    onPressed: () => _handleAttachPhoto(sr.serviceRequestNumber),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF5B4DFF),
                      side: const BorderSide(color: Color(0xFF5B4DFF), width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    child: const Text('Attach Photo', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5B4DFF),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    child: const Text('View Requests', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                ),
              ),
            ],
          ),

          if (isPending) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 40,
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _isLoading ? null : () => _handleCancelServiceRequest(msg, sr),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFEF4444),
                  side: const BorderSide(color: Color(0xFFFCA5A5)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Cancel Request', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showEditDraftDialog(AiAfterSalesChatMessage msg, ServiceRequestModel sr) {
    final titleCtrl = TextEditingController(text: sr.title);
    final descCtrl = TextEditingController(text: sr.description ?? sr.problemDescription);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Edit Service Request', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Title', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF475569))),
              const SizedBox(height: 6),
              TextField(
                controller: titleCtrl,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 14),
              const Text('Description', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF475569))),
              const SizedBox(height: 6),
              TextField(
                controller: descCtrl,
                maxLines: 4,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newTitle = titleCtrl.text.trim();
              final newDesc = descCtrl.text.trim();
              if (newTitle.isNotEmpty) {
                final updated = sr.copyWith(
                  title: newTitle,
                  description: newDesc,
                  problemDescription: newDesc.isNotEmpty ? newDesc : newTitle,
                );
                final idx = _messages.indexOf(msg);
                if (idx != -1) {
                  setState(() {
                    _messages[idx] = AiAfterSalesChatMessage(
                      text: msg.text,
                      isUser: msg.isUser,
                      serviceRequest: updated,
                      ticket: msg.ticket,
                      attemptCount: msg.attemptCount,
                      problemCategory: msg.problemCategory,
                      serviceRequestMode: msg.serviceRequestMode,
                    );
                  });
                }
              }
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5B4DFF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleConfirmAndSubmitDraft(AiAfterSalesChatMessage msg, ServiceRequestModel draft) async {
    setState(() => _isLoading = true);
    try {
      final created = await SupportService.instance.createServiceRequest(
        title: draft.title,
        description: draft.description,
        problemDescription: (draft.description != null && draft.description!.isNotEmpty)
            ? draft.description!
            : draft.title,
        productName: draft.productName,
        problemCategory: draft.problemCategory,
        troubleshootingSummary: draft.title,
        preferredDate: draft.preferredDate,
        preferredTime: draft.preferredTime,
        attemptCount: draft.attemptCount,
      );

      final idx = _messages.indexOf(msg);
      if (idx != -1) {
        setState(() {
          _messages[idx] = AiAfterSalesChatMessage(
            text: 'Your Service Request has been confirmed and submitted successfully! Status is Pending.',
            isUser: false,
            serviceRequest: created,
            attemptCount: msg.attemptCount,
            problemCategory: msg.problemCategory,
            serviceRequestMode: true,
          );
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF10B981),
            content: Text('Service Request #${created.serviceRequestNumber} created with status Pending.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFEF4444),
            content: Text('Failed to submit Service Request: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleCancelServiceRequest(AiAfterSalesChatMessage msg, ServiceRequestModel sr) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Service Request', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text('Are you sure you want to cancel Service Request #${sr.serviceRequestNumber}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Request'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            child: const Text('Cancel Request'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final success = await SupportService.instance.cancelServiceRequest(sr.serviceRequestId);
      if (success) {
        final updated = sr.copyWith(status: 'CANCELLED');
        final idx = _messages.indexOf(msg);
        if (idx != -1) {
          setState(() {
            _messages[idx] = AiAfterSalesChatMessage(
              text: 'Service Request #${sr.serviceRequestNumber} has been cancelled.',
              isUser: false,
              serviceRequest: updated,
              attemptCount: msg.attemptCount,
              problemCategory: msg.problemCategory,
              serviceRequestMode: msg.serviceRequestMode,
            );
          });
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF10B981),
              content: Text('Service Request #${sr.serviceRequestNumber} cancelled.'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFEF4444),
            content: Text('Failed to cancel request: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildRmaServiceRequestCard(AiRmaServiceRequestModel rmaSr) {
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
            'Service Request #${rmaSr.rmaNumber}',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 12),
          _buildServiceRequestRow(label: 'Component', value: rmaSr.componentName, isBold: true),
          const SizedBox(height: 8),
          _buildServiceRequestRow(label: 'Issue Category', value: rmaSr.issueType, isBold: true),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton(
              onPressed: () => _handleAttachPhoto(rmaSr.rmaNumber),
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

  Widget _buildServiceRequestRow({
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
              enabled: !_isLoading,
              decoration: InputDecoration(
                hintText: _isLoading
                    ? 'Waiting for agent response...'
                    : (_isServiceRequestMode
                        ? 'Enter preferred date and time (e.g. Tomorrow at 2 PM)...'
                        : 'Describe your issue (e.g. PC won\'t turn on)...'),
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              ),
              onSubmitted: _isLoading ? null : _handleSendMessage,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _isLoading ? null : () => _handleSendMessage(_textController.text),
            icon: Icon(
              Icons.send_rounded,
              color: _isLoading ? Colors.grey.shade400 : const Color(0xFF5B4DFF),
            ),
          ),
        ],
      ),
    );
  }
}
