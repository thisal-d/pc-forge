import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../core/auth_session.dart';

/// Custom API Exception for user-friendly error messages
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic responseData;
  final dynamic originalError;

  ApiException(
    this.message, {
    this.statusCode,
    this.responseData,
    this.originalError,
  });

  @override
  String toString() => message;
}

class ApiService {
  /// Default base URL: http://localhost:5000/api
  ///
  /// Works on all platforms thanks to `adb reverse tcp:5000 tcp:5000`:
  /// - Windows desktop: direct localhost connection
  /// - Android emulator: adb reverse tunnels localhost:5000 → host:5000
  /// - Physical Android phone (USB): adb reverse tunnels localhost:5000 → host:5000
  ///
  /// The runner.py automatically sets up the adb reverse tunnel on startup
  /// whenever an Android device is detected.
  static String normalizeBaseUrl(String url) {
    var trimmed = url.trim();
    // Local dev ports and localhost/LAN IPs must use unencrypted http, not https
    if (trimmed.startsWith('https://localhost') ||
        trimmed.startsWith('https://127.0.0.1') ||
        trimmed.startsWith('https://10.0.2.2') ||
        trimmed.startsWith('https://192.168.') ||
        trimmed.startsWith('https://10.')) {
      trimmed = trimmed.replaceFirst('https://', 'http://');
    }
    // Remove any trailing slash
    if (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  static String get defaultBaseUrl {
    const envUrl = String.fromEnvironment('API_BASE_URL');
    if (envUrl.isNotEmpty) {
      return normalizeBaseUrl(envUrl);
    }
    return 'http://localhost:5000/api';
  }

  final String baseUrl;
  late final HttpClient _client;

  ApiService({String? baseUrl, HttpClient? client})
      : baseUrl = normalizeBaseUrl(baseUrl ?? defaultBaseUrl) {
    _client = client ??
        (HttpClient()
          ..connectionTimeout = const Duration(seconds: 10)
          ..badCertificateCallback =
              (X509Certificate cert, String host, int port) => true);
  }

  /// Helper to send HTTP GET requests
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    String? token,
  }) async {
    var uri = Uri.parse('$baseUrl$path');
    if (queryParameters != null && queryParameters.isNotEmpty) {
      final cleanParams = <String, String>{};
      queryParameters.forEach((k, v) {
        if (v != null && v.toString().isNotEmpty) {
          cleanParams[k] = v.toString();
        }
      });
      uri = uri.replace(queryParameters: cleanParams);
    }

    try {
      final request = await _client.getUrl(uri);
      final effectiveToken = (token != null && token.isNotEmpty)
          ? token
          : AuthSession.instance.token;
      if (effectiveToken != null && effectiveToken.isNotEmpty) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $effectiveToken');
      }
      final response = await request.close().timeout(const Duration(seconds: 60));
      final responseBody = await response.transform(utf8.decoder).join();

      dynamic data;
      if (responseBody.trim().isNotEmpty) {
        try {
          data = jsonDecode(responseBody);
        } catch (_) {
          data = responseBody;
        }
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return data;
      } else {
        final errorMsg = (data is Map && data['message'] != null)
            ? data['message'] as String
            : 'Request failed with status code ${response.statusCode}';
        throw ApiException(
          errorMsg,
          statusCode: response.statusCode,
          responseData: data,
        );
      }
    } on SocketException catch (e) {
      throw ApiException(
        'Cannot connect to server at $baseUrl.\nPlease ensure the backend API is running.',
        originalError: e,
      );
    } on TimeoutException catch (e) {
      throw ApiException(
        'Connection timed out while contacting $baseUrl.',
        originalError: e,
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Unexpected network error: $e', originalError: e);
    }
  }

  /// Helper to send HTTP POST requests with JSON payload
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    try {
      final request = await _client.postUrl(uri);
      request.headers.contentType = ContentType.json;
      final effectiveToken = (token != null && token.isNotEmpty)
          ? token
          : AuthSession.instance.token;
      if (effectiveToken != null && effectiveToken.isNotEmpty) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $effectiveToken');
      }
      request.write(jsonEncode(body));

