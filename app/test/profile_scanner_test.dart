import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pc_forge_mobile/core/auth_session.dart';
import 'package:pc_forge_mobile/features/auth/data/auth_repository.dart';
import 'package:pc_forge_mobile/features/auth/data/models/user_model.dart';
import 'package:pc_forge_mobile/features/catalog/data/catalog_repository.dart';
import 'package:pc_forge_mobile/features/catalog/presentation/screens/search_screen.dart';
import 'package:pc_forge_mobile/features/profile/presentation/screens/profile_screen.dart';
import 'package:pc_forge_mobile/features/scanner/presentation/screens/scanner_screen.dart';
import 'package:pc_forge_mobile/services/api_service.dart';

class MockSearchApiService extends ApiService {
  @override
  Future<List<Map<String, dynamic>>> fetchProducts({
    int? categoryId,
    String? brand,
    String? searchQuery,
    double? minPrice,
    double? maxPrice,
    bool inStockOnly = false,
    String sortBy = 'name_asc',
    String? socket,
    String? chipset,
    String? memoryType,
    String? speed,
    String? capacity,
    String? vram,
    String? efficiency,
  }) async {
    return [
      {
        'productId': 1,
        'name': 'GeForce RTX 4070 Ti 12GB',
        'brand': 'NVIDIA',
        'price': 749.00,
        'stockQuantity': 5,
      }
    ];
  }
}

class MockAuthApiService extends ApiService {
  @override
  Future<Map<String, dynamic>> updateProfile({
    String? firstName,
    String? lastName,
    String? email,
    String? currentPassword,
    String? newPassword,
    String? token,
  }) async {
    return {
      'userId': 1,
      'firstName': firstName ?? 'Alex',
      'lastName': lastName ?? 'Doe',
      'email': email ?? 'alex@example.com',
      'roleName': 'Customer',
    };
  }
}

void main() {
  setUp(() {
    AuthSession.instance.setSession(
      user: const UserModel(
        userId: 1,
        email: 'alex@example.com',
        firstName: 'Alex',
        lastName: 'Doe',
        roleName: 'Customer',
      ),
      token: 'mock-jwt-token',
    );
  });

  group('Profile Update Unit Tests (Member 01)', () {
    test('AuthSession notifies listeners and updates current user', () {
      bool notified = false;
      AuthSession.instance.addListener(() {
        notified = true;
      });

      final updated = AuthSession.instance.currentUser!.copyWith(
        firstName: 'Alexander',
        lastName: 'Smith',
      );

      AuthSession.instance.updateCurrentUser(updated);

      expect(notified, isTrue);
      expect(AuthSession.instance.currentUser!.displayName, 'Alexander Smith');
      expect(AuthSession.instance.currentUser!.firstName, 'Alexander');
    });

    test('AuthRepository updateProfile updates session state', () async {
      final repo = AuthRepository(apiService: MockAuthApiService());
      final user = await repo.updateProfile(
        firstName: 'Alex',
        lastName: 'Forge',
        email: 'alex.forge@example.com',
      );

      expect(user.firstName, 'Alex');
      expect(user.lastName, 'Forge');
      expect(user.email, 'alex.forge@example.com');
      expect(AuthSession.instance.currentUser!.displayName, 'Alex Forge');
    });
  });

  group('ProfileScreen Widget Tests', () {
    testWidgets('Renders user profile details and Edit Profile button', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ProfileScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Alex Doe'), findsOneWidget);
      expect(find.text('CUSTOMER'), findsOneWidget);
      expect(find.text('Edit Profile Details'), findsOneWidget);
      expect(find.text('Support & Warranty (RMA)'), findsOneWidget);

      // Tap Edit Profile Details button
      await tester.tap(find.text('Edit Profile Details'));
      await tester.pumpAndSettle();

      expect(find.text('Edit Profile'), findsOneWidget);
      expect(find.text('Save Changes'), findsOneWidget);
      expect(find.text('First Name'), findsOneWidget);
    });
  });

  group('ScannerScreen Widget Tests (Device Feature §8)', () {
    testWidgets('Renders viewfinder and simulates hardware barcode lookup', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ScannerScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('In-Store Scanner (Device Feature)'), findsOneWidget);
      expect(find.text('Align component barcode / QR inside the frame'), findsOneWidget);
      expect(find.text('Simulate Barcode Scan (Tap any component):'), findsOneWidget);

      // Tap a preset hardware barcode chip (RTX 4070 Ti)
      final rtxChip = find.textContaining('RTX 4070 Ti');
      expect(rtxChip, findsOneWidget);

      await tester.tap(rtxChip);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      // Verify product bottom sheet opens
      expect(find.text('Component Verified!'), findsOneWidget);
      expect(find.text('View Specs'), findsOneWidget);
      expect(find.text('Add to Cart'), findsOneWidget);
    });
  });

  group('SearchScreen Widget Tests', () {
    testWidgets('Renders search input and popular hardware suggestion chips', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SearchScreen(
            repository: CatalogRepository(apiService: MockSearchApiService()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Search PC Components'), findsOneWidget);
      expect(find.text('Popular Searches'), findsOneWidget);
      expect(find.text('RTX 4070 Ti'), findsOneWidget);
      expect(find.text('B650'), findsOneWidget);

      // Tap suggestion chip
      await tester.tap(find.text('RTX 4070 Ti'));
      await tester.pumpAndSettle();

      expect(find.byType(ListView), findsOneWidget);
    });
  });
}
