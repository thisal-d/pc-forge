import 'package:flutter/material.dart';
import '../../../../core/auth_session.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../catalog/data/models/product_model.dart';
import '../../data/build_service.dart';
import '../../data/models/custom_build_slot.dart';
import '../widgets/component_picker_sheet.dart';
import 'build_status_screen.dart';

class ManualBuilderScreen extends StatefulWidget {
  const ManualBuilderScreen({super.key});

  @override
  State<ManualBuilderScreen> createState() => _ManualBuilderScreenState();
}

class _ManualBuilderScreenState extends State<ManualBuilderScreen> {
  final _buildService = BuildService.instance;
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: _buildService.activeBuildName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _openPicker(BuildSlotInfo slot) {
    ComponentPickerSheet.show(
      context,
      slotInfo: slot,
      onSelect: (product) {
        _buildService.selectComponent(slot.type, product);
      },
    );
  }

  void _showSubmitConfirmationDialog() {
    final notesController = TextEditingController();
    final isEditing = _buildService.isEditingExistingBuild;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom +
                (MediaQuery.of(ctx).padding.bottom > 0
                    ? MediaQuery.of(ctx).padding.bottom + 12
                    : 24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isEditing
                          ? const Color(0xFFF59E0B).withValues(alpha: 0.12)
                          : AppColors.primaryBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isEditing
                          ? Icons.edit_note_rounded
                          : Icons.assignment_turned_in_rounded,
                      color: isEditing
                          ? const Color(0xFFD97706)
                          : AppColors.primaryBlue,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isEditing
                          ? 'Resubmit Build to Store Staff'
                          : 'Submit Build to Store Staff',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isEditing
                      ? const Color(0xFFFFFBEB)
                      : AppColors.primaryBlue.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isEditing
                        ? const Color(0xFFFDE68A)
                        : AppColors.primaryBlue.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      isEditing
                          ? Icons.bolt_rounded
                          : Icons.shield_outlined,
                      color: isEditing
                          ? const Color(0xFFD97706)
                          : AppColors.primaryBlue,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isEditing
                            ? 'Adjusted parts will be sent to technicians for fast-track clearance.'
                            : 'Technicians physically verify socket clearances and PSU headroom before approval.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isEditing
                              ? const Color(0xFF92400E)
                              : AppColors.primaryDark,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _nameController,
                style: const TextStyle(fontSize: 14, color: AppColors.primaryDark),
                decoration: InputDecoration(
                  labelText: 'Rig / Build Name',
                  prefixIcon: const Icon(Icons.drive_file_rename_outline,
                      size: 20, color: AppColors.secondaryText),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: notesController,
                maxLines: 2,
                style: const TextStyle(fontSize: 14, color: AppColors.primaryDark),
                decoration: InputDecoration(
                  labelText: isEditing
                      ? 'Notes for Staff (e.g. Swapped PSU for RM850x)'
                      : 'Optional Notes / Target Use',
                  hintText: isEditing
                      ? 'Explain component adjustments...'
                      : 'e.g. 1440p High FPS Gaming, Streaming...',
                  prefixIcon: const Icon(Icons.notes_rounded,
                      size: 20, color: AppColors.secondaryText),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              ElevatedButton.icon(
                key: const Key('confirm_submit_build_btn'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isEditing
                      ? const Color(0xFFD97706)
                      : AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                icon: const Icon(Icons.send_rounded, size: 18),
                label: Text(
                  isEditing
                      ? 'Confirm & Resubmit to Staff'
                      : 'Confirm & Send to Staff',
                  style:
                      const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                onPressed: () async {
                  final token = AuthSession.instance.token;
                  final navigator = Navigator.of(context);
                  final dialogNavigator = Navigator.of(ctx);
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    final build = isEditing
                        ? await _buildService.resubmitBuild(
                            customerNotes: notesController.text.trim().isNotEmpty
                                ? notesController.text.trim()
                                : null,
                            token: token,
                          )
                        : await _buildService.submitBuildForReview(
                            buildName: _nameController.text.trim(),
                            customerNotes: notesController.text.trim(),
                            token: token,
                          );
                    if (!mounted) return;
                    dialogNavigator.pop();
                    navigator.push(
                      MaterialPageRoute(
                        builder: (_) => BuildStatusScreen(customBuild: build),
                      ),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Failed to submit build: $e'),
                        backgroundColor: AppColors.alertRed,
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
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
    return ListenableBuilder(
      listenable: _buildService,
      builder: (context, _) {
        final warnings = _buildService.compatibilityWarnings;
        final isCompatible = _buildService.isCompatible;
        final missingRequired = _buildService.missingRequiredSlots;
        final canSubmit = _buildService.canSubmitForReview;
        final totalCost = _buildService.totalCost;
        final wattage = _buildService.estimatedWattage;
        final selectedCount = _buildService.selectedCount;
        final isEditing = _buildService.isEditingExistingBuild;

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
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEditing ? 'Modify Build' : 'Custom PC Builder',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  isEditing
                      ? 'Addressing Technician Review Feedback'
                      : 'Step-by-Step Hardware Configurator',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.secondaryText,
                  ),
                ),
              ],
            ),
            actions: [
              if (selectedCount > 0)
                TextButton.icon(
                  onPressed: () => _buildService.clearDraft(),
                  icon: const Icon(Icons.refresh_rounded,
                      size: 16, color: AppColors.secondaryText),
                  label: const Text(
                    'Reset',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ),
            ],
          ),
          body: Stack(
            children: [
              Column(
                children: [
                  // Technician feedback banner if editing
                  if (isEditing &&
                      _buildService.technicianNotesForEdit != null) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.assignment_late_outlined,
                                color: Color(0xFFD97706), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Technician Request:',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF92400E),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _buildService.technicianNotesForEdit!,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFFB45309),
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // Real-time Compatibility Banner
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                    child: _buildCompatibilityBanner(
                      isCompatible,
                      warnings,
                      wattage,
                      selectedCount,
                      missingRequired,
                    ),
                  ),

                  // Slots List
                  Expanded(
                    child: ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        16,
                        8,
                        16,
                        110 + MediaQuery.of(context).padding.bottom,
                      ),
                      itemCount: BuildSlotInfo.allSlots.length,
                      itemBuilder: (context, index) {
                        final slot = BuildSlotInfo.allSlots[index];
                        final product = _buildService.getComponent(slot.type);
                        return _buildSlotCard(slot, product);
                      },
                    ),
                  ),
                ],
              ),

              // Bottom Total & Action Bar
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    10,
                    16,
                    10 + MediaQuery.of(context).padding.bottom,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: const Border(
                      top: BorderSide(color: AppColors.border, width: 1),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 10,
                        offset: const Offset(0, -3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'TOTAL SPEC ESTIMATE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.secondaryText,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'LKR ${totalCost.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primaryDark,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '⚡ ${wattage}W TDP',
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF92400E),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        key: const Key('submit_build_for_review_btn'),
                        onPressed: canSubmit
                            ? _showSubmitConfirmationDialog
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isEditing
                              ? const Color(0xFFD97706)
                              : AppColors.primaryBlue,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              AppColors.border.withValues(alpha: 0.8),
                          disabledForegroundColor: AppColors.secondaryText,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        icon: Icon(
                          isEditing
                              ? Icons.send_rounded
                              : Icons.verified_outlined,
                          size: 17,
                        ),
                        label: Text(
                          isEditing
                              ? 'Resubmit for Review'
                              : 'Submit for Review',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCompatibilityBanner(
    bool isCompatible,
    List<String> warnings,
    int wattage,
    int selectedCount,
    List<BuildSlotInfo> missingRequired,
  ) {
    if (selectedCount == 0) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
          boxShadow: AppColors.softShadow,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.info_outline_rounded,
                  color: AppColors.primaryBlue, size: 18),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Select 8 slots below. Socket, RAM speed, and PSU wattage clearances are verified in real-time.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.secondaryText,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (!isCompatible) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.alertRed.withValues(alpha: 0.4)),
          boxShadow: [
            BoxShadow(
              color: AppColors.alertRed.withValues(alpha: 0.08),
              blurRadius: 8,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.error_outline_rounded,
                    color: AppColors.alertRed, size: 20),
                SizedBox(width: 8),
                Text(
                  'Compatibility Conflict Detected',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.alertRed,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ...warnings.map(
              (w) => Padding(
                padding: const EdgeInsets.only(left: 28, bottom: 3),
                child: Text(
                  '• $w',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF991B1B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Compatible so far, but some required slots are still missing
    if (missingRequired.isNotEmpty) {
      final missingNames =
          missingRequired.map((s) => s.title.split(' (').first).join(', ');
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFDE68A)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFD97706).withValues(alpha: 0.06),
              blurRadius: 8,
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.pending_actions_rounded,
                  color: Color(0xFFD97706), size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Compatible — Missing Required Slots',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF92400E),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Please select: $missingNames to unlock technician review submission.',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFFB45309),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // All required slots filled AND compatible!
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.stockGreen.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: AppColors.stockGreen.withValues(alpha: 0.08),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: AppColors.stockGreen,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, color: Colors.white, size: 14),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'All Required Parts Configured & Compatible ✅',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF065F46),
                    fontSize: 13,
                  ),
                ),
                Text(
                  'Socket match, memory specs & PSU verified. Est. draw: ${wattage}W.',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF047857),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlotCard(BuildSlotInfo slot, ProductModel? product) {
    final isSelected = product != null;
    final slotColor = _getSlotColor(slot.type);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? AppColors.primaryBlue.withValues(alpha: 0.4)
              : AppColors.border,
          width: isSelected ? 1.5 : 1,
        ),
        boxShadow: AppColors.softShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: isSelected
            ? Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: slotColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(slot.icon, color: slotColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          slot.title.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            color: slotColor,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          product.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                            color: AppColors.primaryDark,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              'LKR ${product.price.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AppColors.primaryBlue,
                                fontSize: 13,
                              ),
                            ),
                            if (product.socket != null)
                              _chip('Socket: ${product.socket}'),
                            if (product.memoryType != null)
                              _chip(product.memoryType!),
                            if (product.powerWattage != null)
                              _chip('${product.powerWattage}W'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => _openPicker(slot),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          foregroundColor: AppColors.primaryBlue,
                        ),
                        child: const Text('Swap',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded,
                            size: 18, color: AppColors.alertRed),
                        onPressed: () =>
                            _buildService.removeComponent(slot.type),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ],
              )
            : Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(slot.icon,
                        color: AppColors.secondaryText, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                slot.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: AppColors.primaryDark,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (slot.isRequired) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryBlue
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'REQUIRED',
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primaryBlue,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          slot.description,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    key: Key('add_btn_${slot.type.name}'),
                    onPressed: () => _openPicker(slot),
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Add'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryBlue,
                      side: const BorderSide(color: AppColors.primaryBlue),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _chip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      margin: const EdgeInsets.only(right: 4),
      decoration: BoxDecoration(
        color: AppColors.specPillBackground,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: AppColors.specText,
        ),
      ),
    );
  }
}
