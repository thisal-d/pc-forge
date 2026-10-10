import 'package:flutter/material.dart';
import '../../../../core/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/product_card.dart';
import '../../../cart/data/cart_service.dart';
import '../../data/catalog_repository.dart';
import '../../data/models/product_model.dart';

class SearchScreen extends StatefulWidget {
  final CatalogRepository? repository;

  const SearchScreen({super.key, this.repository});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  late final CatalogRepository _repository;
  final CartService _cartService = CartService.instance;

  List<ProductModel> _results = [];
  bool _isLoading = false;
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? CatalogRepository();
  }

  final List<String> _popularKeywords = [
    'RTX 4070 Ti',
    'Ryzen 7',
    'B650',
    'DDR5',
    '850W',
    'Corsair',
    'ASUS',
    'Kingston',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) {
      setState(() {
        _results = [];
        _hasSearched = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    final results = await _repository.getProducts(
      filter: CatalogFilter(searchQuery: cleanQuery),
    );

    if (mounted) {
      setState(() {
        _results = results;
        _isLoading = false;
      });
    }
  }

  void _handleAddToCart(ProductModel product) {
    final error = _cartService.addItem(product, quantity: 1);
    if (!mounted) return;

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppColors.alertRed),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added ${product.name} to Cart'),
          backgroundColor: AppColors.stockGreen,
          duration: const Duration(seconds: 2),
          action: SnackBarAction(
            label: 'View Cart',
            textColor: Colors.white,
            onPressed: () => Navigator.pushNamed(context, AppRoutes.cart),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Search PC Components'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Barcode Scanner',
            onPressed: () => Navigator.pushNamed(context, AppRoutes.scanner),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Input
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: AppColors.border),
                boxShadow: AppColors.softShadow,
              ),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(fontSize: 14, color: AppColors.primaryDark),
                decoration: InputDecoration(
                  hintText: 'Search parts (e.g. 3060, Ryzen, SSD...)',
                  hintStyle: const TextStyle(color: AppColors.secondaryText, fontSize: 13),
                  prefixIcon: const Icon(Icons.search, color: AppColors.secondaryText, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18, color: AppColors.secondaryText),
                          onPressed: () {
                            _searchController.clear();
                            _performSearch('');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                onChanged: (val) => _performSearch(val),
                onSubmitted: (val) => _performSearch(val),
              ),
            ),
          ),

          // Suggested Search Queries
          if (!_hasSearched) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Popular Searches',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primaryDark),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _popularKeywords.map((kw) {
                      return ActionChip(
                        backgroundColor: AppColors.surface,
                        side: const BorderSide(color: AppColors.border),
                        label: Text(kw, style: const TextStyle(fontSize: 12, color: AppColors.primaryDark)),
                        onPressed: () {
                          _searchController.text = kw;
                          _performSearch(kw);
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],

          // Search Results
          if (_isLoading)
            const Expanded(
              child: Center(child: CircularProgressIndicator(color: AppColors.primaryBlue)),
            )
          else if (_hasSearched && _results.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.search_off_rounded, size: 64, color: AppColors.secondaryText),
                    const SizedBox(height: 12),
                    Text(
                      'No components matched "${_searchController.text}"',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.primaryDark),
                    ),
                    const SizedBox(height: 4),
                    const Text('Try checking for typos or searching by brand or socket',
                        style: TextStyle(color: AppColors.secondaryText, fontSize: 13)),
                  ],
                ),
              ),
            )
          else if (_results.isNotEmpty)
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: _results.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final product = _results[index];
                  return ProductCard(
                    product: product,
                    onTap: () {
                      Navigator.pushNamed(
                        context,
                        AppRoutes.productDetail,
                        arguments: product,
                      );
                    },
                    onAddToCart: () => _handleAddToCart(product),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
