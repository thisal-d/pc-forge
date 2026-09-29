import 'package:flutter/material.dart';
import '../../../../core/app_routes.dart';
import '../../../../core/auth_session.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/pc_forge_app_bar.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../cart/data/cart_service.dart';
import '../../../wishlist/data/wishlist_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _showEditProfileModal(BuildContext context) {
    final user = AuthSession.instance.currentUser;
    final firstNameController =
        TextEditingController(text: user?.firstName ?? '');
    final lastNameController =
        TextEditingController(text: user?.lastName ?? '');
    final emailController = TextEditingController(text: user?.email ?? '');
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();

    bool isSubmitting = false;
    bool changePassword = false;
    String? errorMessage;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 20,
                bottom: MediaQuery.of(modalContext).viewInsets.bottom +
                    (MediaQuery.of(modalContext).padding.bottom > 0
                        ? MediaQuery.of(modalContext).padding.bottom + 12
                        : 28),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Sheet Handle
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primaryBlue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.person_rounded,
                                color: AppColors.primaryBlue,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Edit Profile',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryDark,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: AppColors.secondaryText),
                          onPressed: () => Navigator.pop(modalContext),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: AppColors.divider, height: 1),
                    const SizedBox(height: 16),

                    if (errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.alertRed.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.alertRed.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline,
                                color: AppColors.alertRed, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                errorMessage!,
                                style: const TextStyle(
                                  color: AppColors.alertRed,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // First Name
                    _buildInputField(
                      controller: firstNameController,
                      label: 'First Name',
                      icon: Icons.badge_outlined,
                    ),
                    const SizedBox(height: 12),

                    // Last Name
                    _buildInputField(
                      controller: lastNameController,
                      label: 'Last Name',
                      icon: Icons.badge_outlined,
                    ),
                    const SizedBox(height: 12),

                    // Email
                    _buildInputField(
                      controller: emailController,
                      label: 'Email Address',
                      icon: Icons.alternate_email_rounded,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 14),

                    // Password change toggle
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: CheckboxListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                        title: const Text(
                          'Change Security Password',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryDark,
                          ),
                        ),
                        activeColor: AppColors.primaryBlue,
                        value: changePassword,
                        onChanged: (val) {
                          setModalState(() => changePassword = val ?? false);
                        },
                      ),
                    ),

                    if (changePassword) ...[
                      const SizedBox(height: 12),
                      _buildInputField(
                        controller: currentPasswordController,
                        label: 'Current Password',
                        icon: Icons.lock_outline_rounded,
                        obscureText: true,
                      ),
                      const SizedBox(height: 12),
                      _buildInputField(
                        controller: newPasswordController,
                        label: 'New Password (min 6 chars)',
                        icon: Icons.password_rounded,
                        obscureText: true,
                      ),
                    ],

                    const SizedBox(height: 20),

                    ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              final first = firstNameController.text.trim();
                              final last = lastNameController.text.trim();
                              final email = emailController.text.trim();

                              if (first.isEmpty && last.isEmpty) {
                                setModalState(() {
                                  errorMessage =
                                      'Please enter at least a first or last name.';
                                });
                                return;
                              }

                              setModalState(() {
                                isSubmitting = true;
                                errorMessage = null;
                              });

                              try {
                                await AuthRepository().updateProfile(
                                  firstName: first,
                                  lastName: last,
                                  email: email.isNotEmpty ? email : null,
                                  currentPassword: changePassword
                                      ? currentPasswordController.text
                                      : null,
                                  newPassword: changePassword
                                      ? newPasswordController.text
                                      : null,
                                );

                                if (context.mounted) {
                                  Navigator.pop(modalContext);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Profile updated successfully!'),
                                      backgroundColor: AppColors.stockGreen,
                                    ),
                                  );
                                }
                              } catch (e) {
                                setModalState(() {
                                  isSubmitting = false;
                                  errorMessage = e
                                      .toString()
                                      .replaceFirst('Exception: ', '');
                                });
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'Save Changes',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  static Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 14, color: AppColors.primaryDark),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 13, color: AppColors.secondaryText),
        prefixIcon: Icon(icon, size: 20, color: AppColors.secondaryText),
        filled: true,
        fillColor: AppColors.background,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.5),
        ),
      ),
    );
  }

  void _showGuaranteeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.verified_user_rounded,
                color: AppColors.primaryBlue,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'PCForge Guarantee',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryDark,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            _GuaranteeItem(
              icon: Icons.shield_outlined,
              title: '3-Year Official Warranty',
              description:
                  'All CPUs, GPUs, motherboards and PSUs come with direct manufacturer RMA support.',
            ),
            SizedBox(height: 12),
            _GuaranteeItem(
              icon: Icons.assignment_return_outlined,
              title: '30-Day Hassle-Free Returns',
              description:
                  'Change your mind or compatibility mismatch? Return unopened parts with no restocking fee.',
            ),
            SizedBox(height: 12),
            _GuaranteeItem(
              icon: Icons.speed_rounded,
              title: 'Silicon Guarantee',
              description:
                  '100% genuine factory sealed components verified by our hardware laboratory.',
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Understood'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AuthSession.instance,
      builder: (context, _) {
        final user = AuthSession.instance.currentUser;
        final displayName = user?.displayName ?? 'Alex Doe';
        final email = user?.email ?? 'alex@example.com';
        final role = user?.roleName ?? 'Verified Builder';
        final initial =
            displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: PCForgeAppBar(
            onProfilePressed: () {}, // Already on profile
          ),
          body: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. HERO PROFILE CARD
                _buildHeroProfileCard(
                  context: context,
                  displayName: displayName,
                  email: email,
                  role: role,
                  initial: initial,
                ),

                const SizedBox(height: 16),

                // 2. INTERACTIVE STATS ROW (Cart, Wishlist, Orders)
                _buildStatsRow(context),

                const SizedBox(height: 24),

                // 3. HARDWARE & RIG STUDIO SECTION
                _buildSectionHeader(
                  title: 'RIG STUDIO & HARDWARE TOOLS',
                  badge: 'COMPATIBILITY ENGINE',
                ),
                const SizedBox(height: 8),
                _buildCardGroup([
                  _MenuRowItem(
                    icon: Icons.build_circle_rounded,
                    iconBgColor: const Color(0xFF4F46E5),
                    title: 'Custom PC Builder',
                    subtitle: 'Full rig builder with real-time TDP & bottleneck checks',
                    badgeText: 'AI CHECKS',
                    onTap: () => Navigator.pushNamed(context, AppRoutes.buildPc),
                  ),
                  _MenuRowItem(
                    icon: Icons.history_edu_rounded,
                    iconBgColor: const Color(0xFF8B5CF6),
                    title: 'My Custom Builds & Status',
                    subtitle: 'View submitted builds, technician reviews & approvals',
                    badgeText: 'REVIEW STATUS',
                    onTap: () => Navigator.pushNamed(context, AppRoutes.myCustomBuilds),
                  ),
                  _MenuRowItem(
                    icon: Icons.qr_code_scanner_rounded,
                    iconBgColor: const Color(0xFF06B6D4),
                    title: 'In-Store Barcode Scanner',
                    subtitle: 'Scan component boxes for live specs & stock pricing',
                    onTap: () => Navigator.pushNamed(context, AppRoutes.scanner),
                  ),
                  _MenuRowItem(
                    icon: Icons.memory_rounded,
                    iconBgColor: AppColors.primaryBlue,
                    title: 'Browse PC Components',
                    subtitle: 'CPUs, GPUs, Motherboards, RAM, PSUs & Cooling',
                    isLast: true,
                    onTap: () => Navigator.pushNamed(context, AppRoutes.catalog),
                  ),
                ]),

                const SizedBox(height: 24),

                // 4. ORDERS & SHOPPING SECTION
                _buildSectionHeader(title: 'ORDERS & PURCHASES'),
                const SizedBox(height: 8),
                _buildCardGroup([
                  _MenuRowItem(
                    icon: Icons.receipt_long_rounded,
                    iconBgColor: AppColors.stockGreen,
                    title: 'My Orders & Invoices',
                    subtitle: 'Track component shipments and view tax receipts',
                    onTap: () => Navigator.pushNamed(context, AppRoutes.orders),
                  ),
                  ListenableBuilder(
                    listenable: CartService.instance,
                    builder: (context, _) {
                      final count = CartService.instance.totalCount;
                      return _MenuRowItem(
                        icon: Icons.shopping_cart_rounded,
                        iconBgColor: AppColors.warningAmber,
                        title: 'Shopping Cart',
                        subtitle: 'Review selected hardware components',
                        badgeCount: count > 0 ? count : null,
                        onTap: () => Navigator.pushNamed(context, AppRoutes.cart),
                      );
                    },
                  ),
                  ListenableBuilder(
                    listenable: WishlistService.instance,
                    builder: (context, _) {
                      final count = WishlistService.instance.totalCount;
                      return _MenuRowItem(
                        icon: Icons.favorite_rounded,
                        iconBgColor: const Color(0xFFF43F5E),
                        title: 'Wishlist & Saved Rigs',
                        subtitle: 'Saved PC parts to monitor for price drops',
                        badgeCount: count > 0 ? count : null,
                        isLast: true,
                        onTap: () =>
                            Navigator.pushNamed(context, AppRoutes.wishlist),
                      );
                    },
                  ),
                ]),

                const SizedBox(height: 24),

                // 5. SUPPORT & WARRANTY
                _buildSectionHeader(title: 'SUPPORT & SERVICE'),
                const SizedBox(height: 8),
                _buildCardGroup([
                  _MenuRowItem(
                    icon: Icons.headset_mic_rounded,
                    iconBgColor: const Color(0xFF8B5CF6),
                    title: 'Support & Warranty (RMA)',
                    subtitle: 'Report hardware faults, thermals & claim warranty',
                    onTap: () => Navigator.pushNamed(context, AppRoutes.support),
                  ),
                  _MenuRowItem(
                    icon: Icons.verified_user_rounded,
                    iconBgColor: const Color(0xFF10B981),
                    title: 'PCForge Official Guarantee',
                    subtitle: '3-Year manufacturer warranty & 30-day returns',
                    isLast: true,
                    onTap: () => _showGuaranteeDialog(context),
                  ),
                ]),

                const SizedBox(height: 24),

                // 6. APP VERSION & SYSTEM INFO
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                    boxShadow: AppColors.softShadow,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.dns_outlined,
                          size: 18,
                          color: AppColors.secondaryText,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'PCForge Mobile v2.4.0',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryDark,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: const BoxDecoration(
                                    color: AppColors.stockGreen,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  'API Connected • Localhost 5000',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.secondaryText,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          'ID #${user?.userId ?? 1}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 7. SIGN OUT BUTTON
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => _confirmSignOut(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.alertRed.withValues(alpha: 0.3),
                        ),
                        boxShadow: AppColors.softShadow,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(
                            Icons.logout_rounded,
                            color: AppColors.alertRed,
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Sign Out of Account',
                            style: TextStyle(
                              color: AppColors.alertRed,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- HERO PROFILE CARD WIDGET ---
  Widget _buildHeroProfileCard({
    required BuildContext context,
    required String displayName,
    required String email,
    required String role,
    required String initial,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A3BB6).withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background ambient graphic accents
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
          ),
          Positioned(
            left: 80,
            bottom: -30,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Avatar with verified indicator
                    Stack(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.2),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.85),
                              width: 2.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              initial,
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: AppColors.stockGreen,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),

                    // User Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            email,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.85),
                              fontWeight: FontWeight.w400,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),

                          // Role / Tier Pill
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.35),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.bolt_rounded,
                                  color: Color(0xFFFBBF24),
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  role.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // Edit Profile Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    key: const Key('edit_profile_btn'),
                    onPressed: () => _showEditProfileModal(context),
                    icon: const Icon(Icons.edit_outlined, size: 16, color: Colors.white),
                    label: const Text(
                      'Edit Profile Details',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.6),
                        width: 1.2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      backgroundColor: Colors.white.withValues(alpha: 0.12),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- STATS ROW WIDGET ---
  Widget _buildStatsRow(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        CartService.instance,
        WishlistService.instance,
      ]),
      builder: (context, _) {
        final cartCount = CartService.instance.totalCount;
        final wishlistCount = WishlistService.instance.totalCount;

        return Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.shopping_cart_outlined,
                iconColor: AppColors.primaryBlue,
                iconBgColor: const Color(0xFFEFF6FF),
                value: '$cartCount',
                label: 'In Cart',
                onTap: () => Navigator.pushNamed(context, AppRoutes.cart),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                icon: Icons.favorite_rounded,
                iconColor: const Color(0xFFF43F5E),
                iconBgColor: const Color(0xFFFFF1F2),
                value: '$wishlistCount',
                label: 'Saved Parts',
                onTap: () => Navigator.pushNamed(context, AppRoutes.wishlist),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                icon: Icons.local_shipping_outlined,
                iconColor: AppColors.stockGreen,
                iconBgColor: const Color(0xFFECFDF5),
                value: 'Orders',
                label: 'Tracking',
                onTap: () => Navigator.pushNamed(context, AppRoutes.orders),
              ),
            ),
          ],
        );
      },
    );
  }

  // --- SECTION HEADER ---
  Widget _buildSectionHeader({required String title, String? badge}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.secondaryText,
              letterSpacing: 1.0,
            ),
          ),
          if (badge != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                badge,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryBlue,
                  letterSpacing: 0.5,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // --- CARD GROUP ---
  Widget _buildCardGroup(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        children: children,
      ),
    );
  }

  // --- SIGN OUT CONFIRMATION DIALOG ---
  void _confirmSignOut(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.logout_rounded, color: AppColors.alertRed, size: 22),
            SizedBox(width: 10),
            Text(
              'Sign Out?',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.primaryDark,
              ),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to sign out of your PCForge account? Your local cart and preferences will be preserved.',
          style: TextStyle(color: AppColors.secondaryText, fontSize: 14),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: AppColors.secondaryText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              AuthSession.instance.clearSession();
              Navigator.pushNamedAndRemoveUntil(
                context,
                AppRoutes.login,
                (route) => false,
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.alertRed,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}

