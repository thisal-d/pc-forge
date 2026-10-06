import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/models/service_request_model.dart';
import '../../data/support_service.dart';
import 'ai_support_chat_screen.dart';
import 'create_service_request_screen.dart';

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
  DateTime? _startDate;
  DateTime? _endDate;
  int _displayedCount = 8;
  bool _isLoadingMore = false;

  final List<Map<String, String>> _statusFilters = [
    {'key': 'ALL', 'label': 'All Requests'},
    {'key': 'PENDING', 'label': 'Pending'},
    {'key': 'IN PROGRESS', 'label': 'In Progress'},
    {'key': 'COMPLETED', 'label': 'Completed'},
    {'key': 'NO SHOW', 'label': 'No Show'},
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

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryBlue,
              onPrimary: Colors.white,
              onSurface: AppColors.primaryDark,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _displayedCount = 8;
      });
    }
  }

  void _clearDateRange() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _displayedCount = 8;
    });
  }

  bool _isCancellable(String status) {
    final s = status.toUpperCase().replaceAll('_', ' ');
    return s == 'PENDING';
  }

  Future<void> _confirmCancelRequest(ServiceRequestModel sr) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Service Request'),
        content: const Text('Are you sure you want to cancel this service request?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Request'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.alertRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Cancel Service Request'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _supportService.cancelServiceRequest(sr.serviceRequestId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Service Request ${sr.serviceRequestNumber} has been cancelled.'),
              backgroundColor: AppColors.alertRed,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          final errorMsg = e.toString().replaceAll('ApiException: ', '').replaceAll('Exception: ', '');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to cancel request: $errorMsg'),
              backgroundColor: AppColors.alertRed,
            ),
          );
        }
      }
    }
  }

  List<ServiceRequestModel> _getFilteredRequests(List<ServiceRequestModel> requests) {
    return requests.where((sr) {
      if (_selectedStatus != 'ALL') {
        String norm(String s) => s.toUpperCase().replaceAll('_', ' ');
        final rStatus = norm(sr.status);
        final fStatus = norm(_selectedStatus);

        if (fStatus == 'IN PROGRESS') {
          if (rStatus != 'IN PROGRESS' && rStatus != 'IN SERVICE' && rStatus != 'UNDER REVIEW' && rStatus != 'SCHEDULED') {
            return false;
          }
        } else if (fStatus == 'COMPLETED') {
          if (rStatus != 'COMPLETED' && rStatus != 'RESOLVED') return false;
        } else if (fStatus == 'CANCELLED') {
          if (rStatus != 'CANCELLED' && rStatus != 'CANCELED') return false;
        } else if (fStatus == 'NO SHOW') {
          if (rStatus != 'NO SHOW') return false;
        } else if (rStatus != fStatus) {
          return false;
        }
      }

      // Date Range Filter (Preferred date or CreatedAt)
      if (_startDate != null) {
        DateTime? rDate;
        if (sr.preferredDate != null) {
          rDate = DateTime.tryParse(sr.preferredDate!);
        }
        rDate ??= sr.createdAt;
        final startDay = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
        if (rDate.isBefore(startDay)) return false;
      }

      if (_endDate != null) {
        DateTime? rDate;
        if (sr.preferredDate != null) {
          rDate = DateTime.tryParse(sr.preferredDate!);
        }
        rDate ??= sr.createdAt;
        final endDay = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59, 999);
        if (rDate.isAfter(endDay)) return false;
      }

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final numMatch = sr.serviceRequestNumber.toLowerCase().contains(q);
        final titleMatch = sr.title.toLowerCase().contains(q);
        final catMatch = sr.problemCategory.toLowerCase().contains(q);
        final descMatch = sr.problemDescription.toLowerCase().contains(q);
        if (!numMatch && !titleMatch && !catMatch && !descMatch) return false;
      }
      return true;
    }).toList();
  }

  Color _getStatusColor(String status) {
    final s = status.toUpperCase().replaceAll('_', ' ');
    switch (s) {
      case 'PENDING':
        return AppColors.warningAmber;
      case 'IN PROGRESS':
      case 'IN SERVICE':
      case 'UNDER REVIEW':
      case 'SCHEDULED':
        return const Color(0xFF6366F1);
      case 'COMPLETED':
      case 'RESOLVED':
        return AppColors.stockGreen;
      case 'NO SHOW':
        return const Color(0xFFF97316);
      case 'CANCELLED':
      case 'CANCELED':
        return AppColors.alertRed;
      default:
        return AppColors.secondaryText;
    }
  }

  int _getStatusStepIndex(String status) {
    final s = status.toUpperCase().replaceAll('_', ' ');
    switch (s) {
      case 'PENDING':
        return 0;
      case 'IN PROGRESS':
      case 'IN SERVICE':
      case 'UNDER REVIEW':
      case 'SCHEDULED':
        return 1;
      case 'COMPLETED':
      case 'RESOLVED':
        return 2;
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
              const SizedBox(height: 12),

              // Title & Description Banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sr.title.isNotEmpty ? sr.title : sr.problemDescription,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.primaryDark),
                    ),
                    if (sr.description != null && sr.description!.isNotEmpty && sr.description != sr.title) ...[
                      const SizedBox(height: 6),
                      Text(
                        sr.description!,
                        style: const TextStyle(fontSize: 13, color: AppColors.secondaryText, height: 1.4),
                      ),
                    ],
                  ],
                ),
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

              if (sr.preferredDate != null) ...[
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
                const SizedBox(height: 8),
              ],

              Row(
                children: [
                  const Icon(Icons.access_time_rounded, size: 16, color: AppColors.secondaryText),
                  const SizedBox(width: 6),
                  Text(
                    'Submitted: ${sr.createdAt.day}/${sr.createdAt.month}/${sr.createdAt.year}',
                    style: const TextStyle(color: AppColors.secondaryText, fontSize: 13),
                  ),
                ],
              ),

              const Divider(height: 24),

              if (sr.description != null && sr.description!.isNotEmpty) ...[
                const Text(
                  'Details',
                  style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.primaryDark),
                ),
                const SizedBox(height: 6),
                Text(
                  sr.description!,
                  style: const TextStyle(color: AppColors.primaryDark, fontSize: 14, height: 1.4),
                ),
              ],

              // Customer Cancel Request Button
              if (_isCancellable(sr.status)) ...[
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _confirmCancelRequest(sr);
                  },
                  icon: const Icon(Icons.cancel_outlined, color: AppColors.alertRed),
                  label: const Text('Cancel Service Request', style: TextStyle(color: AppColors.alertRed, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.alertRed),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
            icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primaryBlue),
            tooltip: 'Create Service Request',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateServiceRequestScreen()),
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
            MaterialPageRoute(builder: (_) => const CreateServiceRequestScreen()),
          );
          _loadRequests();
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Service Request', style: TextStyle(fontWeight: FontWeight.bold)),
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
                          'Need help with a PC or hardware part? Submit a service request manually or get guided AI troubleshooting.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: AppColors.secondaryText),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const CreateServiceRequestScreen()),
                                  );
                                  _loadRequests();
                                },
                                icon: const Icon(Icons.add_rounded, size: 18),
                                label: const Text('Submit Request'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryBlue,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const AiSupportChatScreen()),
                                  );
                                  _loadRequests();
                                },
                                icon: const Icon(Icons.auto_awesome, size: 18, color: AppColors.primaryBlue),
                                label: const Text('AI Diagnose'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  side: const BorderSide(color: AppColors.primaryBlue),
                                  foregroundColor: AppColors.primaryBlue,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ),
                          ],
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
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  style: const TextStyle(fontSize: 14),
                                  decoration: InputDecoration(
                                    hintText: 'Search request #, title, category...',
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
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                tooltip: 'Filter by Date Range',
                                onPressed: _pickDateRange,
                                icon: Icon(
                                  Icons.date_range_rounded,
                                  color: (_startDate != null || _endDate != null) ? AppColors.primaryBlue : AppColors.secondaryText,
                                ),
                              ),
                            ],
                          ),
                          if (_startDate != null && _endDate != null) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primaryBlue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.event_available_rounded, size: 14, color: AppColors.primaryBlue),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Date: ${_startDate!.year}-${_startDate!.month.toString().padLeft(2, '0')}-${_startDate!.day.toString().padLeft(2, '0')} to ${_endDate!.year}-${_endDate!.month.toString().padLeft(2, '0')}-${_endDate!.day.toString().padLeft(2, '0')}',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
                                  ),
                                  const SizedBox(width: 6),
                                  InkWell(
                                    onTap: _clearDateRange,
                                    child: const Icon(Icons.close_rounded, size: 14, color: AppColors.primaryBlue),
                                  ),
                                ],
                              ),
                            ),
                          ],
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
                                              _startDate = null;
                                              _endDate = null;
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
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        sr.serviceRequestNumber,
                                                        style: const TextStyle(
                                                          fontWeight: FontWeight.w800,
                                                          fontSize: 13,
                                                          color: AppColors.primaryBlue,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        sr.title.isNotEmpty ? sr.title : sr.problemDescription,
                                                        style: const TextStyle(
                                                          fontWeight: FontWeight.w700,
                                                          fontSize: 15,
                                                          color: AppColors.primaryDark,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ],
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
                                            if (sr.description != null && sr.description!.isNotEmpty && sr.description != sr.title) ...[
                                              const SizedBox(height: 6),
                                              Text(
                                                sr.description!,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(fontSize: 13, color: AppColors.secondaryText),
                                              ),
                                            ],
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
                                                  const Icon(Icons.calendar_today_outlined, size: 12, color: AppColors.secondaryText),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    sr.preferredTime != null && sr.preferredTime!.isNotEmpty
                                                        ? '${sr.preferredDate} at ${sr.preferredTime}'
                                                        : '${sr.preferredDate}',
                                                    style: const TextStyle(fontSize: 11, color: AppColors.secondaryText, fontWeight: FontWeight.w500),
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
                                            if (_isCancellable(sr.status)) ...[
                                              const Divider(height: 16),
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.end,
                                                children: [
                                                  TextButton.icon(
                                                    onPressed: () => _confirmCancelRequest(sr),
                                                    icon: const Icon(Icons.cancel_outlined, size: 14, color: AppColors.alertRed),
                                                    label: const Text(
                                                      'Cancel Service Request',
                                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.alertRed),
                                                    ),
                                                    style: TextButton.styleFrom(
                                                      visualDensity: VisualDensity.compact,
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
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
