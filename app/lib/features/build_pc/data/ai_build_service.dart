import 'package:flutter/foundation.dart';
import '../../../core/auth_session.dart';
import '../../../services/api_service.dart';
import 'models/requirement_profile_model.dart';
import 'models/ai_build_result_model.dart';
import 'models/ai_inventory_model.dart';
import 'models/ai_order_proposal_model.dart';

class AiRequirementMessage {
  final String text;
  final bool isUser;
  final bool isError;
  final DateTime timestamp;

  AiRequirementMessage({
    required this.text,
    required this.isUser,
    this.isError = false,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class AiBuildService extends ChangeNotifier {
  static final AiBuildService instance = AiBuildService._internal();
  AiBuildService._internal();

  final ApiService _apiService = ApiService();

  String? _currentSessionId;
  RequirementProfileModel _currentProfile = const RequirementProfileModel();
  final List<AiRequirementMessage> _messages = [];
  bool _isLoading = false;
  String? _errorMessage;

  String? get currentSessionId => _currentSessionId;
  RequirementProfileModel get currentProfile => _currentProfile;
  List<AiRequirementMessage> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;
  bool get isProfileComplete => _currentProfile.isComplete;
  String? get errorMessage => _errorMessage;

  void resetSession() {
    _currentSessionId = null;
    _currentProfile = const RequirementProfileModel();
    _messages.clear();
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }

  /// Initialize new AI Requirement Gathering session with backend
  Future<void> initSession() async {
    if (_currentSessionId != null && _messages.isNotEmpty && _errorMessage == null) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final token = AuthSession.instance.token;
      final res = await _apiService.post(
        '/aibuilds/requirement-session/start',
        {},
        token: token,
      );

      _currentSessionId = res['sessionId'] as String? ?? res['session_id'] as String?;
      final greeting = res['greetingMessage'] as String? ??
          res['greeting_message'] as String? ??
          "Hi! I'm your PCForge AI Architect. Tell me what kind of PC you're looking for, your budget, and what games or apps you'll run.";

      _messages.clear();
      _messages.add(AiRequirementMessage(text: greeting, isUser: false));
    } catch (e) {
      debugPrint('[AiBuildService] initSession error: $e');
      _errorMessage = e.toString();
      _messages.clear();
      _messages.add(AiRequirementMessage(
        text: "Could not connect to the AI service ($e). Please check that the server is running.",
        isUser: false,
        isError: true,
      ));
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Send message to Requirement Discovery Agent
  Future<void> sendMessage(String text) async {
    final clean = text.trim();
    if (clean.isEmpty) return;

    // Optimistically append user message
    _messages.add(AiRequirementMessage(text: clean, isUser: true));
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // If session was not initialized yet, initialize now
      if (_currentSessionId == null) {
        final token = AuthSession.instance.token;
        final startRes = await _apiService.post(
          '/aibuilds/requirement-session/start',
          {},
          token: token,
        );
        _currentSessionId = startRes['sessionId'] as String? ?? startRes['session_id'] as String?;
      }

      final token = AuthSession.instance.token;
      final res = await _apiService.post(
        '/aibuilds/requirement-session/$_currentSessionId/message',
        {'message': clean},
        token: token,
      );

      final reply = res['reply'] as String? ?? "No reply from AI service.";
      final isErrorResponse = res['status'] == 'error' || res['status'] == 'offline';

      _messages.add(AiRequirementMessage(
        text: reply,
        isUser: false,
        isError: isErrorResponse,
      ));

      if (res['profile'] is Map<String, dynamic>) {
        _currentProfile = RequirementProfileModel.fromJson(
          res['profile'] as Map<String, dynamic>,
        );
      }
    } catch (e) {
      debugPrint('[AiBuildService] sendMessage error: $e');
      _errorMessage = e.toString();
      _messages.add(AiRequirementMessage(
        text: "Error communicating with AI service: $e",
        isUser: false,
        isError: true,
      ));
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Invoke Member 03 PC Build & Compatibility Agent
  Future<AiBuildResultModel> generateBuild({
    String? sessionId,
    String? purpose,
    double? budgetAmount,
    String? currency,
    String? targetResolution,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final token = AuthSession.instance.token;
      final payload = <String, dynamic>{
        if (sessionId != null || _currentSessionId != null)
          'session_id': sessionId ?? _currentSessionId,
        'purpose': purpose ?? _currentProfile.purpose ?? 'Gaming',
        'budget_amount': budgetAmount ?? _currentProfile.budgetAmount ?? 400000.0,
        'currency': currency ?? _currentProfile.currency,
        'target_resolution': targetResolution ?? _currentProfile.targetResolution ?? '1440p',
        'preferences': _currentProfile.preferences,
      };

      final res = await _apiService.post(
        '/aibuilds/generate-build',
        payload,
        token: token,
      );

      final model = AiBuildResultModel.fromJson(res);
      return model;
    } catch (e) {
      debugPrint('[AiBuildService] generateBuild error: $e');
      _errorMessage = e.toString();
      return AiBuildResultModel(
        success: false,
        error: e.toString(),
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Invoke Member 02 Inventory Agent to verify live stock and place 15-min reservation
  Future<AiStockVerificationModel> verifyStock({
    required Map<String, int> componentIds,
    String? sessionId,
    String? buildName,
    String? targetResolution,
    int holdMinutes = 15,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final token = AuthSession.instance.token;
      final payload = <String, dynamic>{
        'session_id': sessionId ?? _currentSessionId,
        'build_name': buildName ?? 'PCForge Custom Build',
        'target_resolution': targetResolution ?? _currentProfile.targetResolution ?? '1440p',
        'component_ids': componentIds,
        'hold_minutes': holdMinutes,
      };

      final res = await _apiService.post(
        '/aibuilds/verify-stock',
        payload,
        token: token,
      );

      final model = AiStockVerificationModel.fromJson(res);
      return model;
    } catch (e) {
      debugPrint('[AiBuildService] verifyStock error: $e');
      _errorMessage = e.toString();
      return AiStockVerificationModel(
        success: false,
        allInStock: false,
        components: const {},
        reservation: const AiReservationHoldModel(
          reservationId: 'FAILED',
          expiresAt: '',
        ),
        error: e.toString(),
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Invoke Member 04 Order Planning Agent to price build, apply discounts & delivery (UI 4)
  Future<AiOrderProposalResultModel> createOrderProposal({
    required String reservationId,
    required String buildName,
    required Map<String, dynamic> components,
    String? promoCode = 'WELCOME5',
    String? shippingMethod = 'standard',
    String? shippingAddress = 'Colombo, Western Province',
    String? currency = 'LKR',
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final token = AuthSession.instance.token;
      final payload = <String, dynamic>{
        'reservation_id': reservationId,
        'build_name': buildName,
        'components': components,
        'promo_code': promoCode,
        'shipping_method': shippingMethod,
        'shipping_address': shippingAddress,
        'currency': currency,
        'session_id': _currentSessionId,
      };

      final res = await _apiService.post(
        '/aibuilds/order-proposal',
        payload,
        token: token,
      );

      return AiOrderProposalResultModel.fromJson(res);
    } catch (e) {
      debugPrint('[AiBuildService] createOrderProposal error: $e');
      _errorMessage = e.toString();
      return AiOrderProposalResultModel(
        success: false,
        error: e.toString(),
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Submit customer-approved order proposal to backend for technician sign-off (UI 5)
  Future<AiSubmittedOrderModel?> submitApprovedOrder({
    required String proposalId,
    required String orderNumber,
    required String reservationId,
    required String buildName,
    required double totalAmount,
    required String formattedTotal,
    required String shippingAddress,
    required List<AiOrderPricingItemModel> components,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final token = AuthSession.instance.token;
      final payload = <String, dynamic>{
        'proposal_id': proposalId,
        'order_number': orderNumber,
        'reservation_id': reservationId,
        'build_name': buildName,
        'total_amount': totalAmount,
        'formatted_total': formattedTotal,
        'shipping_address': shippingAddress,
        'components': components.map((c) => c.toJson()).toList(),
      };

      final res = await _apiService.post(
        '/aibuilds/submit-approved-order',
        payload,
        token: token,
      );

      return AiSubmittedOrderModel.fromJson(res);
    } catch (e) {
      debugPrint('[AiBuildService] submitApprovedOrder error: $e');
      _errorMessage = e.toString();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
