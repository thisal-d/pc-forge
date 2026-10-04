import 'package:flutter/material.dart';
import '../../../../core/app_routes.dart';
import '../../../../core/auth_session.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../cart/data/cart_service.dart';
import '../../../orders/data/order_service.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cartService = CartService.instance;
  final _orderService = OrderService.instance;

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();

  int _currentStep = 0; // 0: Shipping, 1: Payment, 2: Review
  String _selectedPaymentMethod = 'Cash on Delivery';
  bool _isProcessing = false;

  bool get _isCodEligible => _cartService.totalAmount <= 100000;

  @override
  void initState() {
    super.initState();
    final user = AuthSession.instance.currentUser;
    _nameController.text = user?.displayName ?? 'Alex Doe';
    _phoneController.text = '0771234567';
    _addressController.text = 'No. 45, Flower Road';
    _cityController.text = 'Colombo 07';

    // If order total <= 100,000, default to COD.
    // If order total > 100,000, COD is not available, default to In-Store Pickup & Payment.
    if (_isCodEligible) {
      _selectedPaymentMethod = 'Cash on Delivery';
    } else {
      _selectedPaymentMethod = 'In-Store Pickup & Payment';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _handlePlaceOrder() async {
    if (!_formKey.currentState!.validate()) {
      setState(() => _currentStep = 0);
      return;
    }
    if (_cartService.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your cart is empty!')),
      );
      return;
    }

    // Safety enforce: If order is > 100,000, COD cannot be used
    if (!_isCodEligible && _selectedPaymentMethod == 'Cash on Delivery') {
      _selectedPaymentMethod = 'In-Store Pickup & Payment';
    }

    setState(() => _isProcessing = true);

    final shippingAddress =
        '${_nameController.text.trim()}, ${_phoneController.text.trim()}, ${_addressController.text.trim()}, ${_cityController.text.trim()}';

    try {
      final user = AuthSession.instance.currentUser;
      final order = await _orderService.placeOrder(
        userId: user?.userId ?? 1,
        shippingAddress: shippingAddress,
        paymentMethod: _selectedPaymentMethod,
        cartItems: _cartService.items,
        totalAmount: _cartService.totalAmount,
      );

      if (!mounted) return;

      // Navigate to Order Details (Confirmation Mode)
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.orderDetail,
        (route) => route.settings.name == AppRoutes.catalog,
        arguments: {'order': order, 'isNewOrder': true},
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to place order: $e'),
          backgroundColor: AppColors.alertRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartItems = _cartService.items;

    if (cartItems.isEmpty && !_isProcessing) {
      return Scaffold(
        appBar: AppBar(title: const Text('Checkout')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.shopping_cart_outlined, size: 64, color: AppColors.secondaryText),
              const SizedBox(height: 16),
              const Text('No items to checkout.', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pushReplacementNamed(context, AppRoutes.catalog),
                child: const Text('Browse Products'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Checkout & Order'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Stepper Progress Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  _stepIndicator(0, 'Shipping'),
                  _stepDivider(0),
                  _stepIndicator(1, 'Payment'),
                  _stepDivider(1),
                  _stepIndicator(2, 'Review'),
                ],
              ),
            ),

            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_currentStep == 0) _buildShippingStep(),
                    if (_currentStep == 1) _buildPaymentStep(),
                    if (_currentStep == 2) _buildReviewStep(cartItems),
                  ],
                ),
              ),
            ),

            // Bottom Action Navigation Bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  if (_currentStep > 0) ...[
                    OutlinedButton(
                      onPressed: _isProcessing ? null : () => setState(() => _currentStep--),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      ),
                      child: const Text('Back'),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: ElevatedButton(
                      key: _currentStep == 2 ? const Key('place_order_btn') : null,
                      onPressed: _isProcessing
                          ? null
                          : () {
                              if (_currentStep == 0) {
                                if (_formKey.currentState!.validate()) {
                                  setState(() => _currentStep = 1);
                                }
                              } else if (_currentStep == 1) {
                                setState(() => _currentStep = 2);
                              } else {
                                _handlePlaceOrder();
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _isProcessing
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                ),
                                SizedBox(width: 12),
                                Text('Reserving stock & confirming...'),
                              ],
                            )
                          : Text(
                              _currentStep == 0
                                  ? 'Continue to Payment'
                                  : _currentStep == 1
                                      ? 'Review Order'
                                      : _selectedPaymentMethod == 'Cash on Delivery'
                                          ? 'Place COD Order — LKR ${_cartService.totalAmount.toStringAsFixed(2)}'
                                          : 'Reserve for Store Pickup — LKR ${_cartService.totalAmount.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepIndicator(int stepIndex, String title) {
    final isActive = _currentStep >= stepIndex;
    final isCurrent = _currentStep == stepIndex;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? AppColors.primaryBlue : AppColors.specPillBackground,
            border: Border.all(
              color: isActive ? AppColors.primaryBlue : AppColors.border,
            ),
          ),
          child: Center(
            child: isActive && !isCurrent && _currentStep > stepIndex
                ? const Icon(Icons.check, size: 14, color: Colors.white)
                : Text(
                    '${stepIndex + 1}',
                    style: TextStyle(
                      color: isActive ? Colors.white : AppColors.secondaryText,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
            color: isCurrent ? AppColors.primaryBlue : AppColors.secondaryText,
          ),
        ),
      ],
    );
  }

  Widget _stepDivider(int stepIndex) {
    final isDone = _currentStep > stepIndex;
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        height: 2,
        color: isDone ? AppColors.primaryBlue : AppColors.border,
      ),
    );
  }

  Widget _buildShippingStep() {
    final isCod = _isCodEligible;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isCod ? '1. Shipping & Delivery Address' : '1. Showroom Pickup & Contact Details',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          isCod
              ? 'Enter the delivery destination for courier delivery (Eligible for Cash on Delivery)'
              : 'Orders of LKR 100,000 or more require In-Store Showroom Pickup & Counter Payment',
          style: const TextStyle(fontSize: 12, color: AppColors.secondaryText),
        ),
        const SizedBox(height: 16),

        // Showroom Notice for High-Value Orders
        if (!isCod) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.storefront_rounded, color: Color(0xFFD97706), size: 24),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'In-Store Showroom Collection Required',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF92400E)),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Orders of LKR 100,000 or more exceed courier cash limits. Your components will be held for 48 hours at our Colombo Flagship Showroom:\nNo. 45, Galle Road, Colombo 03.\n\nPlease enter your contact details below to generate your In-Store Collection Pass.',
                        style: TextStyle(fontSize: 12, color: Color(0xFFB45309), height: 1.35),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],

        TextFormField(
          key: const Key('checkout_name_field'),
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Recipient Name *',
            prefixIcon: Icon(Icons.person_outline),
          ),
          validator: (v) => v == null || v.trim().isEmpty ? 'Enter recipient name' : null,
        ),
        const SizedBox(height: 12),

        TextFormField(
          key: const Key('checkout_phone_field'),
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Phone Number (for verification) *',
            prefixIcon: Icon(Icons.phone_outlined),
          ),
          validator: (v) => v == null || v.trim().isEmpty ? 'Enter phone number' : null,
        ),
        const SizedBox(height: 12),

        TextFormField(
          key: const Key('checkout_address_field'),
          controller: _addressController,
          decoration: InputDecoration(
            labelText: isCod ? 'Street Address *' : 'Contact / Billing Address *',
            prefixIcon: const Icon(Icons.home_outlined),
          ),
          validator: (v) => v == null || v.trim().isEmpty ? 'Enter address' : null,
        ),
        const SizedBox(height: 12),

        TextFormField(
          key: const Key('checkout_city_field'),
          controller: _cityController,
          decoration: const InputDecoration(
            labelText: 'City / Postal Code *',
            prefixIcon: Icon(Icons.location_city_outlined),
          ),
          validator: (v) => v == null || v.trim().isEmpty ? 'Enter city' : null,
        ),
      ],
    );
  }

  Widget _buildPaymentStep() {
    final total = _cartService.totalAmount;
    final isCod = _isCodEligible;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '2. Payment & Fulfillment Method',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
        ),
        const SizedBox(height: 4),
        Text(
          isCod
              ? 'Orders up to LKR 100,000 can be paid via Cash on Delivery or collected in-store.'
              : 'Orders exceeding LKR 100,000 require In-Store Showroom Pickup & Counter Payment.',
          style: const TextStyle(fontSize: 12, color: AppColors.secondaryText),
        ),
        const SizedBox(height: 16),

        // Policy Banner
        if (!isCod) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'High-Value Order Protection (> LKR 100,000)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF92400E),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Total: LKR ${total.toStringAsFixed(2)}. Due to courier cash limits and transit safety, Cash on Delivery is disabled. Please collect and inspect your hardware at our showroom counter and pay upon pickup (Card POS, Cash, or Bank Transfer).',
                        style: const TextStyle(fontSize: 12, color: Color(0xFFB45309), height: 1.35),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFA7F3D0)),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle_outline_rounded, color: Color(0xFF059669), size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Order total is LKR 100,000 or less — Cash on Delivery (COD) courier delivery is available!',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF065F46)),
                  ),
                ),
              ],
            ),
          ),
        ],

        // Option 1: Cash on Delivery (Enabled only if < 100,000)
        _buildPaymentOptionCard(
          id: 'Cash on Delivery',
          title: 'Cash on Delivery (COD)',
          subtitle: isCod
              ? 'Pay cash directly to courier upon receiving your package'
              : 'Unavailable: Order exceeds LKR 100,000 courier cash limit',
          icon: Icons.local_shipping_outlined,
          isEnabled: isCod,
        ),

        const SizedBox(height: 12),

        // Option 2: In-Store Pickup & Payment (Always available)
        _buildPaymentOptionCard(
          id: 'In-Store Pickup & Payment',
          title: 'In-Store Pickup & Counter Payment',
          subtitle: 'Collect at Colombo Showroom, inspect hardware, and pay at counter (Card POS / Cash / Bank Transfer)',
          icon: Icons.storefront_outlined,
          isEnabled: true,
        ),
      ],
    );
  }

  Widget _buildPaymentOptionCard({
    required String id,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isEnabled,
  }) {
    final isSelected = isEnabled && _selectedPaymentMethod == id;

    return Opacity(
      opacity: isEnabled ? 1.0 : 0.6,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primaryBlue : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isEnabled ? AppColors.softShadow : null,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: isEnabled
              ? () {
                  setState(() => _selectedPaymentMethod = id);
                }
              : () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Cash on Delivery is unavailable for orders of LKR 100,000 or more. Please use In-Store Showroom Pickup.'),
                      backgroundColor: Color(0xFFD97706),
                      duration: Duration(seconds: 3),
                    ),
                  );
                },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primaryBlue.withValues(alpha: 0.12)
                        : (isEnabled ? AppColors.specPillBackground : Colors.grey.shade100),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: isSelected
                        ? AppColors.primaryBlue
                        : (isEnabled ? AppColors.primaryDark : Colors.grey),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: isEnabled ? AppColors.primaryDark : Colors.grey.shade600,
                              ),
                            ),
                          ),
                          if (!isEnabled) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEE2E2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Limit Exceeded',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFDC2626),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: isEnabled ? AppColors.secondaryText : Colors.grey.shade500,
                          fontSize: 12,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Radio<String>(
                  value: id,
                  groupValue: _selectedPaymentMethod,
                  activeColor: AppColors.primaryBlue,
                  onChanged: isEnabled
                      ? (val) {
                          if (val != null) setState(() => _selectedPaymentMethod = val);
                        }
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReviewStep(List cartItems) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '3. Review & Confirmation',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
        ),
        const SizedBox(height: 4),
        const Text(
          'Review your order components and pickup/shipping details before placing',
          style: TextStyle(fontSize: 12, color: AppColors.secondaryText),
        ),
        const SizedBox(height: 16),

        // Destination preview
        Container(
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
              Icon(
                _selectedPaymentMethod == 'In-Store Pickup & Payment'
                    ? Icons.storefront_outlined
                    : Icons.location_on_outlined,
                color: AppColors.primaryBlue,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedPaymentMethod == 'In-Store Pickup & Payment'
                          ? 'In-Store Showroom Pickup'
                          : 'Courier Home Delivery',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _selectedPaymentMethod == 'In-Store Pickup & Payment'
                          ? 'PCForge Flagship Showroom: No. 45, Galle Road, Colombo 03\nPass Holder: ${_nameController.text.trim()} • Tel: ${_phoneController.text.trim()}'
                          : '${_nameController.text.trim()} • ${_addressController.text.trim()}, ${_cityController.text.trim()}\nTel: ${_phoneController.text.trim()}',
                      style: const TextStyle(color: AppColors.secondaryText, fontSize: 12),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _currentStep = 0),
                child: const Text('Edit', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Payment Method preview
        Container(
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
              Icon(
                _selectedPaymentMethod == 'Cash on Delivery'
                    ? Icons.local_shipping_outlined
                    : Icons.storefront_outlined,
                color: AppColors.primaryBlue,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedPaymentMethod,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _selectedPaymentMethod == 'Cash on Delivery'
                          ? 'Pay cash directly to courier upon receiving your package.'
                          : 'Pay at showroom counter via Card POS, Cash, or verified Bank Transfer upon collecting.',
                      style: const TextStyle(color: AppColors.secondaryText, fontSize: 12),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _currentStep = 1),
                child: const Text('Change', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Items list
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
            boxShadow: AppColors.softShadow,
          ),
          child: Column(
            children: [
              for (int i = 0; i < cartItems.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.memory_rounded, color: AppColors.primaryBlue, size: 20),
                  title: Text(
                    cartItems[i].product?.name ?? 'Component',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text('Qty: ${cartItems[i].quantity} × LKR ${cartItems[i].product?.price.toStringAsFixed(2)}'),
                  trailing: Text(
                    'LKR ${((cartItems[i].product?.price ?? 0.0) * cartItems[i].quantity).toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Cost Breakdown Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Subtotal:', style: TextStyle(color: AppColors.secondaryText, fontSize: 13)),
                  Text('LKR ${_cartService.subtotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _selectedPaymentMethod == 'In-Store Pickup & Payment'
                        ? 'Store Pickup Fee:'
                        : 'Courier Delivery Fee:',
                    style: const TextStyle(color: AppColors.secondaryText, fontSize: 13),
                  ),
                  Text(
                    _selectedPaymentMethod == 'In-Store Pickup & Payment'
                        ? 'FREE (LKR 0.00)'
                        : 'LKR ${_cartService.shippingAmount.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const Divider(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Order Total:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text(
                    'LKR ${_cartService.totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
