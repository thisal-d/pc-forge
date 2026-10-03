import 'package:flutter/material.dart';
import '../../features/cart/data/cart_service.dart';
import '../../features/cart/presentation/screens/cart_screen.dart';
import '../../features/catalog/presentation/screens/catalog_screen.dart';
import '../../features/catalog/presentation/screens/categories_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/wishlist/data/wishlist_service.dart';
import '../../features/wishlist/presentation/screens/wishlist_screen.dart';
import '../theme/app_colors.dart';

class MainShellScreen extends StatefulWidget {
  final int initialIndex;

  const MainShellScreen({super.key, this.initialIndex = 0});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  late int _currentIndex;

  final List<Widget> _screens = const [
    CatalogScreen(isHomeTab: true),
    CategoriesScreen(),
    CartScreen(isTab: true),
    WishlistScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  void _onTabTapped(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(
            top: BorderSide(color: AppColors.border, width: 1),
          ),
          boxShadow: [
            BoxShadow(
              color: Color.fromRGBO(0, 0, 0, 0.04),
              blurRadius: 10,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            height: 62,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  index: 0,
                  label: 'Home',
                  icon: Icons.home_rounded,
                  outlineIcon: Icons.home_outlined,
                ),
                _buildNavItem(
                  index: 1,
                  label: 'Categories',
                  icon: Icons.grid_view_rounded,
                  outlineIcon: Icons.grid_view_outlined,
                ),
                _buildNavItem(
                  index: 2,
                  label: 'Cart',
                  icon: Icons.shopping_cart_rounded,
                  outlineIcon: Icons.shopping_cart_outlined,
                  badgeListenable: CartService.instance,
                  getBadgeCount: () => CartService.instance.totalCount,
                ),
                _buildNavItem(
                  index: 3,
                  label: 'Wishlist',
                  icon: Icons.favorite_rounded,
                  outlineIcon: Icons.favorite_border_rounded,
                  badgeListenable: WishlistService.instance,
                  getBadgeCount: () => WishlistService.instance.totalCount,
                ),
                _buildNavItem(
                  index: 4,
                  label: 'Account',
                  icon: Icons.person_rounded,
                  outlineIcon: Icons.person_outline_rounded,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required String label,
    required IconData icon,
    required IconData outlineIcon,
    Listenable? badgeListenable,
    int Function()? getBadgeCount,
  }) {
    final isSelected = _currentIndex == index;

    Widget iconWidget = Icon(
      isSelected ? icon : outlineIcon,
      size: 22,
      color: isSelected ? AppColors.primaryBlue : AppColors.secondaryText,
    );

    if (badgeListenable != null && getBadgeCount != null) {
      iconWidget = ListenableBuilder(
        listenable: badgeListenable,
        builder: (context, _) {
          final count = getBadgeCount();
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                isSelected ? icon : outlineIcon,
                size: 22,
                color: isSelected ? AppColors.primaryBlue : AppColors.secondaryText,
              ),
              if (count > 0)
                Positioned(
                  top: -4,
                  right: -8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.alertRed,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Center(
                      child: Text(
                        '$count',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      );
    }

    return InkWell(
      onTap: () => _onTabTapped(index),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            iconWidget,
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppColors.primaryBlue : AppColors.secondaryText,
              ),
            ),
            const SizedBox(height: 3),

            // Active Blue Underline Indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 2.5,
              width: isSelected ? 20 : 0,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primaryBlue : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