      final response = await request.close().timeout(const Duration(seconds: 60));
      final responseBody = await response.transform(utf8.decoder).join();

      Map<String, dynamic> data = {};
      if (responseBody.trim().isNotEmpty) {
        try {
          data = jsonDecode(responseBody) as Map<String, dynamic>;
        } catch (_) {
          data = {'raw': responseBody};
        }
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return data;
      } else {
        final errorMsg = data['message'] as String? ??
            'Request failed with status code ${response.statusCode}';
        throw ApiException(
          errorMsg,
          statusCode: response.statusCode,
          responseData: data,
        );
      }
    } on SocketException catch (e) {
      throw ApiException(
        'Cannot connect to server at $baseUrl.\nPlease ensure the backend API is running.',
        originalError: e,
      );
    } on TimeoutException catch (e) {
      throw ApiException(
        'Connection timed out while contacting $baseUrl.',
        originalError: e,
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Unexpected network error: $e', originalError: e);
    }
  }

  /// Helper to send HTTP PUT requests with JSON payload
  Future<Map<String, dynamic>> put(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    try {
      final request = await _client.putUrl(uri);
      request.headers.contentType = ContentType.json;
      final effectiveToken = (token != null && token.isNotEmpty)
          ? token
          : AuthSession.instance.token;
      if (effectiveToken != null && effectiveToken.isNotEmpty) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $effectiveToken');
      }
      request.write(jsonEncode(body));

      final response = await request.close().timeout(const Duration(seconds: 10));
      final responseBody = await response.transform(utf8.decoder).join();

      Map<String, dynamic> data = {};
      if (responseBody.trim().isNotEmpty) {
        try {
          data = jsonDecode(responseBody) as Map<String, dynamic>;
        } catch (_) {
          data = {'raw': responseBody};
        }
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return data;
      } else {
        final errorMsg = data['message'] as String? ??
            'Request failed with status code ${response.statusCode}';
        throw ApiException(
          errorMsg,
          statusCode: response.statusCode,
          responseData: data,
        );
      }
    } on SocketException catch (e) {
      throw ApiException(
        'Cannot connect to server at $baseUrl.\nPlease ensure the backend API is running.',
        originalError: e,
      );
    } on TimeoutException catch (e) {
      throw ApiException(
        'Connection timed out while contacting $baseUrl.',
        originalError: e,
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Unexpected network error: $e', originalError: e);
    }
  }

  // ==================== AUTHENTICATION ====================

  /// Auth: Login
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    return await post('/Auth/login', {
      'email': email.trim(),
      'password': password,
    });
  }

  /// Auth: Register
  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    String? firstName,
    String? lastName,
    String role = 'Customer',
  }) async {
    return await post('/Auth/register', {
      'email': email.trim(),
      'password': password,
      if (firstName != null && firstName.trim().isNotEmpty)
        'firstName': firstName.trim(),
      if (lastName != null && lastName.trim().isNotEmpty)
        'lastName': lastName.trim(),
      'role': role,
    });
  }

  /// Auth: Update Profile (Member 01)
  Future<Map<String, dynamic>> updateProfile({
    String? firstName,
    String? lastName,
    String? email,
    String? currentPassword,
    String? newPassword,
    String? token,
  }) async {
    return await put(
      '/Auth/profile',
      {
        if (firstName != null) 'firstName': firstName.trim(),
        if (lastName != null) 'lastName': lastName.trim(),
        if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
        if (currentPassword != null && currentPassword.isNotEmpty)
          'currentPassword': currentPassword,
        if (newPassword != null && newPassword.isNotEmpty)
          'newPassword': newPassword,
      },
      token: token,
    );
  }

  // ==================== CATALOG & FILTERS (LIVE API) ====================

  /// Fetch Categories from Backend API
  Future<List<Map<String, dynamic>>> fetchCategories() async {
    final res = await get('/Categories');
    if (res is List) {
      return res.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  /// Fetch Dynamic Nanotek Filters for a Category
  Future<List<Map<String, dynamic>>> fetchCategoryFilters(int categoryId) async {
    final res = await get('/Categories/$categoryId/filters');
    if (res is List) {
      return res.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  /// Fetch Products with Live Faceted Filters
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
    Map<String, String>? dynamicFilters,
  }) async {
    final queryParams = <String, dynamic>{
      'status': 'Active',
      if (categoryId != null && categoryId > 0) 'categoryId': categoryId,
      if (brand != null && brand.isNotEmpty) 'brand': brand,
      if (searchQuery != null && searchQuery.isNotEmpty) 'search': searchQuery,
      if (minPrice != null) 'minPrice': minPrice,
      if (maxPrice != null) 'maxPrice': maxPrice,
      if (inStockOnly) 'inStockOnly': inStockOnly,
      'sortBy': sortBy,
      if (socket != null && socket.isNotEmpty) 'socket': socket,
      if (chipset != null && chipset.isNotEmpty) 'chipset': chipset,
      if (memoryType != null && memoryType.isNotEmpty) 'memoryType': memoryType,
      if (speed != null && speed.isNotEmpty) 'speed': speed,
      if (capacity != null && capacity.isNotEmpty) 'capacity': capacity,
      if (vram != null && vram.isNotEmpty) 'vram': vram,
      if (efficiency != null && efficiency.isNotEmpty) 'efficiency': efficiency,
    };

    if (dynamicFilters != null && dynamicFilters.isNotEmpty) {
      dynamicFilters.forEach((key, val) {
        if (val.trim().isNotEmpty) {
          queryParams[key] = val.trim();
        }
      });
    }

    final res = await get('/Products', queryParameters: queryParams);
    if (res is List) {
      return res.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  /// Fetch Single Product by ID
  Future<Map<String, dynamic>> fetchProductById(int id) async {
    final res = await get('/Products/$id');
    if (res is Map) {
      return Map<String, dynamic>.from(res);
    }
    throw ApiException('Product #$id not found.');
  }

  // ==================== ORDERS & CHECKOUT ====================

  /// Place Order with stock reservation in PostgreSQL
  Future<Map<String, dynamic>> createOrder({
    required String shippingAddress,
    required String paymentMethod,
    required List<Map<String, dynamic>> items,
    String? token,
  }) async {
    return await post(
      '/Orders',
      {
        'shippingAddress': shippingAddress,
        'paymentMethod': paymentMethod,
        'items': items,
      },
      token: token,
    );
  }

  /// Fetch Order History
  Future<List<Map<String, dynamic>>> fetchOrders({String? token}) async {
    final res = await get('/Orders', token: token);
    if (res is List) {
      return res.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  /// Fetch Single Order with line items
  Future<Map<String, dynamic>> fetchOrderById(int id, {String? token}) async {
    final res = await get('/Orders/$id', token: token);
    if (res is Map) {
      return Map<String, dynamic>.from(res);
    }
    throw ApiException('Order #$id not found.');
  }

  /// Cancel Order (Customer Cancellation & Automatic Stock Return)
  Future<Map<String, dynamic>> cancelOrder(int orderId, {String? token}) async {
    final res = await post('/Orders/$orderId/cancel', {}, token: token);
    if (res is Map) {
      return Map<String, dynamic>.from(res);
    }
    return {'message': 'Order cancelled successfully'};
  }

  // ==================== AFTER-SALES SERVICE REQUESTS (MEMBER 05) ====================

  /// Fetch Service Requests for Current Customer
  Future<List<Map<String, dynamic>>> fetchServiceRequests({
    String? status,
    String? startDate,
    String? endDate,
    String? token,
  }) async {
    final queryParams = <String>[];
    if (status != null && status.isNotEmpty && status.toUpperCase() != 'ALL') {
      queryParams.add('status=${Uri.encodeComponent(status)}');
    }
    if (startDate != null && startDate.isNotEmpty) {
      queryParams.add('startDate=${Uri.encodeComponent(startDate)}');
    }
    if (endDate != null && endDate.isNotEmpty) {
      queryParams.add('endDate=${Uri.encodeComponent(endDate)}');
    }

    final endpoint = queryParams.isEmpty ? '/ServiceRequests' : '/ServiceRequests?${queryParams.join('&')}';
    final res = await get(endpoint, token: token);
    if (res is List) {
      return res.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  /// Check Service Slot Availability for a Specific Date (Max 10 per day)
  Future<Map<String, dynamic>> checkServiceAvailability(String date, {String? token}) async {
    final res = await get('/ServiceRequests/availability?date=$date', token: token);
    if (res is Map<String, dynamic>) return res;
    return <String, dynamic>{};
  }

  /// Cancel a Service Request
  Future<Map<String, dynamic>> cancelServiceRequest(int id, {String? token}) async {
    final res = await post('/ServiceRequests/$id/cancel', {}, token: token);
    if (res is Map<String, dynamic>) return res;
    return <String, dynamic>{'message': 'Service request cancelled'};
  }

  /// Create and Submit a new Service Request
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
    final payload = <String, dynamic>{
      'title': (title != null && title.trim().isNotEmpty)
          ? title.trim()
          : (description != null && description.trim().isNotEmpty
              ? description.trim()
              : (problemDescription.isNotEmpty ? problemDescription : 'Service Request')),
      if (description != null && description.trim().isNotEmpty) 'description': description.trim(),
      if (orderId != null) 'orderId': orderId,
      if (preferredDate != null) 'preferredDate': preferredDate,
      if (preferredTime != null) 'preferredTime': preferredTime,
    };
    return await post(
      '/ServiceRequests',
      payload,
      token: token,
    );
  }

  /// Open Support Ticket in PostgreSQL (Backward Compatibility)
  Future<Map<String, dynamic>> createSupportTicket({
    int? orderId,
    int? productId,
    required String issueType,
    required String subject,
    required String description,
    String? attachmentUrl,
    String? token,
  }) async {
    return await createServiceRequest(
      orderId: orderId,
      productId: productId,
      problemDescription: description.isNotEmpty ? description : subject,
      problemCategory: issueType,
      troubleshootingSummary: subject,
      attemptCount: 1,
      attachmentUrl: attachmentUrl,
      token: token,
    );
  }

  /// Fetch Support Tickets for Current Customer (Backward Compatibility)
  Future<List<Map<String, dynamic>>> fetchSupportTickets({String? token}) async {
    return await fetchServiceRequests(token: token);
  }

  /// Scanner: Manual Product Lookup by barcode / QR
  /// Returns null when no product matches — callers should show a "not found" state.
  Future<Map<String, dynamic>?> lookupProductByBarcode(String barcode) async {
    try {
      final products = await fetchProducts(searchQuery: barcode);
      if (products.isNotEmpty) {
        return products.first;
      }
    } catch (_) {
      // Network error — surface null so caller can display error state
    }
    return null;
  }

  // ==================== CUSTOM BUILDS (MEMBER 02) ====================

  /// Fetch this customer's submitted custom builds from the backend.
  /// The backend filters by the authenticated user's JWT token.
  Future<List<Map<String, dynamic>>> fetchMyCustomBuilds({String? token}) async {
    final res = await get('/CustomBuilds', token: token);
    if (res is List) {
      return res.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  /// Submit a new custom build for staff review
  Future<Map<String, dynamic>> submitCustomBuild({
    required Map<String, dynamic> payload,
    String? token,
  }) async {
    return await post('/CustomBuilds', payload, token: token);
  }

  /// Resubmit an existing custom build after customer adjustments (PUT /{id})
  Future<Map<String, dynamic>> resubmitCustomBuild({
    required int buildId,
    required Map<String, dynamic> payload,
    String? token,
  }) async {
    return await put('/CustomBuilds/$buildId', payload, token: token);
  }

  /// Fetch full details for a custom build including all itemized components (GET /{id})
  Future<Map<String, dynamic>?> fetchCustomBuildById(int buildId, {String? token}) async {
    final res = await get('/CustomBuilds/$buildId', token: token);
    if (res is Map) {
      return Map<String, dynamic>.from(res);
    }
    return null;
  }
}
