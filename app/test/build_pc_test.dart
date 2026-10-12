import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pc_forge_mobile/features/build_pc/data/build_service.dart';
import 'package:pc_forge_mobile/features/build_pc/data/models/custom_build_model.dart';
import 'package:pc_forge_mobile/features/build_pc/data/models/custom_build_slot.dart';
import 'package:pc_forge_mobile/features/build_pc/presentation/screens/build_pc_hub_screen.dart';
import 'package:pc_forge_mobile/features/build_pc/presentation/screens/build_status_screen.dart';
import 'package:pc_forge_mobile/features/build_pc/presentation/screens/my_custom_builds_screen.dart';
import 'package:pc_forge_mobile/features/build_pc/presentation/widgets/component_picker_sheet.dart';
import 'package:pc_forge_mobile/features/cart/data/cart_service.dart';
import 'package:pc_forge_mobile/features/catalog/data/catalog_repository.dart';
import 'package:pc_forge_mobile/features/catalog/data/models/product_model.dart';
import 'package:pc_forge_mobile/services/api_service.dart';

class MockBuildApiService extends ApiService {
  int _nextId = 101;

  @override
  Future<Map<String, dynamic>> submitCustomBuild({
    required Map<String, dynamic> payload,
    String? token,
  }) async {
    final id = _nextId++;
    return {
      'buildId': id,
      'buildName': payload['buildName'],
      'totalPrice': payload['totalCost'],
      'estimatedWattage': payload['estimatedWattage'],
      'status': 'Pending Staff Review',
      'customerNotes': payload['customerNotes'],
      'staffNotes': null,
      'createdAt': DateTime.now().toIso8601String(),
      'isSocketCompatible': payload['isCompatible'] ?? true,
      'isMemoryCompatible': true,
      'components': (payload['components'] as List? ?? []).map((c) {
        final pid = c['productId'];
        final slotStr = c['slotType'] as String?;
        String name = 'Component';
        double price = 50.0;
        int wattage = 65;
        if (pid == 1) {
          name = 'Intel Core i5-13600K';
          wattage = 125;
        } else if (pid == 2) {
          name = 'AMD Ryzen 7 7800X3D';
          wattage = 120;
        } else if (pid == 9 || pid == 11) {
          name = 'Budget 550W Bronze PSU';
          wattage = 550;
        } else if (pid == 10) {
          name = 'Corsair RM850x 850W 80+ Gold';
          wattage = 850;
        }
        return {
          'productId': pid,
          'slotType': slotStr,
          'productName': name,
          'price': price,
          'powerWattage': wattage,
        };
      }).toList(),
    };
  }

  @override
  Future<Map<String, dynamic>> resubmitCustomBuild({
    required int buildId,
    required Map<String, dynamic> payload,
    String? token,
  }) async {
    return {
      'buildId': buildId,
      'buildName': payload['buildName'],
      'totalPrice': payload['totalCost'],
      'estimatedWattage': payload['estimatedWattage'],
      'status': 'In Review by Staff',
      'customerNotes': payload['customerNotes'],
      'staffNotes': null,
      'createdAt': DateTime.now().toIso8601String(),
      'isSocketCompatible': payload['isCompatible'] ?? true,
      'isMemoryCompatible': true,
      'components': (payload['components'] as List? ?? []).map((c) => {
        'productId': c['productId'],
        'slotType': c['slotType'],
        'productName': c['productId'] == 10 ? 'Corsair RM850x 850W 80+ Gold' : 'Component',
        'price': 139.00,
        'powerWattage': 850,
      }).toList(),
    };
  }

  @override
  Future<List<Map<String, dynamic>>> fetchMyCustomBuilds({String? token}) async {
    return [
      {
        'buildId': 901,
        'buildName': 'Pro Creator AM5 Workstation',
        'totalPrice': 1850.00,
        'estimatedWattage': 650,
        'status': 'Approved by Staff',
        'customerNotes': 'Video editing station for 4K workflow',
        'staffNotes': 'Hardware clearances verified on workbench. Automated checks passed. Cleared for assembly.',
        'createdAt': '2026-03-20T10:00:00Z',
        'isSocketCompatible': true,
        'isMemoryCompatible': true,
        'components': [
          {
            'productId': 2,
            'slotType': 'cpu',
            'productName': 'AMD Ryzen 7 7800X3D',
            'price': 449.00,
            'powerWattage': 120,
          },
        ],
      },
      {
        'buildId': 902,
        'buildName': 'Compact ITX Gaming Beast',
        'totalPrice': 950.00,
        'estimatedWattage': 550,
        'status': 'Changes Requested',
        'customerNotes': 'LAN party machine',
        'staffNotes': 'PSU wattage (550W) has insufficient headroom for GPU transients.',
        'createdAt': '2026-03-22T14:30:00Z',
        'isSocketCompatible': true,
        'isMemoryCompatible': true,
        'components': [
          {
            'productId': 1,
            'slotType': 'cpu',
            'productName': 'Intel Core i5-13600K',
            'price': 319.00,
            'powerWattage': 125,
          },
        ],
      },
    ];
  }
}

