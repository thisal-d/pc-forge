import 'package:flutter/material.dart';
import '../../../../core/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/models/order_model.dart';
import '../../data/order_service.dart';
import '../../../support/presentation/screens/ai_support_chat_screen.dart';
import '../../../support/presentation/screens/create_service_request_screen.dart';

class OrderDetailScreen extends StatefulWidget {
  final OrderModel? order;
  final bool isNewOrder;

  const OrderDetailScreen({
    super.key,
    this.order,
    this.isNewOrder = false,
  });

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  OrderModel? _currentOrder;
  bool _isNewOrder = false;
  bool _isCancelling = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_currentOrder == null) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic>) {
        _currentOrder = args['order'] as OrderModel?;
        _isNewOrder = args['isNewOrder'] as bool? ?? false;
      } else if (args is OrderModel) {
        _currentOrder = args;
        _isNewOrder = widget.isNewOrder;
      } else {
        _currentOrder = widget.order;
        _isNewOrder = widget.isNewOrder;
      }
    }
  }

  bool get _canCancel {
    if (_currentOrder == null) return false;
    final s = _currentOrder!.status.toLowerCase();
    return s == 'order placed' || s == 'processing';
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'ORDER PLACED':
        return const Color(0xFFD97706);
      case 'PROCESSING':
        return AppColors.primaryBlue;
      case 'READY FOR DELIVERY':
      case 'READY FOR PICKUP':
        return const Color(0xFF7C3AED);
      case 'OUT FOR DELIVERY':
        return const Color(0xFF2563EB);
      case 'PAID & COMPLETED':
      case 'PAID':
        return const Color(0xFF16A34A);
      case 'CANCELLED':
        return AppColors.alertRed;
      default:
        return AppColors.secondaryText;
    }
  }

  Future<void> _handleCancelOrder() async {
    if (_currentOrder == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Order?'),
        content: Text(
          'Are you sure you want to cancel ${_currentOrder!.formattedOrderId}?\n\n'
          'All reserved hardware components will be returned to store inventory immediately.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Order'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.alertRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm Cancellation'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isCancelling = true);

    try {
      final updated = await OrderService.instance.cancelOrder(_currentOrder!.orderId);
      if (!mounted) return;
      setState(() {
        _currentOrder = updated;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order has been cancelled. Components returned to inventory.'),
          backgroundColor: AppColors.alertRed,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to cancel order: $e'),
          backgroundColor: AppColors.alertRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayOrder = _currentOrder;

    if (displayOrder == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Order Details')),
        body: const Center(child: Text('No order data found.')),
      );
    }

    final isPaid = displayOrder.status.toLowerCase().contains('paid');
    final isCancelled = displayOrder.status.toLowerCase() == 'cancelled';
    final isPickup = displayOrder.paymentMethod.toLowerCase().contains('pickup') ||
        displayOrder.paymentMethod.toLowerCase().contains('counter');

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNewOrder ? 'Order Confirmation' : displayOrder.formattedOrderId),
        automaticallyImplyLeading: !_isNewOrder,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // If New Order: Confirmation Banner
            if (_isNewOrder) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  border: Border.all(color: Colors.green.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green.shade700, size: 56),
                    const SizedBox(height: 12),
                    const Text(
                      'Order Placed Successfully!',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      !isPickup
                          ? 'Component stock verified and parts reserved. Please pay the courier driver in cash upon delivery.'
                          : 'Component stock verified and reserved for Showroom Pickup. Please visit our Colombo store to inspect and pay at the counter.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.green.shade900),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Cancelled Banner
            if (isCancelled) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  border: Border.all(color: const Color(0xFFFECACA)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.cancel_rounded, color: AppColors.alertRed, size: 32),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Order Cancelled',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.alertRed,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'This order has been cancelled and components were returned to inventory.',
                            style: TextStyle(fontSize: 12, color: Color(0xFF991B1B)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Order Metadata Card
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _infoRow('Order Reference', displayOrder.formattedOrderId, isBold: true),
                    const Divider(),
                    _infoRow('Order Date', _formatDate(displayOrder.createdAt)),
                    const Divider(),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 120,
                            child: Text('Order Status', style: TextStyle(color: Colors.grey, fontSize: 13)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: _getStatusColor(displayOrder.status).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _getStatusColor(displayOrder.status).withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              displayOrder.status.toUpperCase(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _getStatusColor(displayOrder.status),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(),
                    _infoRow('Payment Method', displayOrder.paymentMethod),
                    const Divider(),
                    _infoRow('Delivery Address', displayOrder.shippingAddress),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Ordered Items
            const Text(
              'Purchased Components',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: displayOrder.items.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = displayOrder.items[index];
                  return ListTile(
                    leading: const Icon(Icons.memory, size: 28),
                    title: Text(item.productName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: Text('${item.quantity} × LKR ${item.unitPrice.toStringAsFixed(2)}'),
                    trailing: Text(
                      'LKR ${item.totalPrice.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),

            // Total Amount
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isPaid ? 'Total Paid:' : 'Total Amount:',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'LKR ${displayOrder.totalAmount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  if (!isPaid && !isCancelled) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          !isPickup
                              ? 'Pay courier in cash upon delivery'
                              : 'Pay at Colombo showroom counter upon pickup',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Customer Cancellation Button
            if (_canCancel) ...[
              OutlinedButton.icon(
                key: const Key('cancel_order_btn'),
                onPressed: _isCancelling ? null : _handleCancelOrder,
                icon: _isCancelling
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.alertRed),
                      )
                    : const Icon(Icons.cancel_outlined, color: AppColors.alertRed),
                label: Text(
                  _isCancelling ? 'Cancelling Order...' : 'Cancel Order',
                  style: const TextStyle(color: AppColors.alertRed, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.alertRed),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Action Buttons
            if (_isNewOrder) ...[
              ElevatedButton.icon(
                key: const Key('continue_shopping_btn'),
                onPressed: () {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    AppRoutes.catalog,
                    (route) => false,
                  );
                },
                icon: const Icon(Icons.storefront),
                label: const Text('Continue Shopping'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(context, AppRoutes.orders);
                },
                icon: const Icon(Icons.history),
                label: const Text('View All Orders'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ] else ...[
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CreateServiceRequestScreen(initialOrderId: displayOrder.orderId),
                    ),
                  );
                },
                icon: const Icon(Icons.assignment_outlined),
                label: const Text('Submit Service Request'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AiSupportChatScreen(orderId: displayOrder.orderId),
                    ),
                  );
                },
                icon: const Icon(Icons.auto_awesome, color: AppColors.primaryBlue),
                label: const Text('Troubleshoot with AI Assistant'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryBlue,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
