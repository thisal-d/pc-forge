import 'package:flutter/material.dart';
import 'app_network_image.dart';
import '../../features/catalog/data/models/product_model.dart';
import '../../features/wishlist/data/wishlist_service.dart';
import '../theme/app_colors.dart';

class ProductCard extends StatelessWidget {
  final ProductModel product;
  final VoidCallback? onTap;
  final VoidCallback? onAddToCart;

  const ProductCard({
    super.key,
    required this.product,
    this.onTap,
    this.onAddToCart,
  });


  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: AppColors.softShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ==================== LEFT SECTION: IMAGE CONTAINER ====================
                Stack(
                  children: [
                    Container(
                      width: 104,
                      height: 108,
                      decoration: BoxDecoration(
                        color: AppColors.imageContainerBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border.withValues(alpha: 0.6), width: 1),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: AppNetworkImage(
                        imageUrl: product.imageUrl,
                        categoryName: product.categoryName,
                        productName: product.name,
                        width: 104,
                        height: 108,
                        fit: BoxFit.cover,
                        fallbackIconSize: 38,
                        showCategoryTag: true,
                      ),
                    ),

                    // Badge Pill at top-left (e.g. "🔥 Popular" / "🔥 Best Seller")
                    if (product.badge != null && product.badge!.isNotEmpty)
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            gradient: AppColors.badgeGradient,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryBlue.withValues(alpha: 0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Text(
                            product.badge!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(width: 12),

                // ==================== MIDDLE & DETAILS SECTION ====================
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Top Row: Brand & Wishlist Button
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (product.brand != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primaryBlue.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                product.brand!.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primaryBlue,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          const Spacer(),

                          // Wishlist Toggle Button
                          ListenableBuilder(
                            listenable: WishlistService.instance,
                            builder: (context, _) {
                              final isLiked = WishlistService.instance.isWishlisted(product.productId);
                              return InkWell(
                                key: Key('wishlist_toggle_${product.productId}'),
                                borderRadius: BorderRadius.circular(16),
                                onTap: () => WishlistService.instance.toggleWishlist(product),
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Icon(
                                    isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                    size: 20,
                                    color: isLiked ? AppColors.alertRed : AppColors.secondaryText,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 4),

                      // Product Title
                      Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryDark,
                          height: 1.25,
                        ),
                      ),

                      const SizedBox(height: 3),

                      // Sub-spec Description
                      Text(
                        product.subSpecDisplay,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.secondaryText,
                        ),
                      ),

                      const SizedBox(height: 6),

                      // Spec Chips Row
                      if (product.specChips.isNotEmpty) ...[
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: product.specChips.take(3).map((spec) {
                              return Container(
                                margin: const EdgeInsets.only(right: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.specPillBackground,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.border.withValues(alpha: 0.5), width: 0.5),
                                ),
                                child: Text(
                                  spec,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.specText,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 6),
                      ],

                      const SizedBox(height: 8),

                      // Bottom Row: Price, Stock & Add to Cart
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'LKR ${product.price.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primaryBlue,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: product.isInStock ? AppColors.stockGreen : AppColors.alertRed,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        product.isInStock ? 'In Stock' : 'Out of Stock',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: product.isInStock ? AppColors.stockGreen : AppColors.alertRed,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),

                          // Add to Cart Button
                          ElevatedButton.icon(
                            key: Key('add_to_cart_btn_${product.productId}'),
                            onPressed: product.isInStock ? onAddToCart : null,
                            icon: const Icon(Icons.shopping_cart_outlined, size: 14),
                            label: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'Add to Cart',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryBlue,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: AppColors.border,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                              visualDensity: VisualDensity.compact,
                              elevation: 0,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

}
