import 'package:flutter/material.dart';
import '../../data/models/ai_order_proposal_model.dart';
import 'build_pc_hub_screen.dart';

/// Screen displayed immediately after customer taps "Approve Order"
/// Matches UI 5 (ui5.png) in PCForge Agentic AI Workflow specifications:
/// "Flutter · shown immediately after approval - saved to backend, awaiting a technician"
class AiOrderSubmittedScreen extends StatelessWidget {
  final AiSubmittedOrderModel submittedOrder;
  final String buildName;

  const AiOrderSubmittedScreen({
    super.key,
    required this.submittedOrder,
    this.buildName = 'Custom PCForge Rig',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF5B4DFF),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        title: const Text(
          'Order submitted',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            color: Colors.white,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Order Confirmation Card matching ui5.png
              _buildOrderCard(context),

              const SizedBox(height: 28),

              // 2. Linear Stepper matching ui5.png: Submitted -> Reviewing -> Payment -> Confirmed
              _buildProgressStepper(),

              const SizedBox(height: 28),

              // 3. Informational Callout Card matching ui5.png
              _buildTechnicianCalloutCard(),

              const SizedBox(height: 36),

              // 4. Action Buttons
              _buildActionButtons(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order Number Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Order #${submittedOrder.orderNumber}',
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.4,
                ),
              ),
              const Icon(
                Icons.verified_outlined,
                color: Color(0xFF5B4DFF),
                size: 22,
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Status Row with Amber Pill
          Row(
            children: [
              const Text(
                'Status',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7), // Warm amber background matching ui5.png
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  submittedOrder.status,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFB45309), // Dark amber text
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(color: Color(0xFFF1F5F9), height: 1),
          const SizedBox(height: 16),

          // Total Amount Row (not charged yet)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total (not charged yet)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                ),
              ),
              Text(
                submittedOrder.formattedTotal,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressStepper() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildStepItem(
          title: 'Submitted',
          color: const Color(0xFF10B981), // Green matching ui5.png
          isCompleted: true,
          isActive: false,
        ),
        _buildStepSeparator(color: const Color(0xFF10B981)),
        _buildStepItem(
          title: 'Reviewing',
          color: const Color(0xFF5B4DFF), // Purple active matching ui5.png
          isCompleted: false,
          isActive: true,
        ),
        _buildStepSeparator(color: const Color(0xFFCBD5E1)),
        _buildStepItem(
          title: 'Store Pickup',
          color: const Color(0xFF94A3B8), // Gray pending
          isCompleted: false,
          isActive: false,
        ),
        _buildStepSeparator(color: const Color(0xFFCBD5E1)),
        _buildStepItem(
          title: 'Handover',
          color: const Color(0xFF94A3B8), // Gray pending
          isCompleted: false,
          isActive: false,
        ),
      ],
    );
  }

  Widget _buildStepItem({
    required String title,
    required Color color,
    required bool isCompleted,
    required bool isActive,
  }) {
    return Column(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: (isCompleted || isActive) ? FontWeight.w800 : FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildStepSeparator({required Color color}) {
    return Container(
      width: 20,
      height: 2,
      color: color,
    );
  }

  Widget _buildTechnicianCalloutCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left solid purple accent bar matching ui5.png
          Container(
            width: 4.5,
            height: 54,
            decoration: BoxDecoration(
              color: const Color(0xFF5B4DFF),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              submittedOrder.message,
              style: const TextStyle(
                fontSize: 14,
                height: 1.45,
                fontWeight: FontWeight.w500,
                color: Color(0xFF334155),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const BuildPcHubScreen()),
                (route) => route.isFirst,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5B4DFF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 2,
            ),
            child: const Text(
              'Return to PC Builder Hub',
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
