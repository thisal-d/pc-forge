import 'package:flutter/material.dart';

import 'core/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/main_shell_screen.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/auth/presentation/screens/register_screen.dart';
import 'features/catalog/presentation/screens/categories_screen.dart';
import 'features/catalog/presentation/screens/product_detail_screen.dart';
import 'features/catalog/presentation/screens/search_screen.dart';
import 'features/cart/presentation/screens/cart_screen.dart';
import 'features/wishlist/presentation/screens/wishlist_screen.dart';
import 'features/checkout/presentation/screens/checkout_screen.dart';
import 'features/orders/presentation/screens/order_history_screen.dart';
import 'features/orders/presentation/screens/order_detail_screen.dart';
import 'features/scanner/presentation/screens/scanner_screen.dart';
import 'features/profile/presentation/screens/profile_screen.dart';
import 'features/support/presentation/screens/support_screen.dart';
import 'features/support/presentation/screens/ai_support_chat_screen.dart';
import 'features/build_pc/presentation/screens/build_pc_hub_screen.dart';
import 'features/build_pc/presentation/screens/manual_builder_screen.dart';
import 'features/build_pc/presentation/screens/ai_pc_builder_screen.dart';
import 'features/build_pc/presentation/screens/my_custom_builds_screen.dart';

void main() {
  runApp(const PCForgeApp());
}

class PCForgeApp extends StatelessWidget {
  const PCForgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PCForge Shop',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: AppRoutes.initial,
      routes: {
        AppRoutes.login: (context) => const LoginScreen(),
        AppRoutes.register: (context) => const RegisterScreen(),
        AppRoutes.main: (context) => const MainShellScreen(),
        AppRoutes.catalog: (context) => const MainShellScreen(),
        AppRoutes.categories: (context) => const CategoriesScreen(),
        AppRoutes.productDetail: (context) => const ProductDetailScreen(),
        AppRoutes.search: (context) => const SearchScreen(),
        AppRoutes.cart: (context) => const CartScreen(),
        AppRoutes.wishlist: (context) => const WishlistScreen(),
        AppRoutes.checkout: (context) => const CheckoutScreen(),
        AppRoutes.orders: (context) => const OrderHistoryScreen(),
        AppRoutes.orderDetail: (context) => const OrderDetailScreen(),
        AppRoutes.scanner: (context) => const ScannerScreen(),
        AppRoutes.profile: (context) => const ProfileScreen(),
        AppRoutes.support: (context) => const SupportScreen(),
        AppRoutes.createTicket: (context) => const AiSupportChatScreen(),
        AppRoutes.buildPc: (context) => const BuildPcHubScreen(),
        AppRoutes.manualBuilder: (context) => const ManualBuilderScreen(),
        AppRoutes.aiBuilder: (context) => const AiPcBuilderScreen(),
        AppRoutes.myCustomBuilds: (context) => const MyCustomBuildsScreen(),
      },
    );
  }
}
