import 'package:flutter/foundation.dart';
import '../../../../core/auth_session.dart';
import '../../../../services/api_service.dart';
import 'models/support_service_request_model.dart';
import 'models/ai_after_sales_model.dart';

class SupportService extends ChangeNotifier {
  static final SupportService instance = SupportService._internal();

  SupportService._internal();

  ApiService _apiService = ApiService();

  @visibleForTesting
  void setApiServiceForTesting(ApiService api) {
    _apiService = api;
  }

  final List<ServiceRequestModel> _serviceRequests = [];

  List<ServiceRequestModel> get serviceRequests => List.unmodifiable(_serviceRequests);

  bool get hasServiceRequests => _serviceRequests.isNotEmpty;

  // Backward compatibility getter for existing widgets & tests
  List<SupportServiceRequestModel> get tickets => _serviceRequests.map((sr) => SupportServiceRequestModel(
    serviceRequestId: sr.serviceRequestId,
    orderId: sr.orderId,
    productId: sr.productId,
    productName: sr.productName,
    issueType: sr.problemCategory,
    subject: '${sr.serviceRequestNumber} - ${sr.problemCategory}',
    description: sr.problemDescription,
    attachmentUrl: sr.attachmentUrl,
    status: sr.status,
    priority: sr.priority,
    createdAt: sr.createdAt,
  )).toList();

  bool get hasTickets => _serviceRequests.isNotEmpty;

  /// Load service requests from live backend API
  Future<List<ServiceRequestModel>> loadServiceRequests({
    String? status,
    String? startDate,
    String? endDate,
    String? token,
  }) async {
    try {
      final remoteList = await _apiService.fetchServiceRequests(
        status: status,
        startDate: startDate,
        endDate: endDate,
        token: token,
      );
      _serviceRequests.clear();
      for (final item in remoteList) {
        _serviceRequests.add(ServiceRequestModel.fromJson(item));
      }
      notifyListeners();
    } catch (_) {
      // Network error — keep current list
    }
    return _serviceRequests;
  }

  /// Check Service Slot Availability for a given date
  Future<Map<String, dynamic>> checkAvailability(String date, {String? token}) async {
    try {
      return await _apiService.checkServiceAvailability(date, token: token);
    } catch (_) {
      return {};
    }
  }

  /// Cancel a Service Request
  Future<bool> cancelServiceRequest(int id, {String? token}) async {
    try {
      await _apiService.cancelServiceRequest(id, token: token);
      final idx = _serviceRequests.indexWhere((r) => r.serviceRequestId == id);
      if (idx != -1) {
        final cur = _serviceRequests[idx];
        _serviceRequests[idx] = ServiceRequestModel(
          serviceRequestId: cur.serviceRequestId,
          serviceRequestNumber: cur.serviceRequestNumber,
          userId: cur.userId,
          customerName: cur.customerName,
          orderId: cur.orderId,
          productId: cur.productId,
          productName: cur.productName,
          title: cur.title,
          description: cur.description,
          problemDescription: cur.problemDescription,
          problemCategory: cur.problemCategory,
          troubleshootingSummary: cur.troubleshootingSummary,
          attemptCount: cur.attemptCount,
          warrantyStatus: cur.warrantyStatus,
          warrantyExpiryDate: cur.warrantyExpiryDate,
          preferredDate: cur.preferredDate,
          preferredTime: cur.preferredTime,
          status: 'CANCELLED',
          priority: cur.priority,
          assignedStaffName: cur.assignedStaffName,
          technicianNotes: cur.technicianNotes,
          resolution: cur.resolution,
          attachmentUrl: cur.attachmentUrl,
          createdAt: cur.createdAt,
        );
        notifyListeners();
      }
      return true;
    } catch (e) {
      debugPrint('[SupportService] cancelServiceRequest error: $e');
      rethrow;
    }
  }

  /// Backward-compatible loader
  Future<List<SupportServiceRequestModel>> loadTickets({String? token}) async {
    await loadServiceRequests(token: token);
    return tickets;
  }

  /// Create and submit a new Service Request to backend API
  Future<ServiceRequestModel> createServiceRequest({
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
    final finalTitle = (title != null && title.trim().isNotEmpty)
        ? title.trim()
        : (description != null && description.trim().isNotEmpty
            ? description.trim()
            : (problemDescription.isNotEmpty ? problemDescription : 'Service Request'));
    final apiRes = await _apiService.createServiceRequest(
      title: finalTitle,
      description: description,
      orderId: orderId,
      productId: productId,
      productName: productName,
      problemDescription: problemDescription,
      problemCategory: problemCategory,
      troubleshootingSummary: troubleshootingSummary,
      attemptCount: attemptCount,
      warrantyStatus: warrantyStatus,
      preferredDate: preferredDate,
      preferredTime: preferredTime,
      priority: priority,
      attachmentUrl: attachmentUrl,
      token: token,
    );

    final newSr = ServiceRequestModel.fromJson(apiRes);
    _serviceRequests.insert(0, newSr);
    notifyListeners();
    return newSr;
  }

  /// Backward-compatible ticket creation
  Future<SupportServiceRequestModel> createTicket({
    int? orderId,
    int? productId,
    String? productName,
    required String issueType,
    required String subject,
    required String description,
    String? attachmentUrl,
    String? token,
  }) async {
    final sr = await createServiceRequest(
      orderId: orderId,
      productId: productId,
      productName: productName,
      problemDescription: description.isNotEmpty ? description : subject,
      problemCategory: issueType,
      troubleshootingSummary: subject,
      attemptCount: 1,
      attachmentUrl: attachmentUrl,
      token: token,
    );

    return SupportServiceRequestModel(
      serviceRequestId: sr.serviceRequestId,
      orderId: sr.orderId,
      productId: sr.productId,
      productName: sr.productName,
      issueType: sr.problemCategory,
      subject: subject,
      description: sr.problemDescription,
      attachmentUrl: sr.attachmentUrl,
      status: sr.status,
      priority: sr.priority,
      createdAt: sr.createdAt,
    );
  }

  /// Send message to Member 05 After-Sales Service Agent (UI 8 & Service Request workflow)
  Future<AiAfterSalesChatResultModel> sendAfterSalesChatMessage(
    String message, {
    int? orderId,
    String? sessionId,
  }) async {
    try {
      final token = AuthSession.instance.token;
      final payload = <String, dynamic>{
        'user_id': AuthSession.instance.currentUser?.userId ?? 1,
        'message': message,
        'session_id': sessionId,
        'order_id': orderId,
      };

      final res = await _apiService.post(
        '/ServiceRequests/ai-chat',
        payload,
        token: token,
      );

      final result = AiAfterSalesChatResultModel.fromJson(res);
      if (result.serviceRequest != null) {
        // Automatically insert into local list so "My Service Requests" updates instantly
        _serviceRequests.removeWhere((r) => r.serviceRequestId == result.serviceRequest!.serviceRequestId);
        _serviceRequests.insert(0, result.serviceRequest!);
        notifyListeners();
      }
      return result;
    } catch (e) {
      debugPrint('[SupportService] sendAfterSalesChatMessage error: $e');
      return AiAfterSalesChatResultModel(
        success: false,
        reply: 'Failed to contact After-Sales Service Agent. Please ensure the backend is running.',
        error: e.toString(),
      );
    }
  }
}
