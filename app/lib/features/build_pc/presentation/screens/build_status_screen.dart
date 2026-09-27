import 'package:flutter/material.dart';
import '../../../../core/app_routes.dart';
import '../../../../core/auth_session.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../cart/data/cart_service.dart';
import '../../data/build_service.dart';
import '../../data/models/custom_build_model.dart';
import '../../data/models/custom_build_slot.dart';

class BuildStatusScreen extends StatefulWidget {
  final CustomBuildModel customBuild;

  const BuildStatusScreen({super.key, required this.customBuild});

  @override
  State<BuildStatusScreen> createState() => _BuildStatusScreenState();
}

class _BuildStatusScreenState extends State<BuildStatusScreen> {
  late CustomBuildModel _customBuild;
  bool _isLoadingDetails = false;

  CustomBuildModel get customBuild => _customBuild;

  @override
  void initState() {
    super.initState();
    _customBuild = widget.customBuild;
    if (_customBuild.selectedComponents.isEmpty && _customBuild.buildId > 0) {
      _loadFullDetails();
    }
  }

  Future<void> _loadFullDetails() async {
    setState(() => _isLoadingDetails = true);
    try {
      final token = AuthSession.instance.token;
      final fullBuild = await BuildService.instance.fetchBuildById(_customBuild.buildId, token: token);
      if (fullBuild != null && mounted) {
        setState(() {
          _customBuild = fullBuild;
        });
      }
    } finally {
      if (mounted) setState(() => _isLoadingDetails = false);
    }
  }

