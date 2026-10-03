import 'package:flutter/material.dart';
import '../../../../core/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/product_card.dart';
import '../../../cart/data/cart_service.dart';
import '../../../catalog/data/models/product_model.dart';
import '../../data/wishlist_service.dart';

class WishlistScreen extends StatelessWidget {
  const WishlistScreen({super.key});

  void _handleAddToCart(BuildContext context, ProductModel product) {
    final error = CartService.instance.addItem(product, quantity: 1);
    if (!context.mounted) return;

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
          content: Text('Added ${product.name} to Cart'),
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
    final wishlist = WishlistService.instance;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Wishlist'),
        actions: [
          ListenableBuilder(
            listenable: wishlist,
            builder: (context, _) {
              if (wishlist.isEmpty) return const SizedBox.shrink();
              return TextButton(
                onPressed: () => wishlist.clear(),
                child: const Text(
                  'Clear All',
                  style: TextStyle(color: AppColors.secondaryText, fontSize: 13),
                ),
              );
            },
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: wishlist,
        builder: (context, _) {
          final items = wishlist.items;

          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: const BoxDecoration(
                        color: AppColors.specPillBackground,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.favorite_border_rounded,
                        size: 40,
                        color: AppColors.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Your Wishlist is Empty',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Save components you want to review or buy later.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.secondaryText, fontSize: 14),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.pushNamed(context, AppRoutes.catalog),
                      icon: const Icon(Icons.explore_outlined, size: 18),
                      label: const Text('Explore Parts'),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final product = items[index];
              return ProductCard(
                product: product,
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    AppRoutes.productDetail,
                    arguments: product,
                  );
                },
                onAddToCart: () => _handleAddToCart(context, product),
              );
            },
          );
        },
      ),
    );
  }
}
