import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pc_forge_mobile/features/support/data/models/service_request_model.dart';
import 'package:pc_forge_mobile/features/support/data/models/support_ticket_model.dart';
import 'package:pc_forge_mobile/features/support/data/support_service.dart';
import 'package:pc_forge_mobile/features/support/presentation/screens/create_ticket_screen.dart';
import 'package:pc_forge_mobile/features/support/presentation/screens/support_screen.dart';
import 'package:pc_forge_mobile/services/api_service.dart';

class MockSupportApiService extends ApiService {
  @override
  Future<Map<String, dynamic>> createServiceRequest({
    int? orderId,
    int? productId,
    required String problemDescription,
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
      'orderId': orderId,
      'productId': productId ?? 4,
      'productName': 'GeForce RTX 4070 Ti 12GB',
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
  Future<List<Map<String, dynamic>>> fetchServiceRequests({String? token}) async {
    return [
      {
        'serviceRequestId': 101,
        'serviceRequestNumber': 'SR-000101',
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

    test('ServiceRequestModel parses JSON correctly', () {
      final json = {
        'serviceRequestId': 101,
        'serviceRequestNumber': 'SR-000101',
        'orderId': 1001,
        'productId': 4,
        'productName': 'GeForce RTX 4070 Ti 12GB',
        'problemDescription': 'Display goes black during gameplay.',
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
      expect(sr.orderId, 1001);
      expect(sr.productName, 'GeForce RTX 4070 Ti 12GB');
      expect(sr.problemCategory, 'Display');
      expect(sr.warrantyStatus, 'Active');
      expect(sr.preferredDate, '2026-10-02');
      expect(sr.preferredTime, '10:00 AM');
      expect(sr.status, 'PENDING');
      expect(sr.attemptCount, 2);
    });

    test('SupportTicketModel parses JSON correctly', () {
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

      final ticket = SupportTicketModel.fromJson(json);
      expect(ticket.ticketId, 505);
      expect(ticket.orderId, 1001);
      expect(ticket.productName, 'GeForce RTX 4070 Ti 12GB');
      expect(ticket.issueType, 'Overheating');
      expect(ticket.subject, 'GPU is overheating');
      expect(ticket.status, 'Open');
      expect(ticket.priority, 'High');
      expect(ticket.attachmentUrl, isNotNull);
    });

    test('SupportService creates a new Service Request and prepends to list', () async {
      final service = SupportService.instance;
      final initialCount = service.serviceRequests.length;

      final newRequest = await service.createServiceRequest(
        orderId: 1001,
        productId: 4,
        problemDescription: 'Fans spinning at 100% and crashing',
        problemCategory: 'GPU',
        preferredDate: '2026-10-02',
        preferredTime: '10:00 AM',
      );

      expect(newRequest.problemDescription, 'Fans spinning at 100% and crashing');
      expect(newRequest.status, 'PENDING');
      expect(newRequest.warrantyStatus, 'Active');
      expect(service.serviceRequests.length, initialCount + 1);
      expect(service.serviceRequests.first.serviceRequestId, newRequest.serviceRequestId);
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

    testWidgets('CreateTicketScreen renders Service Request form inputs', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CreateTicketScreen(initialOrderId: 1001),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Submit Service Request'), findsWidgets);
      expect(find.text('Issue Category'), findsOneWidget);
    });
  });
}
