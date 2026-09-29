import 'package:flutter/foundation.dart';
import '../../../services/api_service.dart';
import '../../catalog/data/models/product_model.dart';
import 'models/custom_build_model.dart';
import 'models/custom_build_slot.dart';

/// Reactive State Manager for Custom PC Building (Manual & AI)
class BuildService extends ChangeNotifier {
  static final BuildService instance = BuildService._internal();

  BuildService._internal();

  ApiService _apiService = ApiService();

  @visibleForTesting
  void setApiServiceForTesting(ApiService api) {
    _apiService = api;
  }

  // Active Draft Configuration
  final Map<BuildSlotType, ProductModel> _activeSlots = {};
  String _activeBuildName = 'My Custom PC Build';
  int? _editingBuildId;
  String? _technicianNotesForEdit;

  // Customer's Submitted Builds (loaded from backend API)
  final List<CustomBuildModel> _myBuilds = [];
  bool _isLoading = false;

  Map<BuildSlotType, ProductModel> get activeSlots =>
      Map.unmodifiable(_activeSlots);

  String get activeBuildName => _activeBuildName;
  void setActiveBuildName(String name) {
    _activeBuildName = name;
    notifyListeners();
  }

  bool get isEditingExistingBuild => _editingBuildId != null;
  int? get editingBuildId => _editingBuildId;
  String? get technicianNotesForEdit => _technicianNotesForEdit;
  bool get isLoading => _isLoading;

  /// Load an existing build that needs modification into the active builder
  void loadBuildForModification(CustomBuildModel build) {
    _editingBuildId = build.buildId;
    _activeBuildName = build.buildName;
    _technicianNotesForEdit = build.staffNotes;
    _activeSlots.clear();
    _activeSlots.addAll(build.selectedComponents);
    notifyListeners();
  }

  List<CustomBuildModel> get myBuilds => List.unmodifiable(_myBuilds);

  int get selectedCount => _activeSlots.length;
  bool get hasComponents => _activeSlots.isNotEmpty;

  ProductModel? getComponent(BuildSlotType slot) => _activeSlots[slot];

  void selectComponent(BuildSlotType slot, ProductModel product) {
    _activeSlots[slot] = product;
    notifyListeners();
  }

  void removeComponent(BuildSlotType slot) {
    _activeSlots.remove(slot);
    notifyListeners();
  }

  void clearDraft() {
    _activeSlots.clear();
    _activeBuildName = 'My Custom PC Build';
    _editingBuildId = null;
    _technicianNotesForEdit = null;
    notifyListeners();
  }

  // 1. Total Build Cost
  double get totalCost => _activeSlots.values.fold(
        0.0,
        (sum, p) => sum + p.price,
      );

  // 2. Estimated System Wattage Calculation
  int get estimatedWattage {
    int cpuWatts = _activeSlots[BuildSlotType.cpu]?.powerWattage ?? 65;
    int gpuWatts = _activeSlots[BuildSlotType.gpu]?.powerWattage ?? 150;
    const int systemOverhead = 80; // RAM, Fans, Chipset, Storage

    return cpuWatts + gpuWatts + systemOverhead;
  }

  // 3. Real-Time Compatibility Engine
  List<String> get compatibilityWarnings {
    final warnings = <String>[];

    final cpu = _activeSlots[BuildSlotType.cpu];
    final mobo = _activeSlots[BuildSlotType.motherboard];
    final ram = _activeSlots[BuildSlotType.ram];
    final psu = _activeSlots[BuildSlotType.psu];

    // Check Socket Match (AM5 vs LGA1700)
    if (cpu != null && mobo != null) {
      final cpuSocket = cpu.socket?.trim().toUpperCase();
      final moboSocket = mobo.socket?.trim().toUpperCase();
      if (cpuSocket != null &&
          moboSocket != null &&
          cpuSocket.isNotEmpty &&
          moboSocket.isNotEmpty &&
          cpuSocket != moboSocket) {
        warnings.add(
            'Socket Mismatch: CPU requires socket $cpuSocket, but Motherboard has $moboSocket.');
      }
    }

    // Check Memory Type Match (DDR5 vs DDR4)
    if (mobo != null && ram != null) {
      final moboRam = mobo.memoryType?.trim().toUpperCase();
      final ramType = ram.memoryType?.trim().toUpperCase();
      if (moboRam != null &&
          ramType != null &&
          moboRam.isNotEmpty &&
          ramType.isNotEmpty &&
          moboRam != ramType) {
        warnings.add(
            'RAM Incompatibility: Motherboard supports $moboRam, but selected RAM is $ramType.');
      }
    }

    // Check Power Supply Capacity
    if (psu != null && psu.powerWattage != null) {
      if (psu.powerWattage! < estimatedWattage) {
        warnings.add(
            'Underpowered PSU: Estimated system draw is ${estimatedWattage}W, which exceeds ${psu.powerWattage}W.');
      }
    }

    return warnings;
  }

