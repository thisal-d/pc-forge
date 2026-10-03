import 'package:flutter/material.dart';
import '../../../../core/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../services/api_service.dart';
import '../../data/models/order_model.dart';
import '../../data/order_service.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = false;
  String _selectedStatus = 'ALL';
  String _searchQuery = '';
  int _displayedCount = 8;
  bool _isLoadingMore = false;

  final List<String> _statusFilters = [
    'ALL',
    'PAID',
    'PROCESSING',
    'SHIPPED',
    'DELIVERED',
    'CANCELLED',
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _fetchLiveOrders();
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
    final orderService = OrderService.instance;
    final totalFiltered = _getFilteredOrders(orderService.orders).length;
    if (_isLoadingMore || _displayedCount >= totalFiltered) return;

    setState(() => _isLoadingMore = true);
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    setState(() {
      _displayedCount = (_displayedCount + 8).clamp(0, totalFiltered);
      _isLoadingMore = false;
    });
  }

  Future<void> _fetchLiveOrders() async {
    setState(() {
      _isLoading = true;
      _displayedCount = 8;
      _isLoadingMore = false;
    });
    await OrderService.instance.loadOrders();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  List<OrderModel> _getFilteredOrders(List<OrderModel> orders) {
    return orders.where((o) {
      if (_selectedStatus != 'ALL' && o.status.toUpperCase() != _selectedStatus) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final idMatch = o.formattedOrderId.toLowerCase().contains(q) ||
            o.orderId.toString().contains(q);
        final itemsMatch = o.items.any((i) => i.productName.toLowerCase().contains(q));
        if (!idMatch && !itemsMatch) return false;
      }
      return true;
    }).toList();
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'PAID':
        return const Color(0xFF16A34A);
      case 'PROCESSING':
        return AppColors.primaryBlue;
      case 'SHIPPED':
        return const Color(0xFF7C3AED);
      case 'DELIVERED':
        return const Color(0xFF0D9488);
      case 'CANCELLED':
        return AppColors.alertRed;
      default:
        return AppColors.secondaryText;
    }
  }

  Widget _buildStatusChip(String status, bool isSelected) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(
          status == 'ALL' ? 'All Orders' : status,
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
            _selectedStatus = status;
            _displayedCount = 8;
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orderService = OrderService.instance;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Orders'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Orders',
            onPressed: _fetchLiveOrders,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryBlue),
            )
          : ListenableBuilder(
              listenable: orderService,
              builder: (context, _) {
                final allOrders = orderService.orders;

                if (allOrders.isEmpty) {
                  return RefreshIndicator(
                    color: AppColors.primaryBlue,
                    onRefresh: _fetchLiveOrders,
                    child: ListView(
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.7,
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.receipt_long_outlined, size: 72, color: Colors.grey.shade400),
                                const SizedBox(height: 16),
                                const Text(
                                  'No Orders Placed Yet',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'When you checkout components from the shop, your receipts and order tracking will appear here.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey),
                                ),
                                const SizedBox(height: 20),
                                ElevatedButton(
                                  onPressed: () => Navigator.pushReplacementNamed(context, AppRoutes.catalog),
                                  child: const Text('Browse Products'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final filteredOrders = _getFilteredOrders(allOrders);
                final displayedOrders = filteredOrders.take(_displayedCount).toList();

                return Column(
                  children: [
                    // Search & Filters Header
                    Container(
                      color: AppColors.surface,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Search Box
                          TextField(
                            controller: _searchController,
                            style: const TextStyle(fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'Search order number or product...',
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
                          // Status Filter Chips
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: _statusFilters.map((st) {
                                return _buildStatusChip(st, _selectedStatus == st);
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Filtered List or Empty Message
                    Expanded(
                      child: RefreshIndicator(
                        color: AppColors.primaryBlue,
                        onRefresh: _fetchLiveOrders,
                        child: filteredOrders.isEmpty
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
                                          'No orders match filters',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primaryDark,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        const Text(
                                          'Try adjusting your search query or selecting a different status chip.',
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
                                itemCount: displayedOrders.length + (_isLoadingMore ? 1 : 0),
                                itemBuilder: (context, index) {
                                  if (index == displayedOrders.length) {
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

                                  final order = displayedOrders[index];
                                  final itemCount = order.totalItemCount;
                                  final subtitle = order.items.isNotEmpty
                                      ? '$itemCount items • ${order.items.map((i) => i.productName).join(', ')}'
                                      : '$itemCount items purchased';

                                  final statusColor = _getStatusColor(order.status);

                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: const BorderSide(color: AppColors.border),
                                    ),
                                    color: AppColors.surface,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(12),
                                      onTap: () async {
                                        OrderModel detailedOrder = order;
                                        if (detailedOrder.items.isEmpty) {
                                          try {
                                            final res = await ApiService().fetchOrderById(order.orderId);
                                            detailedOrder = OrderModel.fromJson(res);
                                          } catch (_) {}
                                        }
                                        if (!context.mounted) return;
                                        Navigator.pushNamed(
                                          context,
                                          AppRoutes.orderDetail,
                                          arguments: {'order': detailedOrder, 'isNewOrder': false},
                                        );
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  order.formattedOrderId,
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: statusColor.withValues(alpha: 0.12),
                                                    borderRadius: BorderRadius.circular(20),
                                                    border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                                                  ),
                                                  child: Text(
                                                    order.status.toUpperCase(),
                                                    style: TextStyle(
                                                      color: statusColor,
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w700,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              subtitle,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(color: AppColors.secondaryText, fontSize: 13),
                                            ),
                                            const Divider(height: 20),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  _formatDate(order.createdAt),
                                                  style: const TextStyle(color: AppColors.secondaryText, fontSize: 12),
                                                ),
                                                Text(
                                                  'LKR ${order.totalAmount.toStringAsFixed(2)}',
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppColors.primaryBlue,
                                                  ),
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

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}

