// Dart models for Member 05 After-Sales Service Agent & Service Requests.
import 'service_request_model.dart';

export 'service_request_model.dart';

class AiRmaTicketModel {
  final int ticketId;
  final String rmaNumber;
  final int? orderId;
  final String orderNumber;
  final int? productId;
  final String componentName;
  final String issueType;
  final String status;
  final String priority;
  final String description;
  final String? attachmentUrl;
  final String createdAt;

  const AiRmaTicketModel({
    required this.ticketId,
    required this.rmaNumber,
    this.orderId,
    this.orderNumber = 'PCF-10492',
    this.productId,
    required this.componentName,
    this.issueType = 'Hardware fault',
    this.status = 'PENDING',
    this.priority = 'Normal',
    this.description = '',
    this.attachmentUrl,
    this.createdAt = '',
  });

  factory AiRmaTicketModel.fromJson(Map<String, dynamic> json) {
    return AiRmaTicketModel(
      ticketId: (json['ticket_id'] as num?)?.toInt() ??
          (json['ticketId'] as num?)?.toInt() ??
          (json['service_request_id'] as num?)?.toInt() ??
          (json['serviceRequestId'] as num?)?.toInt() ??
          (json['id'] as num?)?.toInt() ??
          108,
      rmaNumber: json['service_request_number']?.toString() ??
          json['serviceRequestNumber']?.toString() ??
          json['rma_number']?.toString() ??
          json['rmaNumber']?.toString() ??
          'SR-000108',
      orderId: (json['order_id'] as num?)?.toInt() ?? (json['orderId'] as num?)?.toInt(),
      orderNumber: json['order_number']?.toString() ?? json['orderNumber']?.toString() ?? 'PCF-10001',
      productId: (json['product_id'] as num?)?.toInt() ?? (json['productId'] as num?)?.toInt(),
      componentName: json['product_name']?.toString() ??
          json['productName']?.toString() ??
          json['component_name']?.toString() ??
          json['componentName']?.toString() ??
          'Hardware Component',
      issueType: json['problem_category']?.toString() ??
          json['problemCategory']?.toString() ??
          json['issue_type']?.toString() ??
          json['issueType']?.toString() ??
          'General',
      status: (json['status']?.toString() ?? 'PENDING').toUpperCase(),
      priority: json['priority']?.toString() ?? 'Normal',
      description: json['problem_description']?.toString() ??
          json['problemDescription']?.toString() ??
          json['description']?.toString() ??
          '',
      attachmentUrl: json['attachment_url']?.toString() ?? json['attachmentUrl']?.toString(),
      createdAt: json['created_at']?.toString() ?? json['createdAt']?.toString() ?? '',
    );
  }
}

class AiAfterSalesChatMessage {
  final String text;
  final bool isUser;
  final AiRmaTicketModel? ticket;
  final ServiceRequestModel? serviceRequest;
  final int attemptCount;
  final String? problemCategory;
  final DateTime timestamp;
  final bool isError;
  final bool serviceRequestMode;

  AiAfterSalesChatMessage({
    required this.text,
    required this.isUser,
    this.ticket,
    this.serviceRequest,
    this.attemptCount = 0,
    this.problemCategory,
    DateTime? timestamp,
    this.isError = false,
    this.serviceRequestMode = false,
  }) : timestamp = timestamp ?? DateTime.now();
}

class AiAfterSalesChatResultModel {
  final bool success;
  final String reply;
  final int attemptCount;
  final List<String> attemptedSteps;
  final String? problemCategory;
  final bool isResolved;
  final bool serviceRequestRequired;
  final bool serviceRequestMode;
  final ServiceRequestModel? serviceRequest;
  final AiRmaTicketModel? ticket;
  final List<String> agentTrace;
  final String? error;

  const AiAfterSalesChatResultModel({
    required this.success,
    required this.reply,
    this.attemptCount = 0,
    this.attemptedSteps = const [],
    this.problemCategory,
    this.isResolved = false,
    this.serviceRequestRequired = false,
    this.serviceRequestMode = false,
    this.serviceRequest,
    this.ticket,
    this.agentTrace = const [],
    this.error,
  });

  factory AiAfterSalesChatResultModel.fromJson(Map<String, dynamic> json) {
    final rawTrace = json['agent_trace'] ?? json['agentTrace'];
    final traceList = <String>[];
    if (rawTrace is List) {
      for (final item in rawTrace) {
        if (item != null) {
          traceList.add(item.toString());
        }
      }
    }

    final rawSteps = json['attempted_steps'] ?? json['attemptedSteps'];
    final stepsList = <String>[];
    if (rawSteps is List) {
      for (final item in rawSteps) {
        if (item != null) {
          stepsList.add(item.toString());
        }
      }
    }

    ServiceRequestModel? srModel;
    if (json['service_request'] is Map) {
      srModel = ServiceRequestModel.fromJson(Map<String, dynamic>.from(json['service_request'] as Map));
    } else if (json['serviceRequest'] is Map) {
      srModel = ServiceRequestModel.fromJson(Map<String, dynamic>.from(json['serviceRequest'] as Map));
    }

    AiRmaTicketModel? ticketModel;
    if (json['ticket'] is Map) {
      ticketModel = AiRmaTicketModel.fromJson(Map<String, dynamic>.from(json['ticket'] as Map));
    } else if (srModel != null) {
      ticketModel = AiRmaTicketModel(
        ticketId: srModel.serviceRequestId,
        rmaNumber: srModel.serviceRequestNumber,
        orderId: srModel.orderId,
        orderNumber: srModel.orderId != null ? 'PCF-10${srModel.orderId.toString().padLeft(3, '0')}' : 'N/A',
        productId: srModel.productId,
        componentName: srModel.productName ?? 'Hardware Component',
        issueType: srModel.problemCategory,
        status: srModel.status,
        priority: srModel.priority,
        description: srModel.problemDescription,
        createdAt: srModel.createdAt.toIso8601String(),
      );
    }

    return AiAfterSalesChatResultModel(
      success: json['success'] as bool? ?? true,
      reply: json['reply']?.toString() ?? '',
      attemptCount: (json['attempt_count'] as num?)?.toInt() ?? (json['attemptCount'] as num?)?.toInt() ?? 0,
      attemptedSteps: stepsList,
      problemCategory: json['problem_category']?.toString() ?? json['problemCategory']?.toString(),
      isResolved: json['is_resolved'] as bool? ?? json['isResolved'] as bool? ?? false,
      serviceRequestRequired: json['service_request_required'] as bool? ?? json['serviceRequestRequired'] as bool? ?? false,
      serviceRequestMode: json['service_request_mode'] as bool? ?? json['serviceRequestMode'] as bool? ?? false,
      serviceRequest: srModel,
      ticket: ticketModel,
      agentTrace: traceList,
      error: json['error']?.toString(),
    );
  }
}
