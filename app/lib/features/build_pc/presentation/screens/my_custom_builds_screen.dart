import 'package:flutter/material.dart';
import '../../../../core/app_routes.dart';
import '../../../../core/auth_session.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/build_service.dart';
import '../../data/models/custom_build_model.dart';
import 'build_status_screen.dart';

class MyCustomBuildsScreen extends StatefulWidget {
  const MyCustomBuildsScreen({super.key});

  @override
  State<MyCustomBuildsScreen> createState() => _MyCustomBuildsScreenState();
}

class _MyCustomBuildsScreenState extends State<MyCustomBuildsScreen> {
  final BuildService _buildService = BuildService.instance;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = false;
  String _selectedStatus = 'ALL';
  String _searchQuery = '';
  int _displayedCount = 8;
  bool _isLoadingMore = false;

  final List<Map<String, String>> _statusFilters = [
    {'key': 'ALL', 'label': 'All Builds'},
    {'key': 'IN_REVIEW', 'label': 'In Review'},
    {'key': 'APPROVED', 'label': 'Approved'},
    {'key': 'CHANGES_REQUESTED', 'label': 'Needs Changes'},
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _fetchBuilds();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    final filtered = _getFilteredBuilds(_buildService.myBuilds);
    if (_isLoadingMore || _displayedCount >= filtered.length) return;

    setState(() => _isLoadingMore = true);
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    setState(() {
      _displayedCount = (_displayedCount + 8).clamp(0, filtered.length);
      _isLoadingMore = false;
    });
  }

  Future<void> _fetchBuilds() async {
    setState(() {
      _isLoading = true;
      _displayedCount = 8;
      _isLoadingMore = false;
    });
    final token = AuthSession.instance.token;
    await _buildService.loadMyBuilds(token: token);
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  List<CustomBuildModel> _getFilteredBuilds(List<CustomBuildModel> builds) {
    return builds.where((b) {
      if (_selectedStatus == 'IN_REVIEW' && !(b.isReviewing || b.isPendingReview)) return false;
      if (_selectedStatus == 'APPROVED' && !b.isApproved) return false;
      if (_selectedStatus == 'CHANGES_REQUESTED' && !b.isChangesRequested) return false;

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final nameMatch = b.buildName.toLowerCase().contains(q);
        final idMatch = b.buildId.toString().contains(q);
        if (!nameMatch && !idMatch) return false;
      }
      return true;
    }).toList();
  }

  Color _getStatusBgColor(CustomBuildModel build) {
    if (build.isApproved) return const Color(0xFFF0FDF4);
    if (build.isChangesRequested) return const Color(0xFFFFFBEB);
    if (build.isReviewing) return const Color(0xFFEFF6FF);
    return const Color(0xFFF8FAFC);
  }

  Color _getStatusBorderColor(CustomBuildModel build) {
    if (build.isApproved) return const Color(0xFF86EFAC);
    if (build.isChangesRequested) return const Color(0xFFFDE68A);
    if (build.isReviewing) return const Color(0xFFBFDBFE);
    return AppColors.border;
  }

  Color _getStatusTextColor(CustomBuildModel build) {
    if (build.isApproved) return const Color(0xFF166534);
    if (build.isChangesRequested) return const Color(0xFFB45309);
    if (build.isReviewing) return const Color(0xFF1E40AF);
    return AppColors.secondaryText;
  }