  Color _getSlotColor(BuildSlotType type) {
    switch (type) {
      case BuildSlotType.cpu:
        return const Color(0xFF6366F1);
      case BuildSlotType.motherboard:
        return const Color(0xFF10B981);
      case BuildSlotType.ram:
        return const Color(0xFFF59E0B);
      case BuildSlotType.gpu:
        return const Color(0xFF0EA5E9);
      case BuildSlotType.psu:
        return const Color(0xFFEF4444);
      case BuildSlotType.storage:
        return const Color(0xFF8B5CF6);
      case BuildSlotType.pcCase:
        return const Color(0xFF64748B);
      case BuildSlotType.cooler:
        return const Color(0xFF06B6D4);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.primaryDark, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Build Review Status',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppColors.primaryDark,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          // 1. HERO STATUS CARD
          _buildHeroCard(context),

          const SizedBox(height: 16),

          // 2. TIMELINE CARD
          _buildTimelineCard(context),

          const SizedBox(height: 16),

          // 3. TECHNICIAN REVIEW FEEDBACK (If Changes Requested)
          if (customBuild.isChangesRequested) ...[
            _buildChangesRequestedCard(context),
            const SizedBox(height: 16),
          ],

          // 3B. TECHNICIAN APPROVAL FEEDBACK (If Approved)
          if (customBuild.isApproved) ...[
            _buildApprovedFeedbackCard(context),
            const SizedBox(height: 16),
          ],

          // 4. IN REVIEW / PENDING BANNER
          if (customBuild.isReviewing) ...[
            _buildInReviewBanner(),
            const SizedBox(height: 16),
          ] else if (customBuild.isPendingReview) ...[
            _buildPendingBanner(),
            const SizedBox(height: 16),
          ],

          // 5. CONFIGURED HARDWARE LIST
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'CONFIGURED HARDWARE COMPONENTS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.secondaryText,
                    letterSpacing: 0.8,
                  ),
                ),
                Text(
                  '${customBuild.selectedComponents.length} Parts',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          _buildComponentsCard(),

          const SizedBox(height: 24),

          // 6. ACTION BUTTONS
          if (customBuild.isChangesRequested)
            ElevatedButton.icon(
              key: const Key('modify_and_resubmit_btn'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD97706),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              icon: const Icon(Icons.build_circle_rounded, size: 20),
              label: const Text(
                'Modify & Resubmit Build',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
              ),
              onPressed: () {
                BuildService.instance.loadBuildForModification(customBuild);
                Navigator.pushNamed(context, AppRoutes.manualBuilder);
              },
            ),

          if (customBuild.isApproved)
            ElevatedButton.icon(
              key: const Key('proceed_to_checkout_approved_btn'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.stockGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              icon: const Icon(Icons.shopping_bag_rounded, size: 20),
              label: const Text(
                'Proceed to Checkout (Approved)',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
              ),
              onPressed: () async {
                if (_customBuild.selectedComponents.isEmpty && _customBuild.buildId > 0) {
                  setState(() => _isLoadingDetails = true);
                  final token = AuthSession.instance.token;
                  final fullBuild = await BuildService.instance.fetchBuildById(_customBuild.buildId, token: token);
                  if (fullBuild != null && mounted) {
                    setState(() {
                      _customBuild = fullBuild;
                    });
                  }
                  if (mounted) setState(() => _isLoadingDetails = false);
                }

                if (_customBuild.selectedComponents.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('No components found in this approved build.'),
                      backgroundColor: AppColors.alertRed,
                    ),
                  );
                  return;
                }

                CartService.instance.clear();
                for (final component in _customBuild.selectedComponents.values) {
                  CartService.instance.addItem(component);
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Loaded ${_customBuild.selectedComponents.length} approved rig parts into Cart!',
                    ),
                    backgroundColor: AppColors.stockGreen,
                    duration: const Duration(seconds: 2),
                  ),
                );
                Navigator.pushNamed(context, AppRoutes.checkout);
              },
            ),

          const SizedBox(height: 12),

          OutlinedButton(
            onPressed: () => Navigator.pushNamedAndRemoveUntil(
                context, AppRoutes.catalog, (route) => false),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.border),
              foregroundColor: AppColors.secondaryText,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Back to Catalog',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildHeroCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.softShadow,
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'RIG #${customBuild.buildId}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryBlue,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              _statusPill(customBuild.status),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            customBuild.buildName,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryDark,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'LKR ${customBuild.totalCost.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryBlue,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '⚡ ${customBuild.estimatedWattage}W TDP',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF92400E),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.softShadow,
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Review & Approval Progress',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(height: 16),
          _timelineStep(
            title: '1. Build Created & Submitted',
            subtitle: 'Component selection validated by local engine',
            isDone: true,
            isActive: false,
          ),
          _timelineStep(
            title: '2. Store Staff Technical Review',
            subtitle: customBuild.isPendingReview
                ? 'Store technicians verifying socket clearance & TDP headroom'
                : customBuild.isChangesRequested
                    ? 'Staff requested component adjustments (see feedback below)'
                    : 'Review complete & verified',
            isDone: customBuild.isApproved,
            isActive: customBuild.isPendingReview ||
                customBuild.isChangesRequested,
            isWarning: customBuild.isChangesRequested,
          ),
          _timelineStep(
            title: '3. Staff Approval & Fast-Track Signoff',
            subtitle: customBuild.isApproved
                ? 'Verified by certified store staff & unlocked for checkout'
                : customBuild.isChangesRequested
                    ? 'Paused: Awaiting component adjustment & resubmission'
                    : 'Awaiting certified technician sign-off',
            isDone: customBuild.isApproved,
            isActive: false,
          ),
          _timelineStep(
            title: '4. Final Checkout & Assembly',
            subtitle: customBuild.isApproved
                ? 'Unlocked: Ready to place order for assembly'
                : 'Locked until staff approves technical build',
            isDone: false,
            isActive: customBuild.isApproved,
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildChangesRequestedCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.assignment_late_outlined,
                  color: Color(0xFFD97706), size: 20),
              SizedBox(width: 8),
              Text(
                'Technician Review Feedback',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: Color(0xFF92400E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Text(
              customBuild.staffNotes ??
                  'Technician requested adjustments to your component selection.',
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF92400E),
                height: 1.4,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Tap "Modify & Resubmit Build" below to swap the conflicting component and submit for rapid clearance.',
            style: TextStyle(fontSize: 12, color: Color(0xFFB45309)),
          ),
        ],
      ),
    );
  }

  Widget _buildApprovedFeedbackCard(BuildContext context) {
    final note = customBuild.staffNotes?.trim();
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF86EFAC)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.verified_rounded, color: Color(0xFF16A34A), size: 22),
              SizedBox(width: 8),
              Text(
                'Certified Technician Approval Message',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: Color(0xFF166534),
                ),
              ),
            ],
          ),
          if (note != null && note.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Text(
                note,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF166534),
                  height: 1.4,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          const Text(
            'All hardware clearances, socket compatibility, and PSU wattage headroom have been verified. You can proceed directly to checkout.',
            style: TextStyle(fontSize: 12, color: Color(0xFF15803D)),
          ),
        ],
      ),
    );
  }

  Widget _buildInReviewBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.manage_search_rounded,
                  color: AppColors.primaryBlue, size: 22),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'In Review by Certified Technician',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E40AF),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Our engineering team is actively testing TDP, socket alignment, and component clearances. You will be updated as soon as verification completes.',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF1E40AF),
              height: 1.35,
            ),
          ),
          if (customBuild.staffNotes != null && customBuild.staffNotes!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Text(
                'Technician Note: ${customBuild.staffNotes}',
                style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Color(0xFF1E40AF)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPendingBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        children: const [
          Icon(Icons.hourglass_top_rounded,
              color: AppColors.primaryBlue, size: 22),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Your rig is currently in the certified technician inspection queue. You will receive an instant notification once approved!',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF1E40AF),
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComponentsCard() {
    if (_isLoadingDetails) {
      return Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: AppColors.softShadow,
        ),
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primaryBlue),
              ),
              SizedBox(height: 10),
              Text(
                'Fetching approved rig components...',
                style: TextStyle(fontSize: 12, color: AppColors.secondaryText),
              ),
            ],
          ),
        ),
      );
    }

    if (customBuild.selectedComponents.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: AppColors.softShadow,
        ),
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.inventory_2_outlined, color: AppColors.secondaryText, size: 30),
              const SizedBox(height: 8),
              const Text(
                'Component details not loaded.',
                style: TextStyle(fontSize: 12, color: AppColors.secondaryText),
              ),
              const SizedBox(height: 6),
              TextButton.icon(
                onPressed: _loadFullDetails,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Reload Components', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        children: customBuild.selectedComponents.entries.map((entry) {
          final slotType = entry.key;
          final product = entry.value;
          final slotTitle = BuildSlotInfo.allSlots
              .firstWhere(
                (s) => s.type == slotType,
                orElse: () => BuildSlotInfo(
                  type: slotType,
                  title: slotType.name.toUpperCase(),
                  description: '',
                  icon: Icons.devices,
                ),
              )
              .title;
          final slotColor = _getSlotColor(slotType);

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: slotColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.memory_rounded,
                      color: slotColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        slotTitle.toUpperCase(),
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: slotColor,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        product.name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Text(
                  'LKR ${product.price.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryBlue,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _statusPill(String status) {
    Color bg = const Color(0xFFF1F5F9);
    Color fg = AppColors.secondaryText;

    if (status == 'Pending Staff Review') {
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFF92400E);
    } else if (status == 'Approved by Staff') {
      bg = const Color(0xFFECFDF5);
      fg = const Color(0xFF065F46);
    } else if (status == 'Changes Requested') {
      bg = const Color(0xFFFFFBEB);
      fg = const Color(0xFFB45309);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }

  Widget _timelineStep({
    required String title,
    required String subtitle,
    required bool isDone,
    required bool isActive,
    bool isWarning = false,
    bool isLast = false,
  }) {
    Color circleColor = isDone
        ? AppColors.stockGreen
        : isWarning
            ? const Color(0xFFD97706)
            : (isActive ? AppColors.primaryBlue : AppColors.border);

    IconData iconData = isDone
        ? Icons.check
        : isWarning
            ? Icons.warning_amber_rounded
            : (isActive ? Icons.more_horiz : Icons.lock_outline_rounded);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: circleColor,
                shape: BoxShape.circle,
                boxShadow: isDone || isActive
                    ? [
                        BoxShadow(
                          color: circleColor.withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                iconData,
                size: 13,
                color: isDone || isWarning || isActive
                    ? Colors.white
                    : AppColors.secondaryText,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 38,
                color: isDone ? AppColors.stockGreen : AppColors.border,
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: (isDone || isActive)
                      ? AppColors.primaryDark
                      : AppColors.secondaryText,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.secondaryText,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ],
    );
  }
}
