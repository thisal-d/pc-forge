import 'package:flutter/material.dart';
import '../../data/ai_build_service.dart';
import '../../data/models/requirement_profile_model.dart';
import 'ai_build_result_screen.dart';

class AiPcBuilderScreen extends StatefulWidget {
  const AiPcBuilderScreen({super.key});

  @override
  State<AiPcBuilderScreen> createState() => _AiPcBuilderScreenState();
}

class _AiPcBuilderScreenState extends State<AiPcBuilderScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AiBuildService _aiService = AiBuildService.instance;

  @override
  void initState() {
    super.initState();
    _aiService.addListener(_onAiServiceUpdate);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _aiService.initSession();
    });
  }

  @override
  void dispose() {
    _aiService.removeListener(_onAiServiceUpdate);
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onAiServiceUpdate() {
    if (mounted) {
      setState(() {});
      _scrollToBottom();
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

  void _sendMessage([String? presetText]) {
    final text = presetText ?? _textController.text;
    if (text.trim().isEmpty) return;
    if (presetText == null) {
      _textController.clear();
    }
    _aiService.sendMessage(text);
  }

  Future<void> _handleGenerateBuild() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF5B4DFF)),
                ),
                SizedBox(height: 20),
                Text(
                  'Building Your Rig...',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Member 03 Agent is selecting 8 components and executing deterministic socket/wattage clearance tools.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final result = await _aiService.generateBuild(
      sessionId: _aiService.currentSessionId,
    );

    if (!mounted) return;

    Navigator.of(context, rootNavigator: true).pop(); // Dismiss loading dialog
    if (result.success && result.build != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AiBuildResultScreen(buildResult: result),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFEF4444),
          content: Text(
            result.error ?? 'Failed to generate build. Please verify backend is running.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isComplete = _aiService.isProfileComplete;
    final profile = _aiService.currentProfile;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tell us what you need',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: Colors.white,
              ),
            ),
            Text(
              'AI Requirement Discovery • Step 1',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Color(0xFFE0E7FF),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Reset session',
            icon: const Icon(Icons.refresh_rounded, size: 22),
            onPressed: () {
              _aiService.resetSession();
              _aiService.initSession();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Quick preset chips bar
            if (_aiService.messages.length <= 2 && !isComplete)
              _buildPresetChipsBar(),

            // Chat Messages list + Profile card
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                itemCount: _aiService.messages.length + (isComplete ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index < _aiService.messages.length) {
                    final msg = _aiService.messages[index];
                    return _buildMessageBubble(msg);
                  } else {
                    // Profile Ready Summary Card (matching UI 1)
                    return _buildRequirementProfileCard(profile);
                  }
                },
              ),
            ),

            // Typing indicator
            if (_aiService.isLoading) _buildTypingIndicator(),

            // Chat Input Bar
            _buildInputBar(isComplete),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetChipsBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      color: Colors.white,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            _buildQuickChip(
              label: '🎮 Gaming PC for LKR 400,000',
              onTap: () => _sendMessage('I want a gaming PC for LKR 400,000'),
            ),
            const SizedBox(width: 8),
            _buildQuickChip(
              label: '🎬 Video Editing (LKR 750,000)',
              onTap: () => _sendMessage('I want a high-end PC for video editing, budget is LKR 750,000'),
            ),
            const SizedBox(width: 8),
            _buildQuickChip(
              label: '💻 Dev & Office (LKR 250,000)',
              onTap: () => _sendMessage('I need a coding workstation for LKR 250,000, 1080p, no monitor'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickChip({required String label, required VoidCallback onTap}) {
    return ActionChip(
      onPressed: onTap,
      backgroundColor: const Color(0xFFEEF2FF),
      side: const BorderSide(color: Color(0xFFC7D2FE)),
      label: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF4F46E5),
        ),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }

  Widget _buildMessageBubble(AiRequirementMessage msg) {
    if (msg.isUser) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12, left: 48),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: Color(0xFF5B4DFF),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                    bottomLeft: Radius.circular(18),
                    bottomRight: Radius.circular(4),
                  ),
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
            ),
          ],
        ),
      );
    } else {
      final isError = msg.isError;
      return Padding(
        padding: const EdgeInsets.only(bottom: 12, right: 48),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 2, right: 8),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isError ? const Color(0xFFFEE2E2) : const Color(0xFFEEF2FF),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isError ? Icons.error_outline_rounded : Icons.smart_toy_rounded,
                size: 16,
                color: isError ? const Color(0xFFDC2626) : const Color(0xFF6366F1),
              ),
            ),
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isError ? const Color(0xFFFEF2F2) : const Color(0xFFEDE9FE),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(18),
                    bottomLeft: Radius.circular(18),
                    bottomRight: Radius.circular(18),
                  ),
                  border: Border.all(
                    color: isError ? const Color(0xFFFCA5A5) : const Color(0xFFDDD6FE),
                  ),
                ),
                child: Text(
                  msg.text,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                    color: isError ? const Color(0xFF991B1B) : const Color(0xFF1E1B4B),
                    height: 1.35,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildRequirementProfileCard(RequirementProfileModel profile) {
    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded, color: Color(0xFF10B981), size: 16),
              ),
              const SizedBox(width: 10),
              const Text(
                'Requirement Profile — Ready',
                style: TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Key Attributes matching UI 1
          _buildProfileRow('Purpose', profile.purpose ?? 'Gaming'),
          const Divider(height: 18, thickness: 0.8, color: Color(0xFFF1F5F9)),
          _buildProfileRow('Budget', profile.budgetRaw ?? 'LKR 400,000'),
          const Divider(height: 18, thickness: 0.8, color: Color(0xFFF1F5F9)),
          _buildProfileRow('Target res.', profile.targetResolution ?? '1440p'),
          const Divider(height: 18, thickness: 0.8, color: Color(0xFFF1F5F9)),
          _buildProfileRow(
            'Monitor needed',
            profile.monitorNeeded == true ? 'Yes' : 'No',
          ),

          if (profile.preferences.isNotEmpty) ...[
            const Divider(height: 18, thickness: 0.8, color: Color(0xFFF1F5F9)),
            _buildProfileRow('Preferences', profile.preferences.join(', ')),
          ],

          const SizedBox(height: 22),

          // Primary Action Button matching UI 1
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _handleGenerateBuild,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5B4DFF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 3,
                shadowColor: const Color(0xFF5B4DFF).withValues(alpha: 0.4),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Generate my build',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF64748B),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  Widget _buildTypingIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      alignment: Alignment.centerLeft,
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
            ),
          ),
          SizedBox(width: 10),
          Text(
            'AI Architect is analyzing requirements...',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(bool isComplete) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _textController,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: isComplete
                      ? 'Say anything to adjust requirements...'
                      : 'Tell me what you need (e.g. 1440p, have monitor)...',
                  hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF5B4DFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              onPressed: () => _sendMessage(),
            ),
          ),
        ],
      ),
    );
  }
}
