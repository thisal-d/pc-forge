import 'package:flutter/material.dart';
import '../../../../core/app_routes.dart';
import '../../data/models/order_model.dart';
import '../../../support/presentation/screens/ai_support_chat_screen.dart';

class OrderDetailScreen extends StatelessWidget {
  final OrderModel? order;
  final bool isNewOrder;

  const OrderDetailScreen({
    super.key,
    this.order,
    this.isNewOrder = false,
  });

  @override
  Widget build(BuildContext context) {
    OrderModel? displayOrder = order;
    bool newOrderFlag = isNewOrder;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) {
      displayOrder = args['order'] as OrderModel?;
      newOrderFlag = args['isNewOrder'] as bool? ?? false;
    } else if (args is OrderModel) {
      displayOrder = args;
    }

    if (displayOrder == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Order Details')),
        body: const Center(child: Text('No order data found.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(newOrderFlag ? 'Order Confirmation' : displayOrder.formattedOrderId),
        automaticallyImplyLeading: !newOrderFlag,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // If New Order: Confirmation Banner
            if (newOrderFlag) ...[
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
                      displayOrder.paymentMethod.contains('Cash')
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
                    _infoRow('Payment Status', '${displayOrder.status} (${displayOrder.paymentMethod})'),
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
                  final item = displayOrder!.items[index];
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Paid:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
            ),
            const SizedBox(height: 28),

            // Action Buttons
            if (newOrderFlag) ...[
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
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AiSupportChatScreen(orderId: displayOrder?.orderId),
                    ),
                  );
                },
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Claim Warranty / Service Request (AI)'),
                style: OutlinedButton.styleFrom(
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
