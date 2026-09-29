import 'package:flutter/material.dart';
import '../../features/cart/data/cart_service.dart';
import '../../features/wishlist/data/wishlist_service.dart';
import '../app_routes.dart';
import '../theme/app_colors.dart';

class PCForgeAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback? onCartPressed;
  final VoidCallback? onWishlistPressed;
  final VoidCallback? onProfilePressed;
  final bool showActions;

  const PCForgeAppBar({
    super.key,
    this.onCartPressed,
    this.onWishlistPressed,
    this.onProfilePressed,
    this.showActions = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              // Brand Logo in rounded square
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryBlue.withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(3),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Brand Title & Caption
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: const TextSpan(
                      children: [
                        TextSpan(
                          text: 'PC',
                          style: TextStyle(
                            color: AppColors.primaryDark,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        TextSpan(
                          text: 'Forge',
                          style: TextStyle(
                            color: AppColors.primaryBlue,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Text(
                    'Shop',
                    style: TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                      height: 1.0,
                    ),
                  ),
                ],
              ),

              const Spacer(),

              if (showActions) ...[
                // Shopping Cart with Red Notification Badge
                ListenableBuilder(
                  listenable: CartService.instance,
                  builder: (context, _) {
                    final count = CartService.instance.totalCount;
                    return IconButton(
                      key: const Key('catalog_cart_btn'),
                      tooltip: 'Shopping Cart',
                      onPressed: onCartPressed ??
                          () => Navigator.pushNamed(context, AppRoutes.cart),
                      icon: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          const Icon(
                            Icons.shopping_cart_outlined,
                            color: AppColors.primaryDark,
                            size: 24,
                          ),
                          if (count > 0)
                            Positioned(
                              top: -4,
                              right: -6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.alertRed,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 1.5),
                                ),
                                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                                child: Center(
                                  child: Text(
                                    '$count',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      height: 1.0,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),

                // Heart (Wishlist) Icon
                ListenableBuilder(
                  listenable: WishlistService.instance,
                  builder: (context, _) {
                    final wishCount = WishlistService.instance.totalCount;
                    return IconButton(
                      key: const Key('catalog_wishlist_btn'),
                      tooltip: 'Wishlist',
                      onPressed: onWishlistPressed ??
                          () {
                            // If navigation shell is used or direct route
                            Navigator.pushNamed(context, '/wishlist');
                          },
                      icon: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          const Icon(
                            Icons.favorite_border_rounded,
                            color: AppColors.primaryDark,
                            size: 24,
                          ),
                          if (wishCount > 0)
                            Positioned(
                              top: -4,
                              right: -6,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryBlue,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 1.5),
                                ),
                                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                                child: Center(
                                  child: Text(
                                    '$wishCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      height: 1.0,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),

                // Account/Profile Icon
                IconButton(
                  key: const Key('catalog_profile_btn'),
                  tooltip: 'Account',
                  onPressed: onProfilePressed ??
                      () => Navigator.pushNamed(context, AppRoutes.profile),
                  icon: const Icon(
                    Icons.person_outline_rounded,
                    color: AppColors.primaryDark,
                    size: 24,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
