import 'package:flutter/material.dart';
import '../../../../core/app_routes.dart';
import '../../../../core/auth_session.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../catalog/data/models/product_model.dart';
import '../../data/build_service.dart';
import '../../data/models/custom_build_slot.dart';
import '../widgets/component_picker_sheet.dart';
import 'build_status_screen.dart';
import 'my_custom_builds_screen.dart';

class BuildPcHubScreen extends StatefulWidget {
  const BuildPcHubScreen({super.key});

  @override
  State<BuildPcHubScreen> createState() => _BuildPcHubScreenState();
}

class _BuildPcHubScreenState extends State<BuildPcHubScreen> {
  // 0: Manual Mode, 1: Auto (AI) Mode
  int _selectedMode = 0;

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
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.build_circle_rounded,
                  color: AppColors.primaryBlue, size: 20),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rig Studio',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  'Custom PC Builder',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.secondaryText,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_edu_rounded, color: AppColors.primaryBlue),
            tooltip: 'My Custom Builds & Status',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MyCustomBuildsScreen()),
              );
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(
                bottom: BorderSide(color: AppColors.border, width: 1),
              ),
            ),
            child: Container(
              height: 44,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedMode = 0),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: _selectedMode == 0
                              ? AppColors.primaryBlue
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: _selectedMode == 0
                              ? [
                                  BoxShadow(
                                    color: AppColors.primaryBlue
                                        .withValues(alpha: 0.3),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.tune_rounded,
                              size: 16,
                              color: _selectedMode == 0
                                  ? Colors.white
                                  : AppColors.secondaryText,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Manual Builder',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _selectedMode == 0
                                    ? Colors.white
                                    : AppColors.secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedMode = 1),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: _selectedMode == 1
                              ? const Color(0xFF8B5CF6)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: _selectedMode == 1
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF8B5CF6)
                                        .withValues(alpha: 0.3),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.auto_awesome,
                              size: 16,
                              color: _selectedMode == 1
                                  ? Colors.white
                                  : AppColors.secondaryText,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'AI Architect',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _selectedMode == 1
                                    ? Colors.white
                                    : AppColors.secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: _selectedMode == 0
          ? const ManualBuilderScreenBody()
          : _buildAutoAiComingSoonView(),
    );
  }

  Widget _buildAutoAiComingSoonView() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Column(
          children: [
            const SizedBox(height: 12),
            // Glowing AI orb
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6), Color(0xFFEC4899)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(Icons.auto_awesome, size: 48, color: Colors.white),
            ),
            const SizedBox(height: 20),

            const Text(
              'Agentic AI Rig Architect',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryDark,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 8),

            const Text(
              'Autonomous multi-agent system analyzing thermal headroom, bottleneck margins, and pricing arbitrage for your dream rig.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                color: AppColors.secondaryText,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 24),

            // AI Subsystems Preview Grid
            _buildAgentPreviewCard(
              icon: Icons.thermostat_rounded,
              color: const Color(0xFF06B6D4),
              agentName: 'Thermal & Clearance Agent',
              description:
                  'Calculates radiator clearances and ensures GPU length fits within chassis dimensions.',
            ),
            const SizedBox(height: 10),
            _buildAgentPreviewCard(
              icon: Icons.speed_rounded,
              color: const Color(0xFF10B981),
              agentName: 'Bottleneck & TDP Auditor',
              description:
                  'Balances CPU single-core performance with GPU compute power to prevent gaming stutters.',
            ),
            const SizedBox(height: 10),
            _buildAgentPreviewCard(
              icon: Icons.price_check_rounded,
              color: const Color(0xFFF59E0B),
              agentName: 'Budget Arbitrage Agent',
              description:
                  'Maximizes frame-rate-per-dollar against current inventory stock in real time.',
            ),

            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, AppRoutes.aiBuilder),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.auto_awesome, size: 20),
                  label: const Text(
                    'Start AI Requirement Chat (Step 1)',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _selectedMode = 0),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.secondaryText,
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.tune_rounded, size: 18),
                label: const Text(
                  'Switch to Manual Builder',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildAgentPreviewCard({
    required IconData icon,
    required Color color,
    required String agentName,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.softShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      agentName,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'AI',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.secondaryText,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The body of the manual builder, hosted inside the hub or standalone
class ManualBuilderScreenBody extends StatefulWidget {
  const ManualBuilderScreenBody({super.key});

  @override
  State<ManualBuilderScreenBody> createState() =>
      _ManualBuilderScreenBodyState();
}

class _ManualBuilderScreenBodyState extends State<ManualBuilderScreenBody> {
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
                      color: AppColors.primaryBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.assignment_turned_in_rounded,
                      color: AppColors.primaryBlue,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Submit Build to Store Staff',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primaryBlue.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Icon(
                      Icons.shield_outlined,
                      color: AppColors.primaryBlue,
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Certified technicians physically inspect socket clearances, case dimensions, and PSU overhead before sign-off.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.primaryDark,
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
                  labelText: 'Optional Customer Notes / Target Use',
                  hintText: 'e.g. 1440p High FPS Gaming, Video Editing...',
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
                key: const Key('hub_confirm_submit_build_btn'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                icon: const Icon(Icons.send_rounded, size: 18),
                label: const Text(
                  'Confirm & Send to Staff',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                onPressed: () async {
                  final token = AuthSession.instance.token;
                  final navigator = Navigator.of(context);
                  final dialogNavigator = Navigator.of(ctx);
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    final build = await _buildService.submitBuildForReview(
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

  // Helper color map for category slots
  Color _getSlotColor(BuildSlotType type) {
    switch (type) {
      case BuildSlotType.cpu:
        return const Color(0xFF6366F1); // Indigo
      case BuildSlotType.motherboard:
        return const Color(0xFF10B981); // Emerald
      case BuildSlotType.ram:
        return const Color(0xFFF59E0B); // Amber
      case BuildSlotType.gpu:
        return const Color(0xFF0EA5E9); // Sky
      case BuildSlotType.psu:
        return const Color(0xFFEF4444); // Red
      case BuildSlotType.storage:
        return const Color(0xFF8B5CF6); // Violet
      case BuildSlotType.pcCase:
        return const Color(0xFF64748B); // Slate
      case BuildSlotType.cooler:
        return const Color(0xFF06B6D4); // Cyan
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

        return Stack(
          children: [
            Column(
              children: [
                // Real-Time Compatibility Banner
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
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

            // Bottom Bar
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
                            'ESTIMATED RIG TOTAL',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.secondaryText,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Wrap(
                            spacing: 6,
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
                      key: const Key('hub_submit_build_for_review_btn'),
                      onPressed:
                          canSubmit ? _showSubmitConfirmationDialog : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
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
                      icon: const Icon(Icons.verified_outlined, size: 17),
                      label: const Text(
                        'Submit for Review',
                        style: TextStyle(
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
                  'Socket match, memory specs & PSU verified. Est. consumption: ${wattage}W.',
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
                    key: Key('hub_add_btn_${slot.type.name}'),
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
