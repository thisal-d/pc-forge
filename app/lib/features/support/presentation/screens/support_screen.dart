import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/models/service_request_model.dart';
import '../../data/support_service.dart';
import 'ai_support_chat_screen.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final SupportService _supportService = SupportService.instance;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = false;
  String _selectedStatus = 'ALL';
  String _searchQuery = '';
  int _displayedCount = 8;
  bool _isLoadingMore = false;

  final List<Map<String, String>> _statusFilters = [
    {'key': 'ALL', 'label': 'All Requests'},
    {'key': 'PENDING', 'label': 'Pending'},
    {'key': 'UNDER_REVIEW', 'label': 'Under Review'},
    {'key': 'SCHEDULED', 'label': 'Scheduled'},
    {'key': 'RESOLVED', 'label': 'Resolved'},
    {'key': 'CANCELLED', 'label': 'Cancelled'},
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadRequests();
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
    final filtered = _getFilteredRequests(_supportService.serviceRequests);
    if (_isLoadingMore || _displayedCount >= filtered.length) return;

    setState(() => _isLoadingMore = true);
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    setState(() {
      _displayedCount = (_displayedCount + 8).clamp(0, filtered.length);
      _isLoadingMore = false;
    });
  }

  Future<void> _loadRequests() async {
    setState(() {
      _isLoading = true;
      _displayedCount = 8;
      _isLoadingMore = false;
    });
    await _supportService.loadServiceRequests();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  List<ServiceRequestModel> _getFilteredRequests(List<ServiceRequestModel> requests) {
    return requests.where((sr) {
      if (_selectedStatus != 'ALL' && sr.status.toUpperCase() != _selectedStatus) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final numMatch = sr.serviceRequestNumber.toLowerCase().contains(q);
        final catMatch = sr.problemCategory.toLowerCase().contains(q);
        final descMatch = sr.problemDescription.toLowerCase().contains(q);
        if (!numMatch && !catMatch && !descMatch) return false;
      }
      return true;
    }).toList();
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return AppColors.warningAmber;
      case 'UNDER_REVIEW':
        return AppColors.primaryBlue;
      case 'SCHEDULED':
      case 'RESOLVED':
        return AppColors.stockGreen;
      case 'IN_SERVICE':
        return const Color(0xFF8B5CF6);
      case 'CANCELLED':
        return AppColors.alertRed;
      default:
        return AppColors.secondaryText;
    }
  }

  int _getStatusStepIndex(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return 0;
      case 'UNDER_REVIEW':
        return 1;
      case 'SCHEDULED':
      case 'IN_SERVICE':
        return 2;
      case 'RESOLVED':
        return 3;
      default:
        return 0;
    }
  }

  void _showRequestDetails(ServiceRequestModel sr) {
    final currentStep = _getStatusStepIndex(sr.status);
    final timelineSteps = ['Pending', 'Under Review', 'In Service', 'Resolved'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).padding.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    sr.serviceRequestNumber,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(sr.status).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      sr.status,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _getStatusColor(sr.status),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Stepper Progress
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Service Progress',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: List.generate(timelineSteps.length * 2 - 1, (index) {
                        if (index % 2 == 0) {
                          final stepIdx = index ~/ 2;
                          final isPassed = stepIdx <= currentStep;
                          final isCurrent = stepIdx == currentStep;
                          return Column(
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isPassed ? AppColors.primaryBlue : Colors.white,
                                  border: Border.all(
                                    color: isPassed ? AppColors.primaryBlue : AppColors.border,
                                    width: 1.5,
                                  ),
                                ),
                                child: Center(
                                  child: isPassed
                                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                                      : Container(
                                          width: 6,
                                          height: 6,
                                          decoration: const BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: AppColors.border,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                timelineSteps[stepIdx],
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                                  color: isPassed ? AppColors.primaryDark : AppColors.secondaryText,
                                ),
                              ),
                            ],
                          );
                        } else {
                          final prevStep = index ~/ 2;
                          final isPassed = prevStep < currentStep;
                          return Expanded(
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              height: 2,
                              color: isPassed ? AppColors.primaryBlue : AppColors.border,
                            ),
                          );
                        }
                      }),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Problem & Category
              Text(
                'Problem Category: ${sr.problemCategory}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: 8),

              if (sr.orderId != null) ...[
                Row(
                  children: [
                    const Icon(Icons.receipt_long_rounded, size: 16, color: AppColors.secondaryText),
                    const SizedBox(width: 6),
                    Text(
                      'Linked Order: #ORD-${sr.orderId}',
                      style: const TextStyle(color: AppColors.secondaryText, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
              ],

              if (sr.productName != null) ...[
                Row(
                  children: [
                    const Icon(Icons.memory_rounded, size: 16, color: AppColors.secondaryText),
                    const SizedBox(width: 6),
                    Text(
                      'Hardware: ${sr.productName}',
                      style: const TextStyle(color: AppColors.secondaryText, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
              ],

              Row(
                children: [
                  const Icon(Icons.verified_user_outlined, size: 16, color: AppColors.secondaryText),
                  const SizedBox(width: 6),
                  Text(
                    'Warranty: ${sr.warrantyStatus}',
                    style: TextStyle(
                      color: sr.warrantyStatus == 'Active' ? AppColors.stockGreen : AppColors.alertRed,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),

              if (sr.preferredDate != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.secondaryText),
                    const SizedBox(width: 6),
                    Text(
                      'Service Appointment: ${sr.preferredDate} (${sr.preferredTime ?? "10:00 AM"})',
                      style: const TextStyle(color: AppColors.primaryDark, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],

              const Divider(height: 24),

              const Text(
                'Customer Description',
                style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.primaryDark),
              ),
              const SizedBox(height: 6),
              Text(
                sr.problemDescription,
                style: const TextStyle(color: AppColors.primaryDark, fontSize: 14, height: 1.4),
              ),

              if (sr.troubleshootingSummary != null && sr.troubleshootingSummary!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFC7D2FE)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.smart_toy_outlined, size: 16, color: Color(0xFF4338CA)),
                          const SizedBox(width: 6),
                          Text(
                            'AI Troubleshooting Summary (${sr.attemptCount} Attempts)',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF4338CA)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        sr.troubleshootingSummary!,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B), height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],

              if (sr.technicianNotes != null && sr.technicianNotes!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.build_circle_outlined, size: 16, color: Color(0xFF166534)),
                          SizedBox(width: 6),
                          Text(
                            'Technician Notes & Diagnostics',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF166534)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        sr.technicianNotes!,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF14532D), height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAiBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryBlue.withValues(alpha: 0.12),
            AppColors.primaryBlue.withValues(alpha: 0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.smart_toy_rounded, color: AppColors.primaryBlue, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'After-Sales Support Assistant',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.primaryDark,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Safe step-by-step troubleshooting, warranty checks & service requests',
                  style: TextStyle(fontSize: 11, color: AppColors.secondaryText),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AiSupportChatScreen()),
              );
              _loadRequests();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Start Chat'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Service Requests'),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome, color: AppColors.primaryBlue),
            tooltip: 'AI Support Assistant',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AiSupportChatScreen()),
              );
              _loadRequests();
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _loadRequests,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AiSupportChatScreen()),
          );
          _loadRequests();
        },
        icon: const Icon(Icons.auto_awesome_rounded),
        label: const Text('New Service Request (AI)', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryBlue))
          : AnimatedBuilder(
              animation: _supportService,
              builder: (context, _) {
                final allRequests = _supportService.serviceRequests;
                if (allRequests.isEmpty) {
                  return RefreshIndicator(
                    color: AppColors.primaryBlue,
                    onRefresh: _loadRequests,
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        _buildAiBanner(),
                        const SizedBox(height: 32),
                        Icon(Icons.assignment_outlined, size: 64, color: AppColors.secondaryText.withValues(alpha: 0.5)),
                        const SizedBox(height: 16),
                        const Center(
                          child: Text(
                            'No Service Requests Yet',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Need help with a PC or hardware part? Chat with our AI After-Sales Assistant or submit a service request.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: AppColors.secondaryText),
                        ),
                      ],
                    ),
                  );
                }

                final filteredRequests = _getFilteredRequests(allRequests);
                final displayedRequests = filteredRequests.take(_displayedCount).toList();

                return Column(
                  children: [
                    // Search & Filter Toolbar
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
                              hintText: 'Search request #, category, issue...',
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

                    // Filtered Requests List with Pull to Refresh & Infinite Scroll
                    Expanded(
                      child: RefreshIndicator(
                        color: AppColors.primaryBlue,
                        onRefresh: _loadRequests,
                        child: filteredRequests.isEmpty
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
                                          'No service requests match filters',
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
                                padding: const EdgeInsets.all(16),
                                itemCount: displayedRequests.length + 1 + (_isLoadingMore ? 1 : 0),
                                itemBuilder: (context, index) {
                                  if (index == 0) {
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 16),
                                      child: _buildAiBanner(),
                                    );
                                  }

                                  if (index == displayedRequests.length + 1) {
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

                                  final sr = displayedRequests[index - 1];
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    elevation: 0,
                                    color: AppColors.surface,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(16),
                                      onTap: () => _showRequestDetails(sr),
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  sr.serviceRequestNumber,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w800,
                                                    fontSize: 15,
                                                    color: AppColors.primaryDark,
                                                  ),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: _getStatusColor(sr.status).withValues(alpha: 0.15),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Text(
                                                    sr.status,
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w700,
                                                      color: _getStatusColor(sr.status),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              sr.problemDescription,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(fontSize: 13, color: AppColors.primaryDark),
                                            ),
                                            const SizedBox(height: 10),
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.background,
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    sr.problemCategory,
                                                    style: const TextStyle(fontSize: 10, color: AppColors.secondaryText),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                if (sr.preferredDate != null) ...[
                                                  Text(
                                                    '📅 ${sr.preferredDate}',
                                                    style: const TextStyle(fontSize: 11, color: AppColors.secondaryText),
                                                  ),
                                                  const SizedBox(width: 8),
                                                ],
                                                const Spacer(),
                                                Text(
                                                  '${sr.createdAt.day}/${sr.createdAt.month}/${sr.createdAt.year}',
                                                  style: const TextStyle(fontSize: 11, color: AppColors.secondaryText),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}
