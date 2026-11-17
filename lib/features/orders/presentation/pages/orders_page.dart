import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/al_rabie_catalog.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/offline_sync_service.dart';
import '../../../../core/widgets/quantity_calculator_sheet.dart';

/// حالات الطلب الميداني
enum OrderStatus {
  pending,
  completed,
  cancelled,
}

extension OrderStatusExtension on OrderStatus {
  String get arabicLabel {
    switch (this) {
      case OrderStatus.pending:
        return 'قيد الانتظار';
      case OrderStatus.completed:
        return 'مكتمل';
      case OrderStatus.cancelled:
        return 'ملغى';
    }
  }

  String get dbValue {
    switch (this) {
      case OrderStatus.pending:
        return 'pending';
      case OrderStatus.completed:
        return 'completed';
      case OrderStatus.cancelled:
        return 'cancelled';
    }
  }

  MaterialColor get badgeColor {
    switch (this) {
      case OrderStatus.pending:
        return Colors.amber;
      case OrderStatus.completed:
        return Colors.green;
      case OrderStatus.cancelled:
        return Colors.red;
    }
  }

  IconData get icon {
    switch (this) {
      case OrderStatus.pending:
        return Icons.hourglass_top_rounded;
      case OrderStatus.completed:
        return Icons.check_circle_rounded;
      case OrderStatus.cancelled:
        return Icons.cancel_rounded;
    }
  }

  static OrderStatus fromString(String? raw) {
    final normalized = (raw ?? '').trim().toLowerCase();
    if (normalized == 'completed' || normalized == 'مكتمل') {
      return OrderStatus.completed;
    }
    if (normalized == 'cancelled' ||
        normalized == 'canceled' ||
        normalized == 'ملغى') {
      return OrderStatus.cancelled;
    }
    return OrderStatus.pending;
  }
}

/// عنصر سطر داخل الفاتورة / الطلب
class OrderLineItem {
  final String code;
  final String productName;
  final String category;
  final String imageAsset;
  final double unitPrice;
  int quantity;

  OrderLineItem({
    required this.code,
    required this.productName,
    required this.category,
    required this.imageAsset,
    required this.unitPrice,
    this.quantity = 0,
  });

  double get lineTotal => unitPrice * quantity;
}

/// نموذج الطلب الميداني المرتبط بجدول `orders`
class FieldOrderModel {
  final String id;
  final String orderNumber;
  final String customerName;
  final String branchName;
  final OrderStatus status;
  final int itemsCount;
  final double totalAmount;
  final DateTime createdAt;
  final List<String> summaryItems;

  const FieldOrderModel({
    required this.id,
    required this.orderNumber,
    required this.customerName,
    required this.branchName,
    required this.status,
    required this.itemsCount,
    required this.totalAmount,
    required this.createdAt,
    this.summaryItems = const [],
  });

  factory FieldOrderModel.fromJson(Map<String, dynamic> json, int index) {
    final rawSummary = json['summary_items'];
    final List<String> parsedSummary = rawSummary is List
        ? rawSummary.map((e) => e.toString()).toList()
        : const <String>[];

    return FieldOrderModel(
      id: json['id']?.toString() ?? 'ORD-${1000 + index}',
      orderNumber: (json['order_number'] ??
              json['code'] ??
              'INV-${202600 + index + 1}')
          .toString(),
      customerName:
          (json['customer_name'] ?? json['customer'] ?? 'عميل جلب الميداني')
              .toString(),
      branchName: (json['branch_name'] ?? json['branch'] ?? 'الفرع الرئيسي - صنعاء')
          .toString(),
      status: OrderStatusExtension.fromString(json['status']?.toString()),
      itemsCount: _parseInt(json['items_count'], 4),
      totalAmount: _parseDouble(json['total_amount'] ?? json['total'], 125000.0),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      summaryItems: parsedSummary,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_number': orderNumber,
      'customer_name': customerName,
      'branch_name': branchName,
      'status': status.dbValue,
      'items_count': itemsCount,
      'total_amount': totalAmount,
      'created_at': createdAt.toIso8601String(),
      'summary_items': summaryItems,
    };
  }