  IconData _getStatusIcon(CustomBuildModel build) {
    if (build.isApproved) return Icons.verified_rounded;
    if (build.isChangesRequested) return Icons.warning_amber_rounded;
    if (build.isReviewing) return Icons.manage_search_rounded;
    return Icons.hourglass_top_rounded;
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
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
          'My Custom Builds',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.primaryDark,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primaryDark),
            tooltip: 'Refresh Builds',
            onPressed: _fetchBuilds,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        onPressed: () {
          _buildService.clearDraft();
          Navigator.pushNamed(context, AppRoutes.manualBuilder);
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Custom Build', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryBlue))
          : RefreshIndicator(
              color: AppColors.primaryBlue,
              onRefresh: _fetchBuilds,
              child: AnimatedBuilder(
                animation: _buildService,
                builder: (context, _) {
                  final allBuilds = _buildService.myBuilds;
                  if (allBuilds.isEmpty) {
                    return _buildEmptyState();
                  }

                  final filteredBuilds = _getFilteredBuilds(allBuilds);
                  final displayedBuilds = filteredBuilds.take(_displayedCount).toList();

                  return Column(
                    children: [
                      // Search and Filter Bar
                      Container(
                        color: AppColors.surface,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: _searchController,
                              style: const TextStyle(fontSize: 14),
                              decoration: InputDecoration(
                                hintText: 'Search build name or ID...',
                                hintStyle: const TextStyle(color: AppColors.secondaryText, fontSize: 13),
                                prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.secondaryText),
                                suffixIcon: _searchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear_rounded, size: 18),
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() {
                                            _searchQuery = '';
                                            _displayedCount = 8;
                                          });
                                        },
                                      )
                                    : null,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                filled: true,
                                fillColor: AppColors.background,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: AppColors.border),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: AppColors.border),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: AppColors.primaryBlue),
                                ),
                              ),
                              onChanged: (val) {
                                setState(() {
                                  _searchQuery = val.trim();
                                  _displayedCount = 8;
                                });
                              },
                            ),
                            const SizedBox(height: 10),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: _statusFilters.map((st) {
                                  final isSelected = _selectedStatus == st['key'];
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: FilterChip(
                                      label: Text(
                                        st['label']!,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                          color: isSelected ? Colors.white : AppColors.primaryDark,
                                        ),
                                      ),
                                      selected: isSelected,
                                      selectedColor: AppColors.primaryBlue,
                                      backgroundColor: AppColors.surface,
                                      showCheckmark: false,
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                        side: BorderSide(
                                          color: isSelected ? AppColors.primaryBlue : AppColors.border,
                                        ),
                                      ),
                                      onSelected: (val) {
                                        setState(() {
                                          _selectedStatus = st['key']!;
                                          _displayedCount = 8;
                                        });
                                      },
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Build list or empty filter message
                      Expanded(
                        child: filteredBuilds.isEmpty
                            ? ListView(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(40.0),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.filter_alt_off_rounded, size: 52, color: AppColors.secondaryText),
                                        const SizedBox(height: 12),
                                        const Text(
                                          'No builds match filters',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primaryDark,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        const Text(
                                          'Try clearing the search query or selecting a different status filter.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(color: AppColors.secondaryText, fontSize: 13),
                                        ),
                                        const SizedBox(height: 16),
                                        TextButton(
                                          onPressed: () {
                                            _searchController.clear();
                                            setState(() {
                                              _searchQuery = '';
                                              _selectedStatus = 'ALL';
                                              _displayedCount = 8;
                                            });
                                          },
                                          child: const Text('Reset All Filters'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              )
                            : ListView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                                itemCount: displayedBuilds.length + (_isLoadingMore ? 1 : 0),
                                itemBuilder: (context, index) {
                                  if (index == displayedBuilds.length) {
                                    return const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 20),
                                      child: Center(
                                        child: SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: AppColors.primaryBlue,
                                          ),
                                        ),
                                      ),
                                    );
                                  }

                                  final buildItem = displayedBuilds[index];
                                  return _buildItemCard(buildItem);
                                },
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 64),
      children: [
        Center(
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.build_circle_outlined,
              size: 44,
              color: AppColors.primaryBlue,
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'No Custom Builds Yet',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.primaryDark,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Design your custom rig with live clearance and TDP calculations, then submit for certified technician review.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: AppColors.secondaryText, height: 1.4),
        ),
        const SizedBox(height: 24),
        Center(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.tune_rounded, size: 18),
            label: const Text('Start Custom Rig Builder', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () {
              _buildService.clearDraft();
              Navigator.pushNamed(context, AppRoutes.manualBuilder);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildItemCard(CustomBuildModel build) {
    final statusBg = _getStatusBgColor(build);
    final statusBorder = _getStatusBorderColor(build);
    final statusColor = _getStatusTextColor(build);
    final statusIcon = _getStatusIcon(build);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.softShadow,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BuildStatusScreen(customBuild: build),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Build Name + Status Badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          build.buildName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Submitted: ${_formatDate(build.submittedAt)} \u2022 ID #${build.buildId}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 14, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          build.status,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 12),

              // Metrics Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _metricPill(
                    icon: Icons.payments_outlined,
                    label: 'Cost',
                    value: 'LKR ${build.totalCost.toStringAsFixed(2)}',
                    color: AppColors.primaryDark,
                  ),
                  _metricPill(
                    icon: Icons.bolt_rounded,
                    label: 'TDP Draw',
                    value: '${build.estimatedWattage} W',
                    color: const Color(0xFFD97706),
                  ),
                  _metricPill(
                    icon: Icons.memory_rounded,
                    label: 'Hardware',
                    value: '${build.selectedComponents.length} Parts',
                    color: AppColors.primaryBlue,
                  ),
                ],
              ),

              // Technician Custom Message / Note Display
              if (build.staffNotes != null && build.staffNotes!.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: statusBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            build.isApproved
                                ? Icons.check_circle_rounded
                                : build.isChangesRequested
                                    ? Icons.error_outline_rounded
                                    : Icons.info_outline_rounded,
                            size: 15,
                            color: statusColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            build.isApproved
                                ? 'Technician Approval Note:'
                                : build.isChangesRequested
                                    ? 'Technician Changes Requested:'
                                    : 'Technician Review Note:',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        build.staffNotes!.trim(),
                        style: TextStyle(
                          fontSize: 12,
                          color: statusColor,
                          height: 1.35,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Action Buttons
              if (build.isChangesRequested) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD97706),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.build_circle_rounded, size: 18),
                    label: const Text(
                      'Modify & Resubmit Build (In Review)',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    onPressed: () {
                      _buildService.loadBuildForModification(build);
                      Navigator.pushNamed(context, AppRoutes.manualBuilder);
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _metricPill({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 5),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 9.5, color: AppColors.secondaryText, fontWeight: FontWeight.w500),
              ),
              Text(
                value,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
