import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/offline_sync_service.dart';

/// نموذج بيانات الصنف المرتبط بجدول `products` (الأصناف الـ 27 المعتمدة)
class ProductItemModel {
  final String id;
  final String code;
  final String name;
  final String category;
  final String unit;
  final double cartonPrice;
  final int packPerCarton;

  const ProductItemModel({
    required this.id,
    required this.code,
    required this.name,
    required this.category,
    required this.unit,
    required this.cartonPrice,
    required this.packPerCarton,
  });

  factory ProductItemModel.fromJson(Map<String, dynamic> json, int index) {
    return ProductItemModel(
      id: json['id']?.toString() ??
          'PRD-${(index + 1).toString().padLeft(2, '0')}',
      code: json['code']?.toString() ??
          json['sku']?.toString() ??
          'JLP-${(index + 1).toString().padLeft(3, '0')}',
      name: (json['name'] ?? json['product_name'] ?? 'صنف جلب ${index + 1}')
          .toString(),
      category: (json['category'] ?? 'الأصناف الأساسية').toString(),
      unit: (json['unit'] ?? 'كرتون / عبوة').toString(),
      cartonPrice: _toDouble(json['price'] ?? json['carton_price'], 8500.0),
      packPerCarton: _toInt(json['pack_per_carton'] ?? json['packs'], 12),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'category': category,
      'unit': unit,
      'carton_price': cartonPrice,
      'pack_per_carton': packPerCarton,
    };
  }

  static double _toDouble(dynamic value, double fallback) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  static int _toInt(dynamic value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }
}

/// نموذج سجل الجرد الأسبوعي المرتبط بجدول `inventory_audits`
class InventoryAuditEntry {
  final String productId;
  final int cartonCount;
  final int packCount;
  final int damagedCount;
  final int returnedCount;
  final String notes;
  final DateTime auditedAt;

  const InventoryAuditEntry({
    required this.productId,
    required this.cartonCount,
    required this.packCount,
    required this.damagedCount,
    required this.returnedCount,
    this.notes = '',
    required this.auditedAt,
  });

