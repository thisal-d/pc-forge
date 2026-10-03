import 'package:flutter/material.dart';
import '../../data/models/ai_build_result_model.dart';
import '../../data/ai_build_service.dart';
import 'ai_inventory_screen.dart';

/// Screen displaying Member 03 PC Build & Compatibility Agent proposal
/// Matches UI 2 in PCForge Agentic AI Workflow specifications.
class AiBuildResultScreen extends StatefulWidget {
  final AiBuildResultModel buildResult;

  const AiBuildResultScreen({
    super.key,
    required this.buildResult,
  });

  @override
  State<AiBuildResultScreen> createState() => _AiBuildResultScreenState();
}

class _AiBuildResultScreenState extends State<AiBuildResultScreen> {
  bool _showTrace = false;

  @override
  Widget build(BuildContext context) {
    final build = widget.buildResult.build;
    final checklist = build?.compatibility ?? const CompatibilityChecklistModel();

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
              'Your build is ready',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: Colors.white,
              ),
            ),
            Text(
              'PC Build & Compatibility Agent • Step 2',
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
        child: build == null
            ? _buildErrorView()
            : ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                children: [
                  // 1. MAIN BUILD SUMMARY CARD (UI 2 Card 1)
                  _buildComponentCard(build),

                  const SizedBox(height: 16),

                  // 2. COMPATIBILITY CHECKLIST CARD (UI 2 Card 2)
                  _buildChecklistCard(checklist),

                  const SizedBox(height: 16),

                  // 3. AI REASONING / TRACE STEPS (Expandable)
                  if (widget.buildResult.traceSteps.isNotEmpty)
                    _buildTraceCard(),

                  const SizedBox(height: 24),

                  // 4. ACTION BUTTONS
                  _buildActionButtons(context, build),
                  const SizedBox(height: 16),
                ],
              ),
      ),
    );
  }

  Widget _buildComponentCard(ValidatedBuildModel build) {
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
          // Header with Title + Valid Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${build.buildName} · ${build.targetResolution}',
                  style: const TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: const Text(
                  'Valid',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF15803D),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Core Components Rows (Matching UI 2)
          if (build.cpu != null) _buildItemRow('CPU', build.cpu!.name),
          const Divider(height: 16, thickness: 0.8, color: Color(0xFFF1F5F9)),

          if (build.gpu != null) _buildItemRow('GPU', build.gpu!.name),
          const Divider(height: 16, thickness: 0.8, color: Color(0xFFF1F5F9)),

          if (build.ram != null) _buildItemRow('RAM', build.ram!.name),
          const Divider(height: 16, thickness: 0.8, color: Color(0xFFF1F5F9)),

          if (build.motherboard != null)
            _buildItemRow('Motherboard', build.motherboard!.name),
          const Divider(height: 16, thickness: 0.8, color: Color(0xFFF1F5F9)),

          if (build.psu != null) _buildItemRow('PSU', build.psu!.name),

          if (build.storage != null) ...[
            const Divider(height: 16, thickness: 0.8, color: Color(0xFFF1F5F9)),
            _buildItemRow('Storage', build.storage!.name),
          ],

          if (build.pcCase != null) ...[
            const Divider(height: 16, thickness: 0.8, color: Color(0xFFF1F5F9)),
            _buildItemRow('Case', build.pcCase!.name),
          ],

          if (build.cooler != null) ...[
            const Divider(height: 16, thickness: 0.8, color: Color(0xFFF1F5F9)),
            _buildItemRow('Cooler', build.cooler!.name),
          ],

          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Est: LKR ${build.totalPrice.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Text(
                  'Peak Draw: ${build.estimatedWattage}W',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChecklistCard(CompatibilityChecklistModel checklist) {
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
            'Compatibility Checklist',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 14),

          // Socket check
          _buildCheckRow(
            label: 'Socket: CPU ↔ Motherboard',
            passed: checklist.socketMatch,
            subtext: checklist.socketDetails.isNotEmpty
                ? checklist.socketDetails
                : 'AM5/LGA1700 pin matched',
          ),
          const SizedBox(height: 10),

          // Memory check
          _buildCheckRow(
            label: 'Memory: DDR5 supported',
            passed: checklist.memoryMatch,
            subtext: checklist.memoryDetails.isNotEmpty
                ? checklist.memoryDetails
                : 'DDR generation matched with board slots',
          ),
          const SizedBox(height: 10),

          // PSU wattage check
          _buildCheckRow(
            label:
                'PSU wattage: ${checklist.psuWattage}W ≥ ${checklist.estimatedWattage}W draw',
            passed: checklist.wattageOk,
            subtext: '+${checklist.headroomWatts}W transient safety headroom',
          ),
          const SizedBox(height: 10),

          // Case fit check
          _buildCheckRow(
            label: 'Case fit: GPU length & form factor OK',
            passed: checklist.caseFitOk,
            subtext: checklist.caseFitDetails.isNotEmpty
                ? checklist.caseFitDetails
                : 'Chassis accommodates ATX motherboard',
          ),
        ],
      ),
    );
  }

  Widget _buildCheckRow({
    required String label,
    required bool passed,
    String? subtext,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: passed ? const Color(0xFF10B981) : const Color(0xFFEF4444),
            shape: BoxShape.circle,
          ),
          child: Icon(
            passed ? Icons.check_rounded : Icons.close_rounded,
            size: 14,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                ),
              ),
              if (subtext != null && subtext.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    subtext,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: passed
                          ? const Color(0xFF059669)
                          : const Color(0xFFDC2626),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTraceCard() {
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
              Icon(Icons.terminal_rounded, size: 18, color: Color(0xFF6366F1)),
              SizedBox(width: 8),
              Text(
                'Agent Architecture & Reasoning Log',
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
                children: widget.buildResult.traceSteps.map((step) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ', style: TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.bold)),
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

  Future<void> _handleCheckStock(ValidatedBuildModel build) async {
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
                  'Verifying Warehouse Inventory...',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Member 02 Inventory Agent is checking shelf stock in PostgreSQL and locking a 15-minute reservation hold.',
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

    final compIds = <String, int>{};
    build.components.forEach((slot, item) {
      compIds[slot] = item.productId;
    });

    final inventoryResult = await AiBuildService.instance.verifyStock(
      componentIds: compIds,
      buildName: build.buildName,
      targetResolution: build.targetResolution,
    );

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // Dismiss loading dialog

    if (inventoryResult.success) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AiInventoryScreen(inventoryResult: inventoryResult),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFEF4444),
          content: Text(
            inventoryResult.error ?? 'Failed to verify warehouse stock. Please verify backend is running.',
          ),
        ),
      );
    }
  }

  Widget _buildActionButtons(BuildContext context, ValidatedBuildModel build) {
    return Column(
      children: [
        // Primary Step 3 Button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: () => _handleCheckStock(build),
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
                  'Check Stock & Availability',
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward_rounded, size: 18),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Outlined button to view revision history
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF5B4DFF),
              side: const BorderSide(color: Color(0xFF5B4DFF), width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'View revision history / Back',
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildItemRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: Color(0xFFEF4444)),
            const SizedBox(height: 16),
            const Text(
              'Build Generation Error',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              widget.buildResult.error ?? 'Unknown error occurred while generating build.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Back to Requirements'),
            ),
          ],
        ),
      ),
    );
  }
}