class MockPickerApiService extends ApiService {
  @override
  Future<List<Map<String, dynamic>>> fetchCategories() async {
    return [
      {'categoryId': 1, 'name': 'CPU'},
    ];
  }

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
    final list = [
      {
        'productId': 5,
        'name': 'Ryzen 9 7950X',
        'brand': 'AMD',
        'categoryId': 1,
        'price': 699.00,
        'stockQuantity': 10,
        'socket': 'AM5',
      },
      {
        'productId': 6,
        'name': 'Core i9-13900K',
        'brand': 'Intel',
        'categoryId': 1,
        'price': 589.00,
        'stockQuantity': 5,
        'socket': 'LGA1700',
      },
    ];
    return list.where((p) {
      if (brand != null && brand.isNotEmpty && p['brand'] != brand) return false;
      return true;
    }).toList();
  }
}

void main() {
  group('BuildService Unit Tests', () {
    late BuildService service;

    setUp(() {
      service = BuildService.instance;
      service.setApiServiceForTesting(MockBuildApiService());
      service.clearDraft();
    });

    test('Selecting compatible AM5 CPU and Motherboard produces clean compatibility', () {
      const cpu = ProductModel(
        productId: 1,
        name: 'AMD Ryzen 9 7950X',
        price: 699.00,
        socket: 'AM5',
        powerWattage: 170,
      );

      const mobo = ProductModel(
        productId: 5,
        name: 'ASUS ROG Crosshair X670E Hero',
        price: 699.00,
        socket: 'AM5',
        memoryType: 'DDR5',
      );

      service.selectComponent(BuildSlotType.cpu, cpu);
      service.selectComponent(BuildSlotType.motherboard, mobo);

      expect(service.selectedCount, 2);
      expect(service.totalCost, 1398.00);
      expect(service.isCompatible, true);
      expect(service.compatibilityWarnings.isEmpty, true);
    });

    test('Selecting mismatched CPU and Motherboard triggers socket warning', () {
      const intelCpu = ProductModel(
        productId: 2,
        name: 'Intel Core i9-13900K',
        price: 589.00,
        socket: 'LGA1700',
        powerWattage: 253,
      );

      const am5Mobo = ProductModel(
        productId: 5,
        name: 'ASUS ROG Crosshair X670E Hero',
        price: 699.00,
        socket: 'AM5',
        memoryType: 'DDR5',
      );

      service.selectComponent(BuildSlotType.cpu, intelCpu);
      service.selectComponent(BuildSlotType.motherboard, am5Mobo);

      expect(service.isCompatible, false);
      expect(service.compatibilityWarnings.length, 1);
      expect(service.compatibilityWarnings.first, contains('Socket Mismatch'));
    });

    test('Wattage calculation sums CPU, GPU, and overhead', () {
      const cpu = ProductModel(
        productId: 1,
        name: 'AMD Ryzen 9 7950X',
        price: 699.00,
        powerWattage: 170,
      );

      const gpu = ProductModel(
        productId: 4,
        name: 'GeForce RTX 4070 Ti 12GB',
        price: 749.00,
        powerWattage: 240,
      );

      service.selectComponent(BuildSlotType.cpu, cpu);
      service.selectComponent(BuildSlotType.gpu, gpu);

      // 170 + 240 + 80 overhead = 490
      expect(service.estimatedWattage, 490);
    });

    test('submitBuildForReview transitions build to Pending Staff Review', () async {
      const cpu = ProductModel(
        productId: 1,
        name: 'AMD Ryzen 9 7950X',
        price: 699.00,
        socket: 'AM5',
      );

      service.selectComponent(BuildSlotType.cpu, cpu);
      final build = await service.submitBuildForReview(
        buildName: 'Test Beast Rig',
        customerNotes: 'Please check case clearance',
      );

      expect(build.buildName, 'Test Beast Rig');
      expect(build.status, 'Pending Staff Review');
      expect(build.isPendingReview, true);
      expect(service.activeSlots.isEmpty, true); // Draft cleared
      expect(service.myBuilds.first.buildName, 'Test Beast Rig');
    });

    test('loadBuildForModification loads parts and resubmitBuild updates existing build', () async {
      // Build a build first (since we no longer have seed data)
      const cpu = ProductModel(
        productId: 2,
        name: 'AMD Ryzen 7 7800X3D',
        price: 449.00,
        socket: 'AM5',
        powerWattage: 120,
      );
      const psuWeak = ProductModel(
        productId: 11,
        name: 'Budget 550W Bronze PSU',
        price: 69.00,
        powerWattage: 550,
      );
      service.selectComponent(BuildSlotType.cpu, cpu);
      service.selectComponent(BuildSlotType.psu, psuWeak);
      final flaggedBuild = (await service.submitBuildForReview(
        buildName: 'Changes Requested Build',
        customerNotes: 'Original submission',
      )).copyWith(status: 'Changes Requested', staffNotes: 'PSU wattage insufficient');

      // Insert it manually at the right position
      service.myBuilds; // access to confirm it exists

      // 1. Load build into service
      service.loadBuildForModification(flaggedBuild);

      expect(service.isEditingExistingBuild, true);
      expect(service.editingBuildId, flaggedBuild.buildId);
      expect(service.technicianNotesForEdit, flaggedBuild.staffNotes);
      expect(service.getComponent(BuildSlotType.psu)?.name, 'Budget 550W Bronze PSU');

      // 2. Customer upgrades PSU to 850W Gold
      const newPsu = ProductModel(
        productId: 10,
        name: 'Corsair RM850x 850W 80+ Gold',
        price: 139.00,
        powerWattage: 850,
      );
      service.selectComponent(BuildSlotType.psu, newPsu);

      // 3. Resubmit build
      final updated = await service.resubmitBuild(
        customerNotes: 'Upgraded to RM850x PSU as requested',
      );

      expect(updated.status, 'In Review by Staff');
      expect(updated.isReviewing, true);
      expect(updated.selectedComponents[BuildSlotType.psu]?.name, 'Corsair RM850x 850W 80+ Gold');
      expect(service.isEditingExistingBuild, false); // Editing flag reset
      expect(service.activeSlots.isEmpty, true); // Draft cleared
    });

    test('canSubmitForReview requires all mandatory components (CPU, Mobo, RAM, GPU, PSU) and compatibility', () {
      final service = BuildService.instance;
      service.clearDraft();

      // Empty builder
      expect(service.hasAllRequiredComponents, false);
      expect(service.canSubmitForReview, false);
      expect(service.missingRequiredSlots.length, 5);

      // Select CPU only
      service.selectComponent(
        BuildSlotType.cpu,
        const ProductModel(productId: 1, name: 'AMD Ryzen 7 7800X3D', price: 449.0, socket: 'AM5', powerWattage: 120),
      );
      expect(service.hasAllRequiredComponents, false);
      expect(service.canSubmitForReview, false);
      expect(service.missingRequiredSlots.length, 4);

      // Select Mobo
      service.selectComponent(
        BuildSlotType.motherboard,
        const ProductModel(productId: 3, name: 'MSI B650 Tomahawk', price: 219.0, socket: 'AM5', memoryType: 'DDR5'),
      );
      // Select RAM
      service.selectComponent(
        BuildSlotType.ram,
        const ProductModel(productId: 4, name: 'Corsair Vengeance 32GB DDR5', price: 119.0, memoryType: 'DDR5'),
      );
      // Select GPU
      service.selectComponent(
        BuildSlotType.gpu,
        const ProductModel(productId: 2, name: 'NVIDIA RTX 4070', price: 599.0, powerWattage: 200),
      );
      // Missing PSU still
      expect(service.hasAllRequiredComponents, false);
      expect(service.canSubmitForReview, false);
      expect(service.missingRequiredSlots.map((s) => s.type), contains(BuildSlotType.psu));

      // Select underpowered PSU -> all required slots present, but NOT compatible
      service.selectComponent(
        BuildSlotType.psu,
        const ProductModel(productId: 9, name: 'Weak 300W PSU', price: 40.0, powerWattage: 300),
      );
      expect(service.hasAllRequiredComponents, true);
      expect(service.isCompatible, false);
      expect(service.canSubmitForReview, false);

      // Upgrade PSU to adequate wattage -> all required slots present AND compatible!
      service.selectComponent(
        BuildSlotType.psu,
        const ProductModel(productId: 10, name: 'Corsair RM850x 850W Gold', price: 139.0, powerWattage: 850),
      );
      expect(service.hasAllRequiredComponents, true);
      expect(service.isCompatible, true);
      expect(service.canSubmitForReview, true);
    });
  });

  group('BuildPcHubScreen Widget Tests', () {
    setUp(() {
      BuildService.instance.clearDraft();
    });

    testWidgets('Renders Auto / Manual mode toggles and slots', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: BuildPcHubScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Check Mode Toggles
      expect(find.text('Manual Builder'), findsOneWidget);
      expect(find.text('AI Architect'), findsOneWidget);

      // Default mode is Manual: checks slot headers
      expect(find.text('Processor (CPU)'), findsOneWidget);
      expect(find.text('Motherboard'), findsOneWidget);
      expect(find.text('Submit for Review'), findsOneWidget);

      // Tap on Auto (AI Mode)
      await tester.tap(find.text('AI Architect'));
      await tester.pumpAndSettle();

      expect(find.text('Agentic AI Rig Architect'), findsOneWidget);

      // Switch back to Manual via the top mode toggle chip
      await tester.tap(find.text('Manual Builder'));
      await tester.pumpAndSettle();

      expect(find.text('Processor (CPU)'), findsOneWidget);
    });
  });

  group('ComponentPickerSheet Filter Tests', () {
    testWidgets('Renders search, filter button, opens modal and applies category filter', (tester) async {
      ProductModel? selected;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ComponentPickerSheet(
              slotInfo: BuildSlotInfo.allSlots.firstWhere((s) => s.type == BuildSlotType.cpu),
              onSelect: (p) => selected = p,
              repository: CatalogRepository(apiService: MockPickerApiService()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check title and filter button
      expect(find.text('Select Processor (CPU)'), findsOneWidget);
      expect(find.byKey(const Key('component_picker_filter_btn')), findsOneWidget);
      expect(find.text('Filter'), findsOneWidget);

      // Open Filter Modal
      await tester.tap(find.byKey(const Key('component_picker_filter_btn')));
      await tester.pumpAndSettle();

      // Verify modal content
      expect(find.text('Filter Processors (CPU)'), findsOneWidget);
      expect(find.text('Brand'), findsOneWidget);
      expect(find.text('AMD'), findsOneWidget);
      expect(find.text('Intel'), findsOneWidget);

      // Select AMD brand chip
      await tester.tap(find.text('AMD'));
      await tester.pumpAndSettle();

      // Apply Filters
      await tester.tap(find.byKey(const Key('apply_filters_btn')));
      await tester.pumpAndSettle();

      // Active chip and filtered button state
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Brand: AMD'), findsOneWidget);

      // Verify results list only has AMD CPUs
      expect(find.text('Ryzen 9 7950X'), findsOneWidget);
      expect(find.text('Core i9-13900K'), findsNothing);

      // Clear filter via Clear all
      await tester.tap(find.text('Clear all'));
      await tester.pumpAndSettle();

      expect(find.text('Filter'), findsOneWidget);
      expect(find.text('Ryzen 9 7950X'), findsOneWidget);
      expect(find.text('Core i9-13900K'), findsOneWidget);

      // Test choosing a component
      await tester.tap(find.byKey(const Key('select_part_5')));
      await tester.pumpAndSettle();
      expect(selected?.name, 'Ryzen 9 7950X');
    });
  });

  group('BuildStatusScreen Widget Tests', () {
    testWidgets('Renders Changes Requested alert banner, technician feedback and modify button', (tester) async {
      final flaggedBuild = CustomBuildModel(
        buildId: 1002,
        buildName: "Alex's ITX Gaming Battlestation",
        selectedComponents: const {
          BuildSlotType.cpu: ProductModel(
            productId: 2,
            name: 'AMD Ryzen 7 7800X3D',
            price: 449.00,
            socket: 'AM5',
          ),
          BuildSlotType.psu: ProductModel(
            productId: 11,
            name: 'Budget 550W Bronze PSU',
            price: 69.00,
            powerWattage: 550,
          ),
        },
        totalCost: 518.00,
        estimatedWattage: 485,
        status: 'Changes Requested',
        staffNotes: 'PSU wattage (550W) has insufficient headroom for RTX 4070 Ti.',
        submittedAt: DateTime(2026, 3, 15),
        isCompatible: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: BuildStatusScreen(customBuild: flaggedBuild),
        ),
      );
      await tester.pumpAndSettle();

      // Check header and status
      expect(find.text('RIG #${flaggedBuild.buildId}'), findsOneWidget);
      expect(find.text('Changes Requested'), findsOneWidget);

      // Check technician feedback banner
      expect(find.text('Technician Review Feedback'), findsOneWidget);
      // Scroll to find Modify & Resubmit Button in ListView
      await tester.scrollUntilVisible(
        find.byKey(const Key('modify_and_resubmit_btn')),
        300,
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('modify_and_resubmit_btn')), findsOneWidget);
      expect(find.text('Modify & Resubmit Build'), findsOneWidget);
    });

    testWidgets('Renders Approved status and Certified Technician Approval Message', (tester) async {
      final approvedBuild = CustomBuildModel(
        buildId: 1005,
        buildName: 'Dream 4K Editing Rig',
        selectedComponents: const {
          BuildSlotType.cpu: ProductModel(
            productId: 1,
            name: 'AMD Ryzen 9 7950X',
            price: 699.00,
            socket: 'AM5',
          ),
        },
        totalCost: 1850.00,
        estimatedWattage: 650,
        status: 'Approved by Staff',
        staffNotes: 'Clearance verified. Motherboard VRM thermals well within spec. Ready for build.',
        submittedAt: DateTime(2026, 3, 20),
        isCompatible: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: BuildStatusScreen(customBuild: approvedBuild),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('RIG #${approvedBuild.buildId}'), findsOneWidget);
      expect(find.text('Approved by Staff'), findsOneWidget);
      expect(find.text('Certified Technician Approval Message'), findsOneWidget);
      expect(find.text('Clearance verified. Motherboard VRM thermals well within spec. Ready for build.'), findsOneWidget);

      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('proceed_to_checkout_approved_btn')), findsOneWidget);
    });

    testWidgets('Tapping Proceed to Checkout loads approved build components into Cart', (tester) async {
      CartService.instance.clear();
      expect(CartService.instance.isEmpty, true);

      final approvedBuild = CustomBuildModel(
        buildId: 777,
        buildName: 'Creator Titan Beast',
        status: 'Approved by Staff',
        staffNotes: 'Passed all thermal stress benchmarks.',
        totalCost: 1999.00,
        estimatedWattage: 650,
        isCompatible: true,
        submittedAt: DateTime(2026, 3, 20),
        selectedComponents: {
          BuildSlotType.cpu: const ProductModel(
            productId: 1,
            name: 'AMD Ryzen 7 7800X3D',
            price: 449.00,
            stockQuantity: 10,
          ),
          BuildSlotType.gpu: const ProductModel(
            productId: 2,
            name: 'RTX 4070 Super',
            price: 599.00,
            stockQuantity: 5,
          ),
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          routes: {
            '/checkout': (context) => const Scaffold(body: Text('Checkout Screen')),
          },
          home: BuildStatusScreen(customBuild: approvedBuild),
        ),
      );
      await tester.pumpAndSettle();

      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('proceed_to_checkout_approved_btn')));
      await tester.pumpAndSettle();

      // Verify cart has the 2 components loaded
      expect(CartService.instance.items.length, 2);
      expect(CartService.instance.items.any((i) => i.productId == 1), true);
      expect(CartService.instance.items.any((i) => i.productId == 2), true);
      // Verify navigated to Checkout
      expect(find.text('Checkout Screen'), findsOneWidget);
    });
  });

  group('MyCustomBuildsScreen Widget Tests', () {
    setUp(() {
      BuildService.instance.setApiServiceForTesting(MockBuildApiService());
      BuildService.instance.clearDraft();
    });

    testWidgets('Renders list of past custom builds, status chips and technician notes', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MyCustomBuildsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Check App bar title
      expect(find.text('My Custom Builds'), findsOneWidget);

      // Check Approved build
      expect(find.text('Pro Creator AM5 Workstation'), findsOneWidget);
      expect(find.text('Approved by Staff'), findsOneWidget);
      expect(find.text('Technician Approval Note:'), findsOneWidget);
      expect(find.text('Hardware clearances verified on workbench. Automated checks passed. Cleared for assembly.'), findsOneWidget);

      // Check Changes Requested build
      expect(find.text('Compact ITX Gaming Beast'), findsOneWidget);
      expect(find.text('Changes Requested'), findsOneWidget);
      expect(find.text('Technician Changes Requested:'), findsOneWidget);
      expect(find.text('PSU wattage (550W) has insufficient headroom for GPU transients.'), findsOneWidget);

      // Check Modify & Resubmit Button
      expect(find.text('Modify & Resubmit Build (In Review)'), findsOneWidget);
    });
  });
}

