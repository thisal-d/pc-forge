import 'package:flutter/material.dart';
import '../../data/models/ai_inventory_model.dart';
import '../../data/ai_build_service.dart';
import 'ai_order_proposal_screen.dart';

/// Screen displaying Member 02 Inventory Agent results (UI 3 in PCForge Agentic Workflow)
class AiInventoryScreen extends StatefulWidget {
  final AiStockVerificationModel inventoryResult;

  const AiInventoryScreen({
    super.key,
    required this.inventoryResult,
  });

  @override
  State<AiInventoryScreen> createState() => _AiInventoryScreenState();
}

class _AiInventoryScreenState extends State<AiInventoryScreen> {
  bool _showTrace = false;

  Color _getStatusBg(String status) {
    switch (status.toUpperCase()) {
      case 'IN_STOCK':
        return const Color(0xFFDCFCE7); // Light green
      case 'LOW_STOCK':
        return const Color(0xFFFEF3C7); // Light amber
      case 'SUBSTITUTED':
        return const Color(0xFFE0E7FF); // Light indigo
      default:
        return const Color(0xFFFEE2E2); // Light red
    }
  }

  Color _getStatusText(String status) {
    switch (status.toUpperCase()) {
      case 'IN_STOCK':
        return const Color(0xFF15803D); // Dark green
      case 'LOW_STOCK':
        return const Color(0xFFB45309); // Dark amber
      case 'SUBSTITUTED':
        return const Color(0xFF4338CA); // Dark indigo
      default:
        return const Color(0xFFDC2626); // Dark red
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.inventoryResult;
    final reservation = result.reservation;

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
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Checking availability',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: Colors.white,
              ),
            ),
            Text(
              'Inventory Agent • Step 3',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Color(0xFFE0E7FF),
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          children: [
            // Top Accent Progress Bar (Matching UI 3)
            Container(
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF5B4DFF),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // 1. STOCK STATUS CARD (UI 3 Card 1)
            _buildStockStatusCard(result),

            const SizedBox(height: 16),

            // 2. RESERVATION CARD (UI 3 Card 2)
            _buildReservationCard(reservation),

            const SizedBox(height: 16),

            // 3. WAREHOUSE AGENT TRACE LOG (Expandable)
            if (result.traceSteps.isNotEmpty)
              _buildTraceCard(result.traceSteps),

            const SizedBox(height: 24),

            // 4. ACTION BUTTON (UI 3 Button)
            _buildActionButton(context),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildStockStatusCard(AiStockVerificationModel result) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Stock Status',
            style: TextStyle(
              fontSize: 16.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 14),

          // Render rows matching UI 3
          ...result.components.entries.map((entry) {
            final comp = entry.value;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          comp.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E293B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (comp.wasSubstituted && comp.originalProductName != null)
                          Text(
                            'Substituted for ${comp.originalProductName}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF4338CA),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusBg(comp.status),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      comp.statusLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _getStatusText(comp.status),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildReservationCard(AiReservationHoldModel reservation) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Reservation',
            style: TextStyle(
              fontSize: 16.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 14),

          // Row 1: Held for -> 15 minutes
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Held for',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                ),
              ),
              Text(
                '${reservation.heldMinutes} minutes',
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const Divider(height: 20, thickness: 0.8, color: Color(0xFFF1F5F9)),

          // Row 2: Status -> Reserved ✓
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Status',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                ),
              ),
              Row(
                children: [
                  Text(
                    reservation.status,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF15803D),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (reservation.reservationId.isNotEmpty) ...[
            const Divider(height: 20, thickness: 0.8, color: Color(0xFFF1F5F9)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Reservation ID',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                Text(
                  reservation.reservationId,
                  style: const TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTraceCard(List<String> traceSteps) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: _showTrace,
          onExpansionChanged: (val) => setState(() => _showTrace = val),
          title: const Row(
            children: [
              Icon(Icons.inventory_2_outlined, size: 18, color: Color(0xFF5B4DFF)),
              SizedBox(width: 8),
              Text(
                'Warehouse Agent Activity Log',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: traceSteps.map((step) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ', style: TextStyle(color: Color(0xFF5B4DFF), fontWeight: FontWeight.bold)),
                        Expanded(
                          child: Text(
                            step,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF475569),
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleContinueToPricing() async {
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
                  'Pricing Build & Calculating Delivery...',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Member 04 Order Planning Agent is summing component pricing, validating welcome voucher, and sizing shipping fees.',
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

    final rawComps = <String, dynamic>{};
    widget.inventoryResult.components.forEach((slot, item) {
      rawComps[slot] = {
        'product_id': item.productId,
        'name': item.name,
        'price': item.price,
      };
    });

    final proposalResult = await AiBuildService.instance.createOrderProposal(
      reservationId: widget.inventoryResult.reservation.reservationId,
      buildName: 'Custom PCForge Rig',
      components: rawComps,
      promoCode: 'WELCOME5',
      currency: 'LKR',
    );

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // Dismiss loading dialog

    if (proposalResult.success && proposalResult.proposal != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AiOrderProposalScreen(
            proposalResult: proposalResult,
            rawComponents: rawComps,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFEF4444),
          content: Text(
            proposalResult.error ?? 'Failed to generate order proposal. Please ensure backend is running.',
          ),
        ),
      );
    }
  }

  Widget _buildActionButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _handleContinueToPricing,
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
              'Continue to pricing \u2192',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
