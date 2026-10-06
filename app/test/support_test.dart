import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pc_forge_mobile/features/support/data/models/service_request_model.dart';
import 'package:pc_forge_mobile/features/support/data/models/support_service_request_model.dart';
import 'package:pc_forge_mobile/features/support/data/support_service.dart';
import 'package:pc_forge_mobile/features/support/presentation/screens/create_service_request_screen.dart';
import 'package:pc_forge_mobile/features/support/presentation/screens/support_screen.dart';
import 'package:pc_forge_mobile/services/api_service.dart';

class MockSupportApiService extends ApiService {
  @override
  Future<Map<String, dynamic>> createServiceRequest({
    String? title,
    String? description,
    int? orderId,
    int? productId,
    String? productName,
    String problemDescription = '',
    String problemCategory = 'General',
    String? troubleshootingSummary,
    int attemptCount = 0,
    String warrantyStatus = 'Active',
    String? preferredDate,
    String? preferredTime,
    String priority = 'Normal',
    String? attachmentUrl,
    String? token,
  }) async {
    return {
      'serviceRequestId': 101,
      'serviceRequestNumber': 'SR-000101',
      'title': title ?? (problemDescription.isNotEmpty ? problemDescription : 'Service Request'),
      'description': description ?? problemDescription,
      'orderId': orderId,
      'productId': productId ?? 4,
      'productName': productName ?? 'GeForce RTX 4070 Ti 12GB',
      'problemDescription': problemDescription,
      'problemCategory': problemCategory,
      'troubleshootingSummary': troubleshootingSummary,
      'attemptCount': attemptCount,
      'warrantyStatus': warrantyStatus,
      'preferredDate': preferredDate ?? '2026-10-02',
      'preferredTime': preferredTime ?? '10:00 AM',
      'status': 'PENDING',
      'priority': priority,
      'createdAt': DateTime.now().toIso8601String(),
    };
  }

  @override
  Future<List<Map<String, dynamic>>> fetchServiceRequests({
    String? status,
    String? startDate,
    String? endDate,
    String? token,
  }) async {
    return [
      {
        'serviceRequestId': 101,
        'serviceRequestNumber': 'SR-000101',
        'title': 'Fans spinning at 100% and crashing',
        'description': 'GPU thermal fault during load',
        'orderId': 1001,
        'productId': 4,
        'productName': 'GeForce RTX 4070 Ti 12GB',
        'problemDescription': 'Fans spinning at 100% and crashing',
        'problemCategory': 'GPU',
        'warrantyStatus': 'Active',
        'preferredDate': '2026-10-02',
        'preferredTime': '10:00 AM',
        'status': 'PENDING',
        'createdAt': DateTime.now().toIso8601String(),
      }
    ];
  }

  @override
  Future<Map<String, dynamic>> checkServiceAvailability(String date, {String? token}) async {
    return {
      'date': date,
      'bookedCount': 3,
      'maxCapacity': 10,
      'remainingSlots': 7,
      'isAvailable': true,
    };
  }

  @override
  Future<Map<String, dynamic>> cancelServiceRequest(int id, {String? token}) async {
    return {
      'message': 'Service request cancelled',
    };
  }

  @override
  Future<Map<String, dynamic>> createSupportTicket({
    int? orderId,
    int? productId,
    required String issueType,
    required String subject,
    required String description,
    String? attachmentUrl,
    String? token,
  }) async {
    return {
      'ticketId': 505,
      'orderId': orderId,
      'productId': productId,
      'productName': 'GeForce RTX 4070 Ti 12GB',
      'issueType': issueType,
      'subject': subject,
      'description': description,
      'attachmentUrl': attachmentUrl,
      'status': 'Open',
      'priority': 'High',
      'createdAt': DateTime.now().toIso8601String(),
    };
  }

  @override
  Future<List<Map<String, dynamic>>> fetchSupportTickets({String? token}) async {
    return [
      {
        'ticketId': 501,
        'orderId': 1001,
        'productId': 4,
        'productName': 'GeForce RTX 4070 Ti 12GB',
        'issueType': 'Overheating',
        'subject': 'GPU is overheating',
        'description': 'Temperature spikes under load.',
        'status': 'Open',
        'priority': 'High',
        'createdAt': DateTime.now().toIso8601String(),
      }
    ];
  }
}