  bool get isCompatible => compatibilityWarnings.isEmpty;

  /// List of required slots that have not been selected yet
  List<BuildSlotInfo> get missingRequiredSlots {
    return BuildSlotInfo.allSlots
        .where((slot) => slot.isRequired && !_activeSlots.containsKey(slot.type))
        .toList();
  }

  /// Whether all mandatory hardware slots (CPU, Motherboard, RAM, GPU, PSU) are configured
  bool get hasAllRequiredComponents => missingRequiredSlots.isEmpty;

  /// Ready for store review only when all required components are present AND compatibility checks pass
  bool get canSubmitForReview => hasAllRequiredComponents && isCompatible;

  bool get hasCoreComponents {
    return _activeSlots.containsKey(BuildSlotType.cpu) &&
        _activeSlots.containsKey(BuildSlotType.motherboard) &&
        _activeSlots.containsKey(BuildSlotType.ram);
  }

  /// Load the current customer's submitted builds from the backend API.
  /// Called when the user opens the Build PC Hub screen.
  Future<void> loadMyBuilds({String? token}) async {
    _isLoading = true;
    notifyListeners();
    try {
      final raw = await _apiService.fetchMyCustomBuilds(token: token);
      _myBuilds.clear();
      for (final item in raw) {
        try {
          _myBuilds.add(CustomBuildModel.fromJson(item));
        } catch (_) {
          // Skip malformed entries
        }
      }
    } catch (_) {
      // Network error — keep existing list (empty on first load)
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetch full details for a custom build by ID from the backend API.
  Future<CustomBuildModel?> fetchBuildById(int buildId, {String? token}) async {
    try {
      final raw = await _apiService.fetchCustomBuildById(buildId, token: token);
      if (raw != null) {
        final fullBuild = CustomBuildModel.fromJson(raw);
        final index = _myBuilds.indexWhere((b) => b.buildId == buildId);
        if (index >= 0) {
          _myBuilds[index] = fullBuild;
          notifyListeners();
        }
        return fullBuild;
      }
    } catch (_) {}
    return null;
  }

  // 4. Submit Build for Store Staff Review
  Future<CustomBuildModel> submitBuildForReview({
    required String buildName,
    String? customerNotes,
    String? token,
  }) async {
    final payload = _buildPayload(buildName: buildName, customerNotes: customerNotes);

    // Live API call - throws ApiException on failure
    final apiResponse = await _apiService.submitCustomBuild(payload: payload, token: token);
    final build = CustomBuildModel.fromJson(apiResponse);

    _myBuilds.insert(0, build);
    clearDraft();
    notifyListeners();
    return build;
  }

  /// 5. Resubmit an existing build after customer made requested adjustments
  Future<CustomBuildModel> resubmitBuild({
    String? customerNotes,
    String? token,
  }) async {
    if (_editingBuildId == null) {
      return submitBuildForReview(
        buildName: _activeBuildName,
        customerNotes: customerNotes,
        token: token,
      );
    }

    final targetId = _editingBuildId!;
    final index = _myBuilds.indexWhere((b) => b.buildId == targetId);
    final payload = _buildPayload(
      buildName: _activeBuildName,
      customerNotes: customerNotes ?? _technicianNotesForEdit,
    );

    // Live API call - throws ApiException on failure
    final apiResponse = await _apiService.resubmitCustomBuild(
      buildId: targetId,
      payload: payload,
      token: token,
    );

    final updatedBuild = CustomBuildModel.fromJson(apiResponse);

    if (index >= 0) {
      _myBuilds[index] = updatedBuild;
    } else {
      _myBuilds.insert(0, updatedBuild);
    }

    clearDraft();
    notifyListeners();
    return updatedBuild;
  }

  /// Build the JSON payload for submit/resubmit API calls
  Map<String, dynamic> _buildPayload({
    required String buildName,
    String? customerNotes,
  }) {
    return {
      'buildName': buildName.trim().isEmpty ? 'Custom Rig' : buildName.trim(),
      'customerNotes': customerNotes,
      'totalCost': totalCost,
      'estimatedWattage': estimatedWattage,
      'isCompatible': isCompatible,
      'compatibilityWarnings': compatibilityWarnings,
      'components': _activeSlots.entries
          .map((e) => {
                'slotType': e.key.name,
                'productId': e.value.productId,
              })
          .toList(),
    };
  }
}