  static int _parseInt(dynamic val, int fallback) {
    if (val is int) return val;
    if (val is num) return val.toInt();
    if (val is String) return int.tryParse(val) ?? fallback;
    return fallback;
  }

  static double _parseDouble(dynamic val, double fallback) {
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? fallback;
    return fallback;
  }
}

/// شاشة إدارة الطلبات والمبيعات الميدانية المرتبطة بجدول `orders`
/// تدعم العمل بدون إنترنت (Offline-First) والعملة الديناميكية (ر.ي).
class OrdersPage extends StatefulWidget {
  final String? currentUserId;
  final String? currentBranchId;

  const OrdersPage({
    super.key,
    this.currentUserId,
    this.currentBranchId,
  });

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  final OfflineSyncService _offlineSync = OfflineSyncService.instance;

  List<FieldOrderModel> _orders = [];
  OrderStatus? _selectedFilter;
  bool _isLoading = false;

  static const List<String> _availableCustomers = <String>[];

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);

    // 1. قراءة الطلبات المخزنة محلياً (Offline Cache)
    final cachedOrdersJson = _offlineSync.getCachedOrders();
    if (cachedOrdersJson.isNotEmpty) {
      _orders = List<FieldOrderModel>.generate(
        cachedOrdersJson.length,
        (i) => FieldOrderModel.fromJson(cachedOrdersJson[i], i),
      );
    } else {
      _orders = _defaultFieldOrders();
      await _persistOrdersLocally();
    }

    // 2. محاولة التحديث من Supabase إذا كان متصلاً
    if (AppConstants.isSupabaseConfigured) {
      try {
        final rows = await Supabase.instance.client
            .from(AppConstants.tableOrders)
            .select()
            .order('created_at', ascending: false)
            .limit(30);

        if (rows.isNotEmpty) {
          final loaded = <FieldOrderModel>[];
          for (int i = 0; i < rows.length; i++) {
            loaded.add(FieldOrderModel.fromJson(rows[i], i));
          }
          if (loaded.isNotEmpty) {
            _orders = loaded;
            await _persistOrdersLocally();
          }
        }
      } catch (error) {
        debugPrint('Orders offline cache active: $error');
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _persistOrdersLocally() async {
    await _offlineSync.cacheOrders(_orders.map((o) => o.toJson()).toList());
  }

  List<FieldOrderModel> _defaultFieldOrders() {
    return const <FieldOrderModel>[];
  }

  List<FieldOrderModel> get _filteredOrders {
    if (_selectedFilter == null) return _orders;
    return _orders.where((o) => o.status == _selectedFilter).toList();
  }

  /// تحديث حالة الطلب وحفظها محلياً وفي طابور المزامنة
  Future<void> _updateOrderStatus(
    FieldOrderModel order,
    OrderStatus newStatus,
  ) async {
    setState(() {
      final index = _orders.indexWhere((o) => o.id == order.id);
      if (index != -1) {
        _orders[index] = FieldOrderModel(
          id: order.id,
          orderNumber: order.orderNumber,
          customerName: order.customerName,
          branchName: order.branchName,
          status: newStatus,
          itemsCount: order.itemsCount,
          totalAmount: order.totalAmount,
          createdAt: order.createdAt,
          summaryItems: order.summaryItems,
        );
      }
    });

    await _persistOrdersLocally();

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
          content: Directionality(
            textDirection: TextDirection.rtl,
            child: Text(
              'تم تحديث حالة الفاتورة (${order.orderNumber}) إلى: ${newStatus.arabicLabel}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      );
  }

  /// فتح نافذة إضافة طلب ميداني جديد (Create Order Sheet) مع حقل عميل مرن/اختياري وحاسبة كميات رقمية
  Future<void> _openCreateOrderSheet() async {
    final TextEditingController customerController = TextEditingController();
    final List<OrderLineItem> catalogLines = List<OrderLineItem>.generate(
      AlRabieCatalog.items.length,
      (idx) {
        final p = AlRabieCatalog.items[idx];
        return OrderLineItem(
          code: p.code,
          productName: p.name,
          category: p.category,
          imageAsset: p.imageAsset,
          unitPrice: p.cartonPrice,
          quantity: 0,
        );
      },
    );

    bool isSubmitting = false;

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

            final int totalCartons = catalogLines.fold<int>(
              0,
              (sum, item) => sum + item.quantity,
            );
            final double grandTotal = catalogLines.fold<double>(
              0.0,
              (sum, item) => sum + item.lineTotal,
            );

            Future<void> submitOrder() async {
              if (totalCartons <= 0) {
                ScaffoldMessenger.of(this.context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    const SnackBar(
                      behavior: SnackBarBehavior.floating,
                      content: Directionality(
                        textDirection: TextDirection.rtl,
                        child: Text('يرجى تحديد كمية صنف واحد على الأقل.'),
                      ),
                    ),
                  );
                return;
              }

              setSheetState(() => isSubmitting = true);

              final newOrderNum = 'INV-${202682 + _orders.length}';
              final selectedSummaries = catalogLines
                  .where((l) => l.quantity > 0)
                  .map((l) => '[${l.code}] ${l.productName} (${l.quantity} كرتون)')
                  .toList();
              final effectiveCustomer = customerController.text.trim().isEmpty
                  ? 'عميل عام (بدون تحديد)'
                  : customerController.text.trim();

              final newOrder = FieldOrderModel(
                id: 'ORD-${DateTime.now().millisecondsSinceEpoch}',
                orderNumber: newOrderNum,
                customerName: effectiveCustomer,
                branchName: widget.currentBranchId ?? 'الفرع الرئيسي - صنعاء',
                status: OrderStatus.pending,
                itemsCount: totalCartons,
                totalAmount: grandTotal,
                createdAt: DateTime.now(),
                summaryItems: selectedSummaries,
              );

              setState(() {
                _orders.insert(0, newOrder);
              });

              await _persistOrdersLocally();
              bool syncedOnline = false;
              for (final line in catalogLines.where((l) => l.quantity > 0)) {
                await _offlineSync.appendReportRecord(<String, dynamic>{
                  'record_type': 'order',
                  'reference_no': newOrder.orderNumber,
                  'rep_id': widget.currentUserId ?? '',
                  'rep_name': 'إدارة المبيعات / المشرف',
                  'rep_username': 'admin_master',
                  'branch_name': newOrder.branchName,
                  'customer_name': newOrder.customerName,
                  'product_id': AlRabieCatalog.databaseIdForProduct(line.code),
                  'sku': line.code,
                  'product_name': line.productName,
                  'category': line.category,
                  'image_asset': line.imageAsset,
                  'carton_qty': line.quantity,
                  'pack_qty': 0,
                  'created_at': newOrder.createdAt.toIso8601String(),
                });

                syncedOnline = await _offlineSync.enqueueOrSyncOperation(
                  table: AppConstants.tableOrders,
                  action: 'insert',
                  payload: {
                    'product_id': line.code,
                    'order_qty': line.quantity,
                    'status': newOrder.status.dbValue,
                    if (widget.currentUserId != null)
                      'rep_id': widget.currentUserId,
                    'order_date': newOrder.createdAt.toIso8601String(),
                  },
                );
              }

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
                              ? 'تم اعتماد ومزامنة الطلب ($newOrderNum) بنجاح ($totalCartons كرتون)'
                              : 'تم اعتماد الطلب ($newOrderNum) محلياً وحفظه في طابور المزامنة ($totalCartons كرتون)',
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
                    const SizedBox(height: 14),
                    const Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppConstants.softRoyalGold,
                          foregroundColor: AppConstants.deepNavyBlue,
                          child: Icon(Icons.add_shopping_cart_rounded),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                               Text(
                                'إنشاء طلب توريد أصناف الربيع',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                'يعرض اسم الصنف ورقم الصنف الرسمي (SKU) وصورة الصنف مباشرة',
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
                    const SizedBox(height: 16),
                    FlexibleCustomerField(
                      controller: customerController,
                      suggestedCustomers: _availableCustomers,
                      labelText: 'اسم العميل / نقطة البيع (اختياري)',
                      hintText:
                          'اكتب اسم العميل يدوياً أو اختر من القائمة (اختياري)...',
                      onChanged: (_) => setSheetState(() {}),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'اضغط على خانة الكمية لفتح الحاسبة الرقمية وإدخال الكراتين:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Flexible(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 280),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: catalogLines.length,
                          separatorBuilder: (_, __) =>
                               const Divider(height: 1),
                          itemBuilder: (context, idx) {
                            final line = catalogLines[idx];
                            final isSelected = line.quantity > 0;
                            return Container(
                              color: isSelected
                                  ? AppConstants.softRoyalGold.withOpacity(0.6)
                                  : null,
                              padding: const EdgeInsets.symmetric(
                                vertical: 8,
                                horizontal: 6,
                              ),
                              child: Row(
                                children: [
                                  AlRabieProductThumbnail(
                                    imageAsset: line.imageAsset,
                                    category: line.category,
                                    size: 44,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    flex: 6,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppConstants.deepNavyBlue,
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            line.code,
                                            textDirection: TextDirection.ltr,
                                            style: const TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.bold,
                                              color: AppConstants.royalGold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          line.productName,
                                          style: TextStyle(
                                            fontWeight: isSelected
                                                ? FontWeight.bold
                                                : FontWeight.w600,
                                            fontSize: 13.5,
                                            color: AppConstants.deepNavyBlue,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    flex: 5,
                                    child: InteractiveQuantityCalculatorBox(
                                      label: 'كرتون',
                                      value: line.quantity,
                                      productName: line.productName,
                                      productCode: line.code,
                                      imageAsset: line.imageAsset,
                                      category: line.category,
                                      onQuantitySaved: (val) {
                                        setSheetState(() {
                                          line.quantity = val;
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppConstants.softRoyalGold,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppConstants.royalGold),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'إجمالي الكميات المطلوبة:',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppConstants.deepNavyBlue,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '$totalCartons كرتون',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: AppConstants.deepNavyBlue,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 54,
                      child: FilledButton.icon(
                        onPressed: isSubmitting ? null : submitOrder,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppConstants.deepNavyBlue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.verified_rounded,
                                color: AppConstants.royalGold,
                              ),
                        label: const Text(
                          'اعتماد وإصدار الفاتورة الآن',
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
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    final int pendingCount =
        _orders.where((o) => o.status == OrderStatus.pending).length;
    final int completedCount =
        _orders.where((o) => o.status == OrderStatus.completed).length;
    final double totalRevenue = _orders
        .where((o) => o.status != OrderStatus.cancelled)
        .fold<double>(0.0, (sum, o) => sum + o.totalAmount);

    final displayedOrders = _filteredOrders;

    return Scaffold(
      backgroundColor: AppConstants.cleanLightGrey,
      appBar: AppBar(
        title: const Text(
          'إدارة الطلبات والمبيعات الميدانية',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        backgroundColor: AppConstants.deepNavyBlue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'تحديث الطلبات',
            onPressed: _loadOrders,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'orders_fab',
        onPressed: _openCreateOrderSheet,
        backgroundColor: AppConstants.royalGold,
        foregroundColor: AppConstants.deepNavyBlue,
        icon: const Icon(Icons.add_shopping_cart_rounded),
        label: const Text(
          'طلب جديد',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ملخص إحصائي للطلبات بالعملة الديناميكية (ر.ي)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: _OrderMetricTile(
                          title: 'إجمالي الطلبات',
                          value: '${_orders.length} طلب',
                          color: Colors.indigo,
                          icon: Icons.inventory_2_outlined,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _OrderMetricTile(
                          title: 'قيد الانتظار',
                          value: '$pendingCount طلب',
                          color: Colors.amber,
                          icon: Icons.hourglass_top_rounded,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _OrderMetricTile(
                          title: 'مكتمل',
                          value: '$completedCount طلب',
                          color: Colors.green,
                          icon: Icons.task_alt_rounded,
                        ),
                      ),
                    ],
                  ),
                ),

                // شريط فلترة حالات الطلب
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      ChoiceChip(
                        label: Text('الكل (${_orders.length})'),
                        selected: _selectedFilter == null,
                        selectedColor: AppConstants.softRoyalGold,
                        onSelected: (_) =>
                            setState(() => _selectedFilter = null),
                      ),
                      const SizedBox(width: 8),
                      ...OrderStatus.values.map((status) {
                        final isSelected = _selectedFilter == status;
                        return Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: ChoiceChip(
                            avatar: Icon(
                              status.icon,
                              size: 16,
                              color: status.badgeColor.shade700,
                            ),
                            label: Text(status.arabicLabel),
                            selected: isSelected,
                            selectedColor: status.badgeColor.shade100,
                            onSelected: (_) {
                              setState(() => _selectedFilter = status);
                            },
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // قائمة الطلبات
                Expanded(
                  child: displayedOrders.isEmpty
                      ? const Center(
                          child: Text('لا توجد طلبات ضمن هذا التصنيف حالياً.'),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                          itemCount: displayedOrders.length,
                          itemBuilder: (context, index) {
                            final order = displayedOrders[index];
                            final badgeColor = order.status.badgeColor;

                            return Card(
                              elevation: 0,
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                  color: badgeColor.shade200,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppConstants.deepNavyBlue,
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            order.orderNumber,
                                            textDirection: TextDirection.ltr,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 12,
                                              color: AppConstants.royalGold,
                                            ),
                                          ),
                                        ),
                                        const Spacer(),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: badgeColor.shade50,
                                            borderRadius:
                                                BorderRadius.circular(14),
                                            border: Border.all(
                                              color: badgeColor.shade300,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                order.status.icon,
                                                size: 15,
                                                color: badgeColor.shade800,
                                              ),
                                              const SizedBox(width: 5),
                                              Text(
                                                order.status.arabicLabel,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: badgeColor.shade900,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      order.customerName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
                                        color: AppConstants.deepNavyBlue,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.location_on_outlined,
                                          size: 15,
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          order.branchName,
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Icon(
                                          Icons.inventory_2_outlined,
                                          size: 15,
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${order.itemsCount} كرتون',
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (order.summaryItems.isNotEmpty) ...[
                                      const SizedBox(height: 10),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: AppConstants.cleanLightGrey,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: order.summaryItems
                                              .map(
                                                (line) => Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                    bottom: 2,
                                                  ),
                                                  child: Text(
                                                    '• $line',
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                              )
                                              .toList(),
                                        ),
                                      ),
                                    ],
                                    const Divider(height: 22),
                                    Row(
                                      children: [
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'إجمالي الكميات المطلوبة',
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                color: colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                            ),
                                            Text(
                                              '${order.itemsCount} كرتون',
                                              style: const TextStyle(
                                                fontSize: 17,
                                                fontWeight: FontWeight.w900,
                                                color:
                                                    AppConstants.deepNavyBlue,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const Spacer(),
                                        if (order.status == OrderStatus.pending)
                                          FilledButton.tonalIcon(
                                            onPressed: () => _updateOrderStatus(
                                              order,
                                              OrderStatus.completed,
                                            ),
                                            style: FilledButton.styleFrom(
                                              backgroundColor:
                                                  AppConstants.softRoyalGold,
                                              foregroundColor:
                                                  AppConstants.deepNavyBlue,
                                            ),
                                            icon: const Icon(
                                              Icons.check_circle_outline,
                                              size: 18,
                                            ),
                                            label: const Text(
                                              'تأكيد التسليم',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
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

class _OrderMetricTile extends StatelessWidget {
  final String title;
  final String value;
  final MaterialColor color;
  final IconData icon;

  const _OrderMetricTile({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppConstants.deepNavyBlue),
          const SizedBox(height: 6),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w900,
              color: AppConstants.deepNavyBlue,
            ),
          ),
        ],
      ),
    );
  }
}
