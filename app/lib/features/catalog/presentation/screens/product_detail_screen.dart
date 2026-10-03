import 'package:flutter/material.dart';
import '../../../../core/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../cart/data/cart_service.dart';
import '../../../wishlist/data/wishlist_service.dart';
import '../../data/models/product_model.dart';

class ProductDetailScreen extends StatefulWidget {
  final ProductModel? product;

  const ProductDetailScreen({super.key, this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final CartService _cartService = CartService.instance;
  final PageController _imagePageController = PageController();
  int _currentImageIndex = 0;
  int _quantity = 1;

  @override
  void dispose() {
    _imagePageController.dispose();
    super.dispose();
  }

  void _handleAddToCart(ProductModel product) {
    final error = _cartService.addItem(product, quantity: _quantity);
    if (!mounted) return;

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: AppColors.alertRed,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added $_quantity x ${product.name} to Cart'),
          backgroundColor: AppColors.stockGreen,
          action: SnackBarAction(
            label: 'View Cart',
            textColor: Colors.white,
            onPressed: () => Navigator.pushNamed(context, AppRoutes.cart),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product ??
        ModalRoute.of(context)?.settings.arguments as ProductModel? ??
        const ProductModel(
          productId: 1,
          name: 'GeForce RTX 4070 Ti 12GB',
          brand: 'NVIDIA',
          model: 'RTX 4070 Ti',
          price: 749.00,
          stockQuantity: 12,
          vram: '12GB',
          powerWattage: 240,
          description: 'High performance Ada Lovelace architecture with 12GB GDDR6X VRAM and 240W TDP.',
        );

    final maxStock = product.stockQuantity;
    final inCartQty = _cartService.getProductQuantity(product.productId);
    final galleryImages = product.allImages;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          product.brand != null ? '${product.brand} ${product.model ?? ''}' : product.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          // Wishlist Action
          ListenableBuilder(
            listenable: WishlistService.instance,
            builder: (context, _) {
              final isLiked = WishlistService.instance.isWishlisted(product.productId);
              return IconButton(
                icon: Icon(
                  isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: isLiked ? AppColors.alertRed : AppColors.primaryDark,
                ),
                tooltip: 'Wishlist',
                onPressed: () => WishlistService.instance.toggleWishlist(product),
              );
            },
          ),

          // Cart Action with Badge
          ListenableBuilder(
            listenable: _cartService,
            builder: (context, _) {
              final count = _cartService.totalCount;
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.shopping_cart_outlined),
                    tooltip: 'Cart',
                    onPressed: () => Navigator.pushNamed(context, AppRoutes.cart),
                  ),
                  if (count > 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppColors.alertRed,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Text(
                          '$count',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ==================== MULTI-IMAGE GALLERY WITH DOT INDICATORS ====================
                  Container(
                    height: 240,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.border, width: 1),
                      boxShadow: AppColors.softShadow,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      children: [
                        if (galleryImages.isNotEmpty)
                          PageView.builder(
                            controller: _imagePageController,
                            itemCount: galleryImages.length,
                            onPageChanged: (idx) => setState(() => _currentImageIndex = idx),
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Image.network(
                                  galleryImages[index],
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) => Center(
                                    child: Icon(Icons.devices_rounded, size: 70, color: Colors.grey.shade400),
                                  ),
                                  loadingBuilder: (context, child, progress) {
                                    if (progress == null) return child;
                                    return const Center(
                                      child: CircularProgressIndicator(color: AppColors.primaryBlue),
                                    );
                                  },
                                ),
                              );
                            },
                          )
                        else
                          Center(
                            child: Icon(Icons.devices_rounded, size: 80, color: Colors.grey.shade400),
                          ),

                        // Badge at top-left
                        if (product.badge != null && product.badge!.isNotEmpty)
                          Positioned(
                            top: 12,
                            left: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                gradient: AppColors.badgeGradient,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                product.badge!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),

                        // Dot Indicators at bottom
                        if (galleryImages.length > 1)
                          Positioned(
                            bottom: 12,
                            left: 0,
                            right: 0,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                galleryImages.length,
                                (idx) => AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  margin: const EdgeInsets.symmetric(horizontal: 3),
                                  width: _currentImageIndex == idx ? 18 : 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: _currentImageIndex == idx
                                        ? AppColors.primaryBlue
                                        : AppColors.border,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ==================== BRAND & TITLE ====================
                  Row(
                    children: [
                      if (product.brand != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primaryBlue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            product.brand!.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryBlue,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      const SizedBox(width: 8),
                      if (product.categoryName != null)
                        Text(
                          product.categoryName!,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.secondaryText,
                          ),
                        ),
                      const Spacer(),
                      // Official Warranty Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.stockGreen.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.stockGreen.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.verified_user_rounded, color: AppColors.stockGreen, size: 15),
                            const SizedBox(width: 4),
                            Text(
                              product.warrantyDisplay,
                              style: const TextStyle(
                                color: AppColors.stockGreen,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Product Title
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryDark,
                      height: 1.25,
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ==================== PRICE & BADGES ROW ====================
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                      boxShadow: AppColors.softShadow,
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'LKR ${product.price.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primaryBlue,
                                letterSpacing: -0.5,
                              ),
                            ),
                            // In Stock Badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: product.isInStock
                                    ? AppColors.stockGreen.withValues(alpha: 0.1)
                                    : AppColors.alertRed.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: product.isInStock
                                      ? AppColors.stockGreen.withValues(alpha: 0.3)
                                      : AppColors.alertRed.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: product.isInStock ? AppColors.stockGreen : AppColors.alertRed,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    product.isInStock ? 'In Stock (${product.stockQuantity})' : 'Out of Stock',
                                    style: TextStyle(
                                      color: product.isInStock ? AppColors.stockGreen : AppColors.alertRed,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const Divider(height: 20),

                        // Warranty & Trust Badge
                        Row(
                          children: [
                            const Icon(Icons.verified_user_rounded, color: AppColors.primaryBlue, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                product.warranty,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                            ),
                            const Text(
                              'Genuine Parts',
                              style: TextStyle(fontSize: 12, color: AppColors.secondaryText),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Cart notice if already added
                  if (inCartQty > 0) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, color: AppColors.primaryBlue, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'You currently have $inCartQty in your cart.',
                            style: const TextStyle(
                              color: AppColors.primaryDark,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // ==================== TECHNICAL SPECIFICATIONS TABLE ====================
                  const Text(
                    'Technical Specifications',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                      boxShadow: AppColors.softShadow,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        if (product.brand != null) _specRow('Brand', product.brand!),
                        if (product.model != null) _specRow('Model', product.model!),
                        if (product.chipset != null) _specRow('Chipset', product.chipset!),
                        if (product.socket != null) _specRow('Socket', product.socket!),
                        if (product.memoryType != null) _specRow('Memory Type', product.memoryType!),
                        if (product.speed != null) _specRow('Speed / Frequency', product.speed!),
                        if (product.capacity != null) _specRow('Capacity', product.capacity!),
                        if (product.vram != null) _specRow('VRAM', product.vram!),
                        if (product.powerWattage != null) _specRow('Power / TDP', '${product.powerWattage} W'),
                        if (product.efficiencyRating != null) _specRow('Efficiency', product.efficiencyRating!),
                        if (product.formFactor != null) _specRow('Form Factor', product.formFactor!),
                        _specRow('Warranty', product.warranty),
                        _specRow('Stock Units', '${product.stockQuantity} units available'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Description
                  if (product.description != null && product.description!.isNotEmpty) ...[
                    const Text(
                      'Overview',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        product.description!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.specText,
                          height: 1.45,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
          ),

          // ==================== STICKY BOTTOM BAR ====================
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border, width: 1)),
              boxShadow: [
                BoxShadow(
                  color: Color.fromRGBO(0, 0, 0, 0.05),
                  blurRadius: 10,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  // Wishlist Toggle
                  ListenableBuilder(
                    listenable: WishlistService.instance,
                    builder: (context, _) {
                      final isLiked = WishlistService.instance.isWishlisted(product.productId);
                      return Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: isLiked ? AppColors.alertRed.withValues(alpha: 0.1) : AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isLiked ? AppColors.alertRed : AppColors.border,
                          ),
                        ),
                        child: IconButton(
                          icon: Icon(
                            isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            color: isLiked ? AppColors.alertRed : AppColors.primaryDark,
                            size: 22,
                          ),
                          tooltip: 'Add to Wishlist',
                          onPressed: () => WishlistService.instance.toggleWishlist(product),
                        ),
                      );
                    },
                  ),

                  const SizedBox(width: 10),

                  // Quantity Stepper
                  Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove, size: 16),
                          onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 36),
                        ),
                        Text(
                          '$_quantity',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add, size: 16),
                          onPressed: _quantity < maxStock ? () => setState(() => _quantity++) : null,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 36),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 10),

                  // Add to Cart Primary CTA Button
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        key: const Key('detail_add_to_cart_btn'),
                        onPressed: product.isInStock ? () => _handleAddToCart(product) : null,
                        icon: const Icon(Icons.shopping_cart_outlined, size: 18),
                        label: Text(
                          product.isInStock
                              ? 'Add to Cart — LKR ${(product.price * _quantity).toStringAsFixed(2)}'
                              : 'Out of Stock',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: AppColors.border,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
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
  }

  Widget _specRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border, width: 0.8)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppColors.secondaryText, fontSize: 13),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: AppColors.primaryDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