// --- STAT CARD COMPONENT ---
class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String value;
  final String label;
  final VoidCallback onTap;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.value,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
            boxShadow: AppColors.softShadow,
          ),
          child: Column(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.secondaryText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- MENU ROW ITEM COMPONENT ---
class _MenuRowItem extends StatelessWidget {
  final IconData icon;
  final Color iconBgColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final int? badgeCount;
  final String? badgeText;
  final bool isLast;

  const _MenuRowItem({
    required this.icon,
    required this.iconBgColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badgeCount,
    this.badgeText,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.vertical(
              top: isLast ? Radius.zero : const Radius.circular(16),
              bottom: isLast ? const Radius.circular(16) : Radius.zero,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  // Leading Icon with soft rounded container
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: iconBgColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: iconBgColor, size: 22),
                  ),
                  const SizedBox(width: 14),

                  // Title & Subtitle
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryDark,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (badgeText != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryBlue.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  badgeText!,
                                  style: const TextStyle(
                                    color: AppColors.primaryBlue,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.secondaryText,
                            fontWeight: FontWeight.w400,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // Optional badge count
                  if (badgeCount != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$badgeCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(width: 8),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.secondaryText,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (!isLast)
          const Divider(
            height: 1,
            indent: 72,
            endIndent: 16,
            color: AppColors.divider,
          ),
      ],
    );
  }
}

// --- GUARANTEE ITEM COMPONENT ---
class _GuaranteeItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _GuaranteeItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.primaryBlue, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.secondaryText,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
