import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/offline_sync_service.dart';

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
  final String productName;
  final double unitPrice;
  int quantity;

  OrderLineItem({
    required this.productName,
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

  static const List<String> _availableCustomers = [
    'هائل سعيد أنعم وشركاه - المركز التجاري',
    'سوبرماركت الجند الحديث - فرع حدة',
    'مؤسسة الخير لتجارة الجملة - الحصبة',
    'بقالة وتموينات السعيدة - شارع تعز',
    'هايبر شملان ستار - فرع الستين',
    'مجموعة مطاعم وفنادق التاج الملكي',
  ];

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
    final now = DateTime.now();
    return [
      FieldOrderModel(
        id: 'ORD-101',
        orderNumber: 'INV-202681',
        customerName: 'هائل سعيد أنعم وشركاه - المركز التجاري',
        branchName: 'الفرع الرئيسي - صنعاء',
        status: OrderStatus.pending,
        itemsCount: 18,
        totalAmount: 182400.0,
        createdAt: now.subtract(const Duration(minutes: 35)),
        summaryItems: const [
          'عصير جلب مانجو طبيعي 1 لتر (10 كرتون)',
          'جبنة جلب كريمية 500 جم (8 كرتون)',
        ],
      ),
      FieldOrderModel(
        id: 'ORD-102',
        orderNumber: 'INV-202680',
        customerName: 'سوبرماركت الجند الحديث - فرع حدة',
        branchName: 'الفرع الرئيسي - صنعاء',
        status: OrderStatus.completed,
        itemsCount: 25,
        totalAmount: 317500.0,
        createdAt: now.subtract(const Duration(hours: 3)),
        summaryItems: const [
          'زيت دوار الشمس جلب 1.5 لتر (15 كرتون)',
          'تونة جلب لحم خفيف 185 جم (10 كرتون)',
        ],
      ),
      FieldOrderModel(
        id: 'ORD-103',
        orderNumber: 'INV-202679',
        customerName: 'مؤسسة الخير لتجارة الجملة - الحصبة',
        branchName: 'فرع الحديدة التجاري',
        status: OrderStatus.pending,
        itemsCount: 12,
        totalAmount: 81600.0,
        createdAt: now.subtract(const Duration(hours: 5)),
        summaryItems: const [
          'حليب جلب كامل الدسم 1 لتر (12 كرتون)',
        ],
      ),
      FieldOrderModel(
        id: 'ORD-104',
        orderNumber: 'INV-202678',
        customerName: 'بقالة وتموينات السعيدة - شارع تعز',
        branchName: 'فرع تعز الميداني',
        status: OrderStatus.completed,
        itemsCount: 9,
        totalAmount: 48600.0,
        createdAt: now.subtract(const Duration(days: 1)),
        summaryItems: const [
          'بسكويت جلب بالزبدة الفاخرة (9 كرتون)',
        ],
      ),
      FieldOrderModel(
        id: 'ORD-105',
        orderNumber: 'INV-202677',
        customerName: 'هايبر شملان ستار - فرع الستين',
        branchName: 'فرع عدن - المعلا',
        status: OrderStatus.cancelled,
        itemsCount: 6,
        totalAmount: 34800.0,
        createdAt: now.subtract(const Duration(days: 1, hours: 4)),
        summaryItems: const [
          'تم إلغاء الطلب بناءً على طلب العميل لتعديل الكميات',
        ],
      ),
    ];
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

  /// فتح نافذة إضافة طلب ميداني جديد (Create Order Sheet)
  Future<void> _openCreateOrderSheet() async {
    String selectedCustomer = _availableCustomers.first;
    final List<OrderLineItem> catalogLines = [
      OrderLineItem(
        productName: 'عصير جلب مانجو طبيعي 1 لتر',
        unitPrice: 7200.0,
        quantity: 2,
      ),
      OrderLineItem(
        productName: 'حليب جلب كامل الدسم 1 لتر',
        unitPrice: 6800.0,
        quantity: 1,
      ),
      OrderLineItem(
        productName: 'جبنة جلب كريمية 500 جم',
        unitPrice: 13500.0,
        quantity: 0,
      ),
      OrderLineItem(
        productName: 'تونة جلب لحم خفيف 185 جم',
        unitPrice: 14500.0,
        quantity: 0,
      ),
      OrderLineItem(
        productName: 'زيت دوار الشمس جلب 1.5 لتر',
        unitPrice: 11500.0,
        quantity: 0,
      ),
      OrderLineItem(
        productName: 'زيت زيتون جلب بكر ممتاز 500 مل',
        unitPrice: 18500.0,
        quantity: 0,
      ),
      OrderLineItem(
        productName: 'فول مدمس جلب الخلطة السرية 400 جم',
        unitPrice: 5800.0,
        quantity: 0,
      ),
      OrderLineItem(
        productName: 'مكسرات جلب المشكلة المحمصة 250 جم',
        unitPrice: 16000.0,
        quantity: 0,
      ),
    ];

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
                  .map((l) => '${l.productName} (${l.quantity} كرتون)')
                  .toList();

              final newOrder = FieldOrderModel(
                id: 'ORD-${DateTime.now().millisecondsSinceEpoch}',
                orderNumber: newOrderNum,
                customerName: selectedCustomer,
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
              final syncedOnline = await _offlineSync.enqueueOrSyncOperation(
                table: AppConstants.tableOrders,
                action: 'insert',
                payload: {
                  'order_number': newOrder.orderNumber,
                  'customer_name': newOrder.customerName,
                  'status': newOrder.status.dbValue,
                  'items_count': newOrder.itemsCount,
                  'total_amount': newOrder.totalAmount,
                  if (widget.currentUserId != null)
                    'created_by': widget.currentUserId,
                  'created_at': newOrder.createdAt.toIso8601String(),
                },
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
                              ? 'تم اعتماد ومزامنة الفاتورة ($newOrderNum) بإجمالي ${AppConstants.formatCurrency(grandTotal, branch: widget.currentBranchId)}'
                              : 'تم اعتماد الفاتورة ($newOrderNum) محلياً وحفظها في طابور المزامنة (${AppConstants.formatCurrency(grandTotal, branch: widget.currentBranchId)})',
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
                                'إنشاء طلب توريد / فاتورة جديدة',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                'يعمل محلياً وفورياً مع حساب الإجمالي بالعملة المعتمدة (ر.ي)',
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
                    DropdownButtonFormField<String>(
                      value: selectedCustomer,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'العميل / نقطة البيع',
                        prefixIcon: const Icon(Icons.storefront_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      items: _availableCustomers.map((cust) {
                        return DropdownMenuItem<String>(
                          value: cust,
                          child: Text(cust, overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setSheetState(() => selectedCustomer = val);
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'تحديد الأصناف والكميات (بالكرتون):',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
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
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          line.productName,
                                          style: TextStyle(
                                            fontWeight: isSelected
                                                ? FontWeight.bold
                                                : FontWeight.w500,
                                            fontSize: 13.5,
                                          ),
                                        ),
                                        Text(
                                          '${AppConstants.formatCurrency(line.unitPrice, branch: widget.currentBranchId)} / كرتون',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton.filledTonal(
                                    onPressed: line.quantity > 0
                                        ? () => setSheetState(
                                              () => line.quantity--,
                                            )
                                        : null,
                                    constraints: const BoxConstraints(
                                      minWidth: 34,
                                      minHeight: 34,
                                    ),
                                    padding: EdgeInsets.zero,
                                    icon: const Icon(
                                      Icons.remove_rounded,
                                      size: 18,
                                    ),
                                  ),
                                  SizedBox(
                                    width: 38,
                                    child: Text(
                                      '${line.quantity}',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                  IconButton.filled(
                                    onPressed: () => setSheetState(
                                      () => line.quantity++,
                                    ),
                                    style: IconButton.styleFrom(
                                      backgroundColor:
                                          AppConstants.deepNavyBlue,
                                    ),
                                    constraints: const BoxConstraints(
                                      minWidth: 34,
                                      minHeight: 34,
                                    ),
                                    padding: EdgeInsets.zero,
                                    icon: const Icon(
                                      Icons.add_rounded,
                                      size: 18,
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
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'إجمالي الكميات: $totalCartons كرتون',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: AppConstants.deepNavyBlue,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const Text(
                                'الإجمالي النهائي للفاتورة:',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            AppConstants.formatCurrency(
                              grandTotal,
                              branch: widget.currentBranchId,
                            ),
                            style: const TextStyle(
                              fontSize: 20,
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
                          title: 'إجمالي المبيعات',
                          value: AppConstants.formatCurrency(
                            totalRevenue,
                            branch: widget.currentBranchId,
                          ),
                          color: Colors.indigo,
                          icon: Icons.payments_outlined,
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
                                              'إجمالي الفاتورة',
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                color: colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                            ),
                                            Text(
                                              AppConstants.formatCurrency(
                                                order.totalAmount,
                                                branch: order.branchName,
                                              ),
                                              style: const TextStyle(
                                                fontSize: 18,
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