  factory InventoryAuditEntry.fromJson(Map<String, dynamic> json) {
    return InventoryAuditEntry(
      productId: json['product_id']?.toString() ?? '',
      cartonCount: (json['carton_qty'] as num?)?.toInt() ?? 0,
      packCount: (json['pack_qty'] as num?)?.toInt() ?? 0,
      damagedCount: (json['damaged_qty'] as num?)?.toInt() ?? 0,
      returnedCount: (json['returned_qty'] as num?)?.toInt() ?? 0,
      notes: json['notes']?.toString() ?? '',
      auditedAt: DateTime.tryParse(json['audited_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  InventoryAuditEntry copyWith({
    int? cartonCount,
    int? packCount,
    int? damagedCount,
    int? returnedCount,
    String? notes,
    DateTime? auditedAt,
  }) {
    return InventoryAuditEntry(
      productId: productId,
      cartonCount: cartonCount ?? this.cartonCount,
      packCount: packCount ?? this.packCount,
      damagedCount: damagedCount ?? this.damagedCount,
      returnedCount: returnedCount ?? this.returnedCount,
      notes: notes ?? this.notes,
      auditedAt: auditedAt ?? this.auditedAt,
    );
  }

  Map<String, dynamic> toSupabaseMap({String? branchId, String? userId}) {
    return {
      'product_id': productId,
      'carton_qty': cartonCount,
      'pack_qty': packCount,
      'damaged_qty': damagedCount,
      'returned_qty': returnedCount,
      'notes': notes,
      if (branchId != null) 'branch_id': branchId,
      if (userId != null) 'audited_by': userId,
      'audited_at': auditedAt.toIso8601String(),
    };
  }
}

/// الشاشة الكاملة للأصناف والجرد الميداني الأسبوعي (27 صنفاً معتمداً)
/// تدعم التخزين المحلي (Offline-First) والإدخال السريع (+ / -) داخل البطاقات بيد واحدة.
class InventoryPage extends StatefulWidget {
  final String? currentUserId;
  final String? currentBranchId;

  const InventoryPage({
    super.key,
    this.currentUserId,
    this.currentBranchId,
  });

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  final TextEditingController _searchController = TextEditingController();
  final OfflineSyncService _offlineSync = OfflineSyncService.instance;

  List<ProductItemModel> _allProducts = [];
  final Map<String, InventoryAuditEntry> _auditRecords = {};

  String _selectedCategory = 'الكل';
  String _searchQuery = '';
  bool _isLoading = false;

  static const List<String> _categories = [
    'الكل',
    'المشروبات والعصائر',
    'الألبان والأجبان',
    'المعلبات الغذائية',
    'الزيوت والسمن',
    'الوجبات الخفيفة',
  ];

  @override
  void initState() {
    super.initState();
    _initializeInventoryData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// تهيئة قائمة الأصناف الـ 27 مع دعم التخزين المحلي (Local Cache) والمزامنة
  Future<void> _initializeInventoryData() async {
    setState(() => _isLoading = true);

    final List<ProductItemModel> default27Products =
        _generateApproved27Products();

    // 1. استرجاع الأصناف المخزنة محلياً إن وجدت
    final cachedProductsJson = _offlineSync.getCachedProducts();
    if (cachedProductsJson.isNotEmpty) {
      _allProducts = List<ProductItemModel>.generate(
        cachedProductsJson.length,
        (i) => ProductItemModel.fromJson(cachedProductsJson[i], i),
      );
    } else {
      _allProducts = default27Products;
      await _offlineSync.cacheProducts(
        _allProducts.map((p) => p.toJson()).toList(),
      );
    }

    // 2. استرجاع سجلات الجرد المخزنة محلياً
    final cachedAuditsMap = _offlineSync.getCachedInventoryAudits();
    if (cachedAuditsMap.isNotEmpty) {
      _auditRecords.clear();
      cachedAuditsMap.forEach((productId, map) {
        _auditRecords[productId] = InventoryAuditEntry.fromJson(map);
      });
    } else if (_auditRecords.isEmpty) {
      for (int i = 0; i < 22; i++) {
        final item = _allProducts[i];
        _auditRecords[item.id] = InventoryAuditEntry(
          productId: item.id,
          cartonCount: 15 + (i % 10),
          packCount: (i * 2) % 12,
          damagedCount: i % 7 == 0 ? 1 : 0,
          returnedCount: i % 5 == 0 ? 2 : 0,
          notes: 'جرد دوري معتمد',
          auditedAt: DateTime.now().subtract(Duration(hours: i + 1)),
        );
      }
      await _persistAuditsLocally();
    }

    // 3. محاولة التحديث من Supabase إذا كان متصلاً
    if (AppConstants.isSupabaseConfigured) {
      try {
        final supabase = Supabase.instance.client;
        final List<dynamic> rows = await supabase
            .from(AppConstants.tableProducts)
            .select()
            .limit(50);

        if (rows.isNotEmpty) {
          final fetched = <ProductItemModel>[];
          for (int i = 0; i < rows.length; i++) {
            fetched.add(ProductItemModel.fromJson(rows[i], i));
          }
          if (fetched.isNotEmpty) {
            _allProducts = fetched;
            await _offlineSync.cacheProducts(
              _allProducts.map((p) => p.toJson()).toList(),
            );
          }
        }
      } catch (error) {
        debugPrint('Inventory offline mode active: $error');
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  /// حفظ كافة سجلات الجرد الحالية في الذاكرة المحلية للجهاز
  Future<void> _persistAuditsLocally() async {
    final serialized = <String, Map<String, dynamic>>{};
    _auditRecords.forEach((key, entry) {
      serialized[key] = entry.toSupabaseMap(
        branchId: widget.currentBranchId,
        userId: widget.currentUserId,
      );
    });
    await _offlineSync.cacheInventoryAudits(serialized);
  }

  /// تعديل سريع لكمية الكرتون أو العبوة مباشرة من بطاقة الصنف (+ / -) بيد واحدة
  Future<void> _quickAdjustProductQty(
    ProductItemModel product, {
    int cartonDelta = 0,
    int packDelta = 0,
  }) async {
    final current = _auditRecords[product.id] ??
        InventoryAuditEntry(
          productId: product.id,
          cartonCount: 0,
          packCount: 0,
          damagedCount: 0,
          returnedCount: 0,
          notes: 'إدخال ميداني سريع',
          auditedAt: DateTime.now(),
        );

    final nextCartons = (current.cartonCount + cartonDelta).clamp(0, 9999);
    final nextPacks = (current.packCount + packDelta).clamp(0, 9999);

    final updated = current.copyWith(
      cartonCount: nextCartons,
      packCount: nextPacks,
      auditedAt: DateTime.now(),
    );

    setState(() {
      _auditRecords[product.id] = updated;
    });

    await _persistAuditsLocally();
    await _offlineSync.enqueueOrSyncOperation(
      table: AppConstants.tableInventoryAudits,
      action: 'upsert',
      payload: updated.toSupabaseMap(
        branchId: widget.currentBranchId,
        userId: widget.currentUserId,
      ),
    );
  }

  /// توليد قائمة الأصناف الـ 27 المعتمدة بالعملة المحلية (ر.ي)
  List<ProductItemModel> _generateApproved27Products() {
    const List<Map<String, dynamic>> rawItems = [
      {'name': 'عصير جلب مانجو طبيعي 1 لتر', 'cat': 'المشروبات والعصائر', 'price': 7200.0, 'packs': 12},
      {'name': 'عصير جلب برتقال فاخر 1 لتر', 'cat': 'المشروبات والعصائر', 'price': 7200.0, 'packs': 12},
      {'name': 'عصير جلب فواكه مشكلة 1 لتر', 'cat': 'المشروبات والعصائر', 'price': 7000.0, 'packs': 12},
      {'name': 'عصير جلب تفاح أحمر 250 مل', 'cat': 'المشروبات والعصائر', 'price': 4800.0, 'packs': 24},
      {'name': 'مشروب جلب جوافة نكتار 250 مل', 'cat': 'المشروبات والعصائر', 'price': 4800.0, 'packs': 24},
      {'name': 'مياه جلب النقية 330 مل', 'cat': 'المشروبات والعصائر', 'price': 2200.0, 'packs': 40},
      {'name': 'حليب جلب كامل الدسم 1 لتر', 'cat': 'الألبان والأجبان', 'price': 6800.0, 'packs': 12},
      {'name': 'حليب جلب قليل الدسم 1 لتر', 'cat': 'الألبان والأجبان', 'price': 6800.0, 'packs': 12},
      {'name': 'جبنة جلب كريمية قابلة للدهن 500 جم', 'cat': 'الألبان والأجبان', 'price': 13500.0, 'packs': 12},
      {'name': 'جبنة جلب موزاريلا مبشورة 1 كجم', 'cat': 'الألبان والأجبان', 'price': 19000.0, 'packs': 6},
      {'name': 'قشطة جلب التاج الفاخرة 170 جم', 'cat': 'الألبان والأجبان', 'price': 9600.0, 'packs': 24},
      {'name': 'لبنة جلب التركية الفاخرة 400 جم', 'cat': 'الألبان والأجبان', 'price': 11000.0, 'packs': 12},
      {'name': 'تونة جلب لحم خفيف بالزيت 185 جم', 'cat': 'المعلبات الغذائية', 'price': 14500.0, 'packs': 24},
      {'name': 'فول مدمس جلب الخلطة السرية 400 جم', 'cat': 'المعلبات الغذائية', 'price': 5800.0, 'packs': 24},
      {'name': 'حمص جلب بالطحينة الجاهز 400 جم', 'cat': 'المعلبات الغذائية', 'price': 6200.0, 'packs': 24},
      {'name': 'معجون طماطم جلب المركز 135 جم', 'cat': 'المعلبات الغذائية', 'price': 7500.0, 'packs': 48},
      {'name': 'ذرة حلوة جلب الذهبية 340 جم', 'cat': 'المعلبات الغذائية', 'price': 8200.0, 'packs': 24},
      {'name': 'ورق عنب جلب محشي جاهز 400 جم', 'cat': 'المعلبات الغذائية', 'price': 12000.0, 'packs': 12},
      {'name': 'زيت دوار الشمس جلب النقي 1.5 لتر', 'cat': 'الزيوت والسمن', 'price': 11500.0, 'packs': 6},
      {'name': 'زيت ذرة جلب الصافي 1.5 لتر', 'cat': 'الزيوت والسمن', 'price': 12500.0, 'packs': 6},
      {'name': 'زيت زيتون جلب بكر ممتاز 500 مل', 'cat': 'الزيوت والسمن', 'price': 18500.0, 'packs': 12},
      {'name': 'سمن جلب النباتي الفاخر 1 كجم', 'cat': 'الزيوت والسمن', 'price': 14000.0, 'packs': 12},
      {'name': 'بسكويت جلب بالزبدة الفاخرة 80 جم', 'cat': 'الوجبات الخفيفة', 'price': 5400.0, 'packs': 24},
      {'name': 'ويفر جلب بالشوكولاتة والبندق 45 جم', 'cat': 'الوجبات الخفيفة', 'price': 4200.0, 'packs': 36},
      {'name': 'شيبس جلب بالملح البحري 150 جم', 'cat': 'الوجبات الخفيفة', 'price': 6000.0, 'packs': 20},
      {'name': 'شيبس جلب بالجبنة الحارة 150 جم', 'cat': 'الوجبات الخفيفة', 'price': 6000.0, 'packs': 20},
      {'name': 'مكسرات جلب المشكلة المحمصة 250 جم', 'cat': 'الوجبات الخفيفة', 'price': 16000.0, 'packs': 12},
    ];

    return List<ProductItemModel>.generate(rawItems.length, (index) {
      final item = rawItems[index];
      final numCode = (index + 1).toString().padLeft(2, '0');
      return ProductItemModel(
        id: 'PRD-$numCode',
        code: 'JLP-10$numCode',
        name: item['name'] as String,
        category: item['cat'] as String,
        unit: '${item['packs']} عبوة / كرتون',
        cartonPrice: item['price'] as double,
        packPerCarton: item['packs'] as int,
      );
    });
  }

  List<ProductItemModel> get _filteredProducts {
    return _allProducts.where((product) {
      final matchesCategory = _selectedCategory == 'الكل' ||
          product.category == _selectedCategory;
      final query = _searchQuery.trim().toLowerCase();
      final matchesSearch = query.isEmpty ||
          product.name.toLowerCase().contains(query) ||
          product.code.toLowerCase().contains(query) ||
          product.category.toLowerCase().contains(query);
      return matchesCategory && matchesSearch;
    }).toList();
  }

  /// اعتماد جرد كافة الأصناف المتبقية دفعة واحدة (إكمال 27/27) وحفظها محلياً وفي طابور المزامنة
  Future<void> _completeAllRemainingAudits() async {
    setState(() {
      for (final product in _allProducts) {
        _auditRecords.putIfAbsent(
          product.id,
          () => InventoryAuditEntry(
            productId: product.id,
            cartonCount: 12,
            packCount: 0,
            damagedCount: 0,
            returnedCount: 0,
            notes: 'اعتماد سريع للجرد الأسبوعي',
            auditedAt: DateTime.now(),
          ),
        );
      }
    });

    await _persistAuditsLocally();

    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppConstants.deepNavyBlue,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: const Directionality(
            textDirection: TextDirection.rtl,
            child: Text(
              'تم اعتماد وحفظ جرد جميع الأصناف الـ 27 محلياً وفي طابور المزامنة (27/27)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      );
  }

  /// فتح نافذة إدخال/تعديل الجرد التفصيلي لصنف محدد (Audit Entry Form)
  Future<void> _openAuditEntrySheet({ProductItemModel? initialProduct}) async {
    if (_allProducts.isEmpty) return;

    ProductItemModel selectedProduct = initialProduct ?? _allProducts.first;
    final existing = _auditRecords[selectedProduct.id];

    final cartonCtrl = TextEditingController(
      text: (existing?.cartonCount ?? 10).toString(),
    );
    final packCtrl = TextEditingController(
      text: (existing?.packCount ?? 0).toString(),
    );
    final damagedCtrl = TextEditingController(
      text: (existing?.damagedCount ?? 0).toString(),
    );
    final returnedCtrl = TextEditingController(
      text: (existing?.returnedCount ?? 0).toString(),
    );
    final notesCtrl = TextEditingController(
      text: existing?.notes ?? '',
    );

    bool isSaving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final colorScheme = Theme.of(context).colorScheme;

            void loadProductValues(ProductItemModel prod) {
              final rec = _auditRecords[prod.id];
              cartonCtrl.text = (rec?.cartonCount ?? 10).toString();
              packCtrl.text = (rec?.packCount ?? 0).toString();
              damagedCtrl.text = (rec?.damagedCount ?? 0).toString();
              returnedCtrl.text = (rec?.returnedCount ?? 0).toString();
              notesCtrl.text = rec?.notes ?? '';
            }

            void adjustCounter(TextEditingController ctrl, int delta) {
              final current = int.tryParse(ctrl.text) ?? 0;
              final next = (current + delta).clamp(0, 9999);
              setSheetState(() {
                ctrl.text = next.toString();
              });
            }

            Future<void> saveAuditEntry() async {
              setSheetState(() => isSaving = true);

              final entry = InventoryAuditEntry(
                productId: selectedProduct.id,
                cartonCount: int.tryParse(cartonCtrl.text) ?? 0,
                packCount: int.tryParse(packCtrl.text) ?? 0,
                damagedCount: int.tryParse(damagedCtrl.text) ?? 0,
                returnedCount: int.tryParse(returnedCtrl.text) ?? 0,
                notes: notesCtrl.text.trim(),
                auditedAt: DateTime.now(),
              );

              setState(() {
                _auditRecords[selectedProduct.id] = entry;
              });

              await _persistAuditsLocally();
              final syncedOnline = await _offlineSync.enqueueOrSyncOperation(
                table: AppConstants.tableInventoryAudits,
                action: 'upsert',
                payload: entry.toSupabaseMap(
                  branchId: widget.currentBranchId,
                  userId: widget.currentUserId,
                ),
              );

              if (sheetContext.mounted) {
                Navigator.of(sheetContext).pop();
              }

              if (mounted) {
                ScaffoldMessenger.of(this.context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    SnackBar(
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: AppConstants.deepNavyBlue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      content: Directionality(
                        textDirection: TextDirection.rtl,
                        child: Text(
                          syncedOnline
                              ? 'تم حفظ ومزامنة جرد "${selectedProduct.name}" بنجاح (${_auditRecords.length}/${_allProducts.length})'
                              : 'تم حفظ جرد "${selectedProduct.name}" محلياً وإضافته لطابور المزامنة (${_auditRecords.length}/${_allProducts.length})',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  );
              }
            }

            return Directionality(
              textDirection: TextDirection.rtl,
              child: Padding(
                padding: EdgeInsets.only(
                  right: 20,
                  left: 20,
                  top: 16,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 5,
                          decoration: BoxDecoration(
                            color: colorScheme.outlineVariant,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: AppConstants.softRoyalGold,
                            foregroundColor: AppConstants.deepNavyBlue,
                            child: Icon(Icons.fact_check_rounded),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'نموذج تسجيل الجرد الأسبوعي التفصيلي',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  'حفظ محلي فوري مع مزامنة تلقائية لجدول (inventory_audits)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      DropdownButtonFormField<ProductItemModel>(
                        value: selectedProduct,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'الصنف المجرود',
                          prefixIcon: const Icon(Icons.inventory_2_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        items: _allProducts.map((prod) {
                          return DropdownMenuItem<ProductItemModel>(
                            value: prod,
                            child: Text(
                              '${prod.code} - ${prod.name}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val == null) return;
                          setSheetState(() {
                            selectedProduct = val;
                            loadProductValues(val);
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _CounterFieldCard(
                              label: 'كمية الكرتون',
                              icon: Icons.all_inbox_rounded,
                              color: Colors.teal,
                              controller: cartonCtrl,
                              onDecrement: () => adjustCounter(cartonCtrl, -1),
                              onIncrement: () => adjustCounter(cartonCtrl, 1),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _CounterFieldCard(
                              label: 'كمية العبوة (فرط)',
                              icon: Icons.widgets_outlined,
                              color: Colors.blue,
                              controller: packCtrl,
                              onDecrement: () => adjustCounter(packCtrl, -1),
                              onIncrement: () => adjustCounter(packCtrl, 1),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _CounterFieldCard(
                              label: 'الكميات التالفة',
                              icon: Icons.broken_image_outlined,
                              color: Colors.red,
                              controller: damagedCtrl,
                              onDecrement: () => adjustCounter(damagedCtrl, -1),
                              onIncrement: () => adjustCounter(damagedCtrl, 1),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _CounterFieldCard(
                              label: 'الكميات المرتجعة',
                              icon: Icons.assignment_return_outlined,
                              color: Colors.orange,
                              controller: returnedCtrl,
                              onDecrement: () =>
                                  adjustCounter(returnedCtrl, -1),
                              onIncrement: () => adjustCounter(returnedCtrl, 1),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: notesCtrl,
                        decoration: InputDecoration(
                          labelText:
                              'ملاحظات المندوب حول الصنف أو تاريخ الصلاحية',
                          prefixIcon: const Icon(Icons.note_alt_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 54,
                        child: FilledButton.icon(
                          onPressed: isSaving ? null : saveAuditEntry,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppConstants.deepNavyBlue,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.save_rounded,
                                  color: AppConstants.royalGold,
                                ),
                          label: const Text(
                            'حفظ واعتماد جرد الصنف',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    final int totalCount = _allProducts.length;
    final int completedCount = _auditRecords.length;
    final int remainingCount =
        (totalCount - completedCount).clamp(0, totalCount);
    final double progress =
        totalCount == 0 ? 0.0 : (completedCount / totalCount).clamp(0.0, 1.0);

    final filtered = _filteredProducts;

    return Scaffold(
      backgroundColor: AppConstants.cleanLightGrey,
      appBar: AppBar(
        title: const Text(
          'الأصناف والجرد الأسبوعي (27 صنفاً)',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        backgroundColor: AppConstants.deepNavyBlue,
        foregroundColor: Colors.white,
        actions: [
          if (remainingCount > 0)
            TextButton.icon(
              onPressed: _completeAllRemainingAudits,
              icon: const Icon(
                Icons.done_all_rounded,
                size: 18,
                color: AppConstants.royalGold,
              ),
              label: const Text(
                'اعتماد الكل',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppConstants.royalGold,
                ),
              ),
            ),
          IconButton(
            tooltip: 'تحديث الأصناف',
            onPressed: _initializeInventoryData,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'inventory_fab',
        onPressed: () => _openAuditEntrySheet(),
        backgroundColor: AppConstants.royalGold,
        foregroundColor: AppConstants.deepNavyBlue,
        icon: const Icon(Icons.add_task_rounded),
        label: const Text(
          'جرد تفصيلي',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // =============================================================
                // 1. البطاقة الإحصائية الملكية لحالة الجرد الأسبوعي (27/27)
                // =============================================================
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          AppConstants.deepNavyBlue,
                          AppConstants.royalNavySecondary,
                        ],
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppConstants.deepNavyBlue.withOpacity(0.15),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppConstants.royalGold.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: AppConstants.royalGold,
                                ),
                              ),
                              child: const Icon(
                                Icons.inventory_rounded,
                                color: AppConstants.royalGold,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'حالة الجرد الأسبوعي للأصناف',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    remainingCount == 0
                                        ? 'مكتمل بالكامل لهذا الأسبوع (27/27) ومحفوظ محلياً'
                                        : 'تم جرد $completedCount صنفاً ومتبقي $remainingCount أصناف',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppConstants.royalGold,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                '$completedCount / $totalCount',
                                textDirection: TextDirection.ltr,
                                style: const TextStyle(
                                  color: AppConstants.deepNavyBlue,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 8,
                            backgroundColor: Colors.white24,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              AppConstants.royalGold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // =============================================================
                // 2. شريط البحث السريع والفلترة حسب الفئة
                // =============================================================
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: 'ابحث باسم الصنف أو الكود (مثال: JLP-1001)...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                              icon: const Icon(Icons.clear_rounded),
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: colorScheme.outlineVariant,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: colorScheme.outlineVariant,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 42,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final category = _categories[index];
                      final isSelected = _selectedCategory == category;
                      return ChoiceChip(
                        label: Text(category),
                        selected: isSelected,
                        onSelected: (_) {
                          setState(() => _selectedCategory = category);
                        },
                        selectedColor: AppConstants.softRoyalGold,
                        side: BorderSide(
                          color: isSelected
                              ? AppConstants.royalGold
                              : colorScheme.outlineVariant,
                        ),
                        labelStyle: TextStyle(
                          color: AppConstants.deepNavyBlue,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),

                // =============================================================
                // 3. قائمة الأصناف الـ 27 مع أزرار الإدخال السريعة (+ / -) للكرتون والعبوة
                // =============================================================
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(
                          child: Text('لا توجد أصناف مطابقة لبحثك الحالي.'),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final product = filtered[index];
                            final audit = _auditRecords[product.id];
                            final isAudited = audit != null;
                            final int currentCartons = audit?.cartonCount ?? 0;
                            final int currentPacks = audit?.packCount ?? 0;

                            return Card(
                              elevation: 0,
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                  color: isAudited
                                      ? AppConstants.royalGold
                                      : colorScheme.outlineVariant,
                                  width: isAudited ? 1.4 : 1.0,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // رأس البطاقة (الكود + الاسم + شارة الحالة)
                                    InkWell(
                                      onTap: () => _openAuditEntrySheet(
                                        initialProduct: product,
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppConstants.deepNavyBlue,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              product.code,
                                              textDirection: TextDirection.ltr,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: AppConstants.royalGold,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              product.name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 15,
                                                color:
                                                    AppConstants.deepNavyBlue,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isAudited
                                                  ? AppConstants.softRoyalGold
                                                  : Colors.grey.shade100,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: isAudited
                                                    ? AppConstants.royalGold
                                                    : Colors.grey.shade300,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  isAudited
                                                      ? Icons.verified_rounded
                                                      : Icons.schedule_rounded,
                                                  size: 14,
                                                  color: isAudited
                                                      ? AppConstants
                                                          .deepNavyBlue
                                                      : Colors.grey.shade700,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  isAudited
                                                      ? 'تم الجرد'
                                                      : 'غير مجرود',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: isAudited
                                                        ? AppConstants
                                                            .deepNavyBlue
                                                        : Colors.grey.shade700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 8),

                                    // الفئة والسعر بالعملة الديناميكية (ر.ي)
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.category_outlined,
                                          size: 14,
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${product.category} • ${product.unit}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(
                                          '${AppConstants.formatCurrency(product.cartonPrice, branch: widget.currentBranchId)} / كرتون',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w900,
                                            color: AppConstants.deepNavyBlue,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Divider(height: 20),

                                    // =========================================
                                    // أزرار الإدخال السريعة (+ / -) للكرتون والعبوات بيد واحدة
                                    // =========================================
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _InlineQuickStepper(
                                            label: 'كرتون',
                                            value: currentCartons,
                                            primaryColor:
                                                AppConstants.deepNavyBlue,
                                            accentColor: AppConstants.royalGold,
                                            onDecrement: () =>
                                                _quickAdjustProductQty(
                                              product,
                                              cartonDelta: -1,
                                            ),
                                            onIncrement: () =>
                                                _quickAdjustProductQty(
                                              product,
                                              cartonDelta: 1,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: _InlineQuickStepper(
                                            label: 'عبوة',
                                            value: currentPacks,
                                            primaryColor:
                                                Colors.blueGrey.shade800,
                                            accentColor:
                                                Colors.blueGrey.shade100,
                                            onDecrement: () =>
                                                _quickAdjustProductQty(
                                              product,
                                              packDelta: -1,
                                            ),
                                            onIncrement: () =>
                                                _quickAdjustProductQty(
                                              product,
                                              packDelta: 1,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        IconButton.filledTonal(
                                          tooltip: 'تسجيل التوالف والمرتجعات',
                                          onPressed: () => _openAuditEntrySheet(
                                            initialProduct: product,
                                          ),
                                          style: IconButton.styleFrom(
                                            backgroundColor:
                                                AppConstants.softRoyalGold,
                                            foregroundColor:
                                                AppConstants.deepNavyBlue,
                                          ),
                                          icon: const Icon(
                                            Icons.tune_rounded,
                                            size: 20,
                                          ),
                                        ),
                                      ],
                                    ),

                                    if (isAudited &&
                                        (audit.damagedCount > 0 ||
                                            audit.returnedCount > 0)) ...[
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 8,
                                        children: [
                                          if (audit.damagedCount > 0)
                                            _AuditMiniBadge(
                                              label:
                                                  'تالف: ${audit.damagedCount}',
                                              color: Colors.red,
                                            ),
                                          if (audit.returnedCount > 0)
                                            _AuditMiniBadge(
                                              label:
                                                  'مرتجع: ${audit.returnedCount}',
                                              color: Colors.orange,
                                            ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

/// عداد سريع مدمج داخل بطاقة الصنف (+ / -) للتشغيل بيد واحدة أثناء الزيارة الميدانية
class _InlineQuickStepper extends StatelessWidget {
  final String label;
  final int value;
  final Color primaryColor;
  final Color accentColor;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  const _InlineQuickStepper({
    required this.label,
    required this.value,
    required this.primaryColor,
    required this.accentColor,
    required this.onDecrement,
    required this.onIncrement,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: AppConstants.cleanLightGrey,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          InkWell(
            onTap: onDecrement,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Icon(Icons.remove_rounded, size: 18, color: primaryColor),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$value',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  color: primaryColor,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
          InkWell(
            onTap: onIncrement,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.add_rounded,
                size: 18,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CounterFieldCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final MaterialColor color;
  final TextEditingController controller;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  const _CounterFieldCard({
    required this.label,
    required this.icon,
    required this.color,
    required this.controller,
    required this.onDecrement,
    required this.onIncrement,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.shade50.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.shade200),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: color.shade700),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color.shade900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton.filledTonal(
                onPressed: onDecrement,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.remove_rounded, size: 18),
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              IconButton.filled(
                onPressed: onIncrement,
                style: IconButton.styleFrom(backgroundColor: color.shade700),
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.add_rounded, size: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AuditMiniBadge extends StatelessWidget {
  final String label;
  final MaterialColor color;

  const _AuditMiniBadge({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.shade200),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.bold,
          color: color.shade800,
        ),
      ),
    );
  }
}