void main() {
  group('Service Request & Support Unit Tests', () {
    setUp(() {
      SupportService.instance.setApiServiceForTesting(MockSupportApiService());
    });

    test('ServiceRequestModel parses JSON correctly with title and description', () {
      final json = {
        'serviceRequestId': 101,
        'serviceRequestNumber': 'SR-000101',
        'title': 'Display Artifacts on Screen',
        'description': 'Green vertical lines appear under gaming load.',
        'orderId': 1001,
        'productId': 4,
        'productName': 'GeForce RTX 4070 Ti 12GB',
        'problemDescription': 'Green vertical lines appear under gaming load.',
        'problemCategory': 'Display',
        'troubleshootingSummary': 'Checked HDMI cable. Restarted PC.',
        'troubleshootingAttemptCount': 2,
        'warrantyStatus': 'Active',
        'warrantyExpiryDate': '2027-04-15T00:00:00Z',
        'preferredDate': '2026-10-02',
        'preferredTime': '10:00 AM',
        'status': 'PENDING',
        'priority': 'Medium',
        'createdAt': '2026-09-27T10:00:00Z',
      };

      final sr = ServiceRequestModel.fromJson(json);
      expect(sr.serviceRequestId, 101);
      expect(sr.serviceRequestNumber, 'SR-000101');
      expect(sr.title, 'Display Artifacts on Screen');
      expect(sr.description, 'Green vertical lines appear under gaming load.');
      expect(sr.orderId, 1001);
      expect(sr.productName, 'GeForce RTX 4070 Ti 12GB');
      expect(sr.problemCategory, 'Display');
      expect(sr.warrantyStatus, 'Active');
      expect(sr.preferredDate, '2026-10-02');
      expect(sr.preferredTime, '10:00 AM');
      expect(sr.status, 'PENDING');
      expect(sr.attemptCount, 2);
    });

    test('SupportServiceRequestModel parses JSON correctly', () {
      final json = {
        'ticketId': 505,
        'orderId': 1001,
        'productId': 4,
        'productName': 'GeForce RTX 4070 Ti 12GB',
        'issueType': 'Overheating',
        'subject': 'GPU is overheating',
        'description': 'Temperature spikes to 95C under load.',
        'attachmentUrl': 'https://example.com/error.jpg',
        'status': 'Open',
        'priority': 'High',
        'createdAt': '2026-09-16T10:00:00Z',
      };

      final ticket = SupportServiceRequestModel.fromJson(json);
      expect(ticket.serviceRequestId, 505);
      expect(ticket.ticketId, 505);
      expect(ticket.orderId, 1001);
      expect(ticket.productName, 'GeForce RTX 4070 Ti 12GB');
      expect(ticket.issueType, 'Overheating');
      expect(ticket.subject, 'GPU is overheating');
      expect(ticket.status, 'Open');
      expect(ticket.priority, 'High');
      expect(ticket.attachmentUrl, isNotNull);
    });

    test('SupportService creates a new Service Request with title and status PENDING', () async {
      final service = SupportService.instance;
      final initialCount = service.serviceRequests.length;

      final newRequest = await service.createServiceRequest(
        title: 'GPU fans loud and crashing',
        description: 'Detailed crash logs',
        orderId: 1001,
        productId: 4,
        problemDescription: 'Fans spinning at 100% and crashing',
        problemCategory: 'GPU',
        preferredDate: '2026-10-02',
        preferredTime: '10:00 AM',
      );

      expect(newRequest.title, 'GPU fans loud and crashing');
      expect(newRequest.problemDescription, 'Fans spinning at 100% and crashing');
      expect(newRequest.status, 'PENDING');
      expect(newRequest.warrantyStatus, 'Active');
      expect(service.serviceRequests.length, initialCount + 1);
      expect(service.serviceRequests.first.serviceRequestId, newRequest.serviceRequestId);
    });

    test('SupportService checks date availability capacity', () async {
      final service = SupportService.instance;
      final avail = await service.checkAvailability('2026-10-02');
      expect(avail['isAvailable'], true);
      expect(avail['remainingSlots'], 7);
      expect(avail['maxCapacity'], 10);
    });

    test('SupportService can cancel a service request', () async {
      final service = SupportService.instance;
      // Pre-load requests
      await service.loadServiceRequests();
      expect(service.serviceRequests.isNotEmpty, true);
      final firstId = service.serviceRequests.first.serviceRequestId;

      final success = await service.cancelServiceRequest(firstId);
      expect(success, true);
      final updated = service.serviceRequests.firstWhere((r) => r.serviceRequestId == firstId);
      expect(updated.status, 'CANCELLED');
    });

    test('SupportService creates a manual Service Request without order and custom product', () async {
      final service = SupportService.instance;
      final initialCount = service.serviceRequests.length;

      final newRequest = await service.createServiceRequest(
        title: 'Custom PC thermal throttling',
        productName: 'Custom Rig (AMD Ryzen 7 7800X3D + RTX 4070)',
        problemDescription: 'Reaches 98C under Blender render',
        problemCategory: 'Overheating & Thermals',
        preferredDate: '2026-10-02',
        preferredTime: '11:00 AM',
      );

      expect(newRequest.title, 'Custom PC thermal throttling');
      expect(newRequest.productName, 'Custom Rig (AMD Ryzen 7 7800X3D + RTX 4070)');
      expect(newRequest.orderId, isNull);
      expect(newRequest.status, 'PENDING');
      expect(service.serviceRequests.length, initialCount + 1);
    });
  });

  group('Service Request Widget Tests', () {
    testWidgets('SupportScreen renders Service Requests list and header', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SupportScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('My Service Requests'), findsOneWidget);
      expect(find.text('After-Sales Support Assistant'), findsOneWidget);
    });

    testWidgets('CreateServiceRequestScreen renders simplified Service Request form inputs', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CreateServiceRequestScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Submit Service Request'), findsWidgets);
      expect(find.text('Title (Optional)'), findsOneWidget);
      expect(find.text('Description (Optional)'), findsOneWidget);
      expect(find.text('Preferred Appointment (Optional)'), findsOneWidget);
    });

    testWidgets('SupportScreen renders New Service Request manual action button', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SupportScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('New Service Request'), findsOneWidget);
    });

    testWidgets('SupportScreen shows confirmation dialog and cancels request when confirmed', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SupportScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Find the Cancel Service Request button
      final cancelBtn = find.text('Cancel Service Request');
      expect(cancelBtn, findsWidgets);

      // Tap cancel button on the first card
      await tester.tap(cancelBtn.first);
      await tester.pumpAndSettle();

      // Verify the confirmation dialog appears with exact prompt text
      expect(find.text('Are you sure you want to cancel this service request?'), findsOneWidget);
      expect(find.text('Keep Request'), findsOneWidget);

      // Tap confirm button
      await tester.tap(find.widgetWithText(ElevatedButton, 'Cancel Service Request'));
      await tester.pumpAndSettle();

      // Verify cancel was processed
      expect(find.textContaining('cancelled'), findsWidgets);
    });
  });
}
