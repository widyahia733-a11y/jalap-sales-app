import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/al_rabie_catalog.dart';
import '../constants/app_constants.dart';

/// عنصر عملية ميدانية محفوظة في طابور المزامنة (Sync Queue) عند العمل بدون إنترنت
class SyncQueueOperation {
  final String id;
  final String table;
  final String action; // 'insert', 'upsert', 'update'
  final Map<String, dynamic> payload;
  final DateTime createdAt;

  const SyncQueueOperation({
    required this.id,
    required this.table,
    required this.action,
    required this.payload,
    required this.createdAt,
  });

  factory SyncQueueOperation.fromJson(Map<String, dynamic> json) {
    return SyncQueueOperation(
      id: json['id']?.toString() ?? '',
      table: json['table']?.toString() ?? '',
      action: json['action']?.toString() ?? 'insert',
      payload: json['payload'] is Map
          ? Map<String, dynamic>.from(json['payload'] as Map)
          : <String, dynamic>{},
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'table': table,
      'action': action,
      'payload': payload,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

/// محرك التخزين المحلي والمزامنة الذكية (Offline-First Architecture & Sync Queue)
/// يحفظ بيانات الأصناف الـ 27، والعملاء، والطلبات، وسجلات الجرد محلياً على الجهاز
/// ويحتفظ بكافة العمليات الميدانية في طابور المزامنة لرفعها فور توفر اتصال بـ Supabase.
class OfflineSyncService {
  OfflineSyncService._();

  static final OfflineSyncService instance = OfflineSyncService._();

  static const String _keyProductsCache = 'jalap_cache_products_alrabie_v3_fixed';
  static const String _keyAuditsCache = 'jalap_cache_inventory_audits_alrabie_v3_fixed';
  static const String _keyOrdersCache = 'jalap_cache_orders_clean_v12';
  static const String _keyCustomersCache = 'jalap_cache_customers_clean_v12';
  static const String _keyReportsCache = 'jalap_cache_reports_v13';
  static const String _keySyncQueue = 'jalap_sync_queue_v13';
  static const String _keyCatalogSyncedToSupabase = 'jalap_alrabie_supabase_synced_v3';

  static const List<String> _legacyCacheKeysToPurge = [
    'jalap_cache_products_v1',
    'jalap_cache_products_alrabie_v2',
    'jalap_cache_inventory_audits_v1',
    'jalap_cache_inventory_audits_alrabie_v2',
    'jalap_cache_orders_v1',
    'jalap_cache_orders_alrabie_v2',
    'jalap_cache_orders_alrabie_v3_fixed',
    'jalap_cache_customers_v1',
    'jalap_sync_queue_v1',
  ];

  SharedPreferences? _prefs;

  /// مؤشر تفاعلي لحالة الاتصال المباشر أو العمل محلياً (Offline)
  final ValueNotifier<bool> isOnlineNotifier = ValueNotifier<bool>(false);

  /// مؤشر تفاعلي لعدد العمليات المنتظرة في طابور المزامنة (Sync Queue)
  final ValueNotifier<int> pendingSyncCountNotifier = ValueNotifier<int>(0);

  bool get isOnline => isOnlineNotifier.value;
  int get pendingSyncCount => pendingSyncCountNotifier.value;

  /// تهيئة التخزين المحلي والتحقق من حالة الشبكة وطابور المزامنة عند بدء التشغيل
  Future<void> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      for (final legacyKey in _legacyCacheKeysToPurge) {
        if (_prefs!.containsKey(legacyKey)) {
          await _prefs!.remove(legacyKey);
        }
      }
      // تخزين الكتالوج الرسمي الكامل (62 صنفاً) محلياً بشكل مضمون منذ اللحظة الأولى
      await cacheProducts(
        AlRabieCatalog.items.map((p) => p.toJson()).toList(),
      );
      final queue = getPendingQueue();
      pendingSyncCountNotifier.value = queue.length;
    } catch (error) {
      debugPrint('SharedPreferences init warning: $error');
    }

    await checkConnectivityAndFlush();
  }

  /// مزامنة كتالوج الربيع الرسمي (62 صنفاً) إلى جدول `products` في Supabase وتنظيف أي أصناف تجريبية قديمة
  Future<void> syncOfficialCatalogToSupabase() async {
    if (!AppConstants.isSupabaseConfigured) return;
    try {
      final supabase = Supabase.instance.client;
      final List<Map<String, dynamic>> upsertRows = <Map<String, dynamic>>[];
      for (int i = 0; i < AlRabieCatalog.items.length; i++) {
        final item = AlRabieCatalog.items[i];
        upsertRows.add(<String, dynamic>{
          'id': i + 1,
          'item_code': item.code,
          'product_name': item.name,
          'image_url': item.imageAsset,
        });
      }
      await supabase.from(AppConstants.tableProducts).upsert(upsertRows);
      await _prefs?.setBool(_keyCatalogSyncedToSupabase, true);
    } catch (e) {
      debugPrint('Background catalog sync info: $e');
    }
  }

  /// فحص الاتصال الفعلي بـ Supabase ومحاولة تفريغ طابور المزامنة إن وجد
  Future<bool> checkConnectivityAndFlush() async {
    if (!AppConstants.isSupabaseConfigured) {
      isOnlineNotifier.value = false;
      return false;
    }

    try {
      await Supabase.instance.client
          .from(AppConstants.tableBranches)
          .select('id')
          .limit(1);
      isOnlineNotifier.value = true;
      final alreadySynced = _prefs?.getBool(_keyCatalogSyncedToSupabase) ?? false;
      if (!alreadySynced) {
        await syncOfficialCatalogToSupabase();
      }
      await flushSyncQueue();
      return true;
    } catch (_) {
      isOnlineNotifier.value = false;
      return false;
    }
  }

  /// تبديل وضع العمل المحلي يدوياً (للتجربة الميدانية السريعة لوضع Offline)
  void setOfflineMode(bool offline) {
    isOnlineNotifier.value = !offline;
  }

  // ===========================================================================
  // إدارة التخزين المحلي (Local Cache) للأصناف الـ 27، الجرد، الطلبات، والعملاء
  // ===========================================================================

  Future<void> cacheProducts(List<Map<String, dynamic>> products) async {
    await _saveJsonList(_keyProductsCache, products);
  }

  List<Map<String, dynamic>> getCachedProducts() {
    return _readJsonList(_keyProductsCache);
  }

  Future<void> cacheInventoryAudits(
    Map<String, Map<String, dynamic>> auditsByProductId,
  ) async {
    if (_prefs == null) return;
    await _prefs!.setString(_keyAuditsCache, jsonEncode(auditsByProductId));
  }

  Map<String, Map<String, dynamic>> getCachedInventoryAudits() {
    final raw = _prefs?.getString(_keyAuditsCache);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return decoded.map(
          (key, value) => MapEntry(
            key.toString(),
            value is Map
                ? Map<String, dynamic>.from(value)
                : <String, dynamic>{},
          ),
        );
      }
    } catch (e) {
      debugPrint('Read audits cache warning: $e');
    }
    return {};
  }

  Future<void> cacheOrders(List<Map<String, dynamic>> orders) async {
    await _saveJsonList(_keyOrdersCache, orders);
  }

  List<Map<String, dynamic>> getCachedOrders() {
    return _readJsonList(_keyOrdersCache);
  }

  Future<void> cacheCustomers(List<Map<String, dynamic>> customers) async {
    await _saveJsonList(_keyCustomersCache, customers);
  }

  List<Map<String, dynamic>> getCachedCustomers() {
    return _readJsonList(_keyCustomersCache);
  }

  Future<void> appendReportRecord(Map<String, dynamic> record) async {
    final current = getCachedReportRecords();
    current.insert(0, record);
    await _saveJsonList(_keyReportsCache, current);
  }

  List<Map<String, dynamic>> getCachedReportRecords() {
    return _readJsonList(_keyReportsCache);
  }

  bool _isValidUuid(String? value) {
    if (value == null || value.trim().isEmpty) return false;
    final regex = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    return regex.hasMatch(value.trim());
  }

  /// تحويل حمولة البيانات (Payload) لتتوافق 100% مع أعمدة جداول Supabase الفعلية
  Map<String, dynamic> _normalizePayloadForSupabase(
    String table,
    Map<String, dynamic> raw,
  ) {
    if (table == AppConstants.tableInventoryAudits) {
      final rawProd = raw['product_id']?.toString() ??
          raw['sku']?.toString() ??
          '43002001';
      final dbProductId = AlRabieCatalog.databaseIdForProduct(rawProd);
      final stockQty =
          ((raw['stock_qty'] ?? raw['carton_qty'] ?? raw['carton_count'])
                  as num?)
              ?.toInt() ??
          0;
      final repId = (raw['rep_id'] ?? raw['audited_by'])?.toString();
      final auditDate = (raw['audit_date'] ?? raw['audited_at'])?.toString() ??
          DateTime.now().toIso8601String();
      final custId = (raw['customer_id'] is int)
          ? raw['customer_id'] as int
          : int.tryParse(raw['customer_id']?.toString() ?? '');

      return <String, dynamic>{
        if (custId != null) 'customer_id': custId,
        if (_isValidUuid(repId)) 'rep_id': repId,
        'product_id': dbProductId,
        'stock_qty': stockQty,
        'week_number': ((DateTime.now().day - 1) ~/ 7) + 1,
        'audit_date': auditDate,
      };
    }

    if (table == AppConstants.tableOrders) {
      final rawProd = raw['product_id']?.toString() ??
          raw['sku']?.toString() ??
          '43002001';
      final dbProductId = AlRabieCatalog.databaseIdForProduct(rawProd);
      final orderQty =
          ((raw['order_qty'] ?? raw['items_count'] ?? raw['carton_qty'])
                  as num?)
              ?.toInt() ??
          0;
      final repId = (raw['rep_id'] ?? raw['created_by'])?.toString();
      final orderDate = (raw['order_date'] ?? raw['created_at'])?.toString() ??
          DateTime.now().toIso8601String();
      final status = raw['status']?.toString() ?? 'pending';
      final custId = (raw['customer_id'] is int)
          ? raw['customer_id'] as int
          : int.tryParse(raw['customer_id']?.toString() ?? '');

      return <String, dynamic>{
        if (custId != null) 'customer_id': custId,
        if (_isValidUuid(repId)) 'rep_id': repId,
        'product_id': dbProductId,
        'order_qty': orderQty,
        'status': status,
        'order_date': orderDate,
      };
    }

    if (table == AppConstants.tableCustomers) {
      final name =
          (raw['customer_name'] ?? raw['name'] ?? raw['store_name'])?.toString() ??
              'عميل ميداني';
      final repId = raw['assigned_rep_id']?.toString();
      return <String, dynamic>{
        'customer_name': name,
        if (raw['governorate'] != null || raw['region'] != null)
          'governorate': (raw['governorate'] ?? raw['region']).toString(),
        if (_isValidUuid(repId)) 'assigned_rep_id': repId,
      };
    }

    return raw;
  }

  // ===========================================================================
  // إدارة طابور المزامنة (Sync Queue) للعمليات المسجلة بدون إنترنت
  // ===========================================================================

  List<SyncQueueOperation> getPendingQueue() {
    final list = _readJsonList(_keySyncQueue);
    return list.map(SyncQueueOperation.fromJson).toList();
  }

  /// إضافة عملية ميدانية (طلب جديد، جرد صنف، إضافة عميل) إلى طابور المزامنة
  /// ومحاولة رفعها مباشرة إذا كان الاتصال متوفراً
  Future<bool> enqueueOrSyncOperation({
    required String table,
    required Map<String, dynamic> payload,
    String action = 'insert',
  }) async {
    final normalizedPayload = _normalizePayloadForSupabase(table, payload);

    if (AppConstants.isSupabaseConfigured && isOnlineNotifier.value) {
      try {
        final client = Supabase.instance.client.from(table);
        await client.insert(normalizedPayload);
        return true;
      } catch (error) {
        debugPrint('Direct sync failed, queuing offline operation: $error');
        isOnlineNotifier.value = false;
      }
    }

    // حفظ العملية في طابور المزامنة المحلي (Sync Queue)
    final currentQueue = getPendingQueue();
    final newOp = SyncQueueOperation(
      id: 'SYNC-${DateTime.now().millisecondsSinceEpoch}',
      table: table,
      action: 'insert',
      payload: normalizedPayload,
      createdAt: DateTime.now(),
    );
    currentQueue.add(newOp);

    await _saveJsonList(
      _keySyncQueue,
      currentQueue.map((e) => e.toJson()).toList(),
    );
    pendingSyncCountNotifier.value = currentQueue.length;
    return false;
  }

  /// رفع كافة العمليات المخزنة في طابور المزامنة إلى Supabase فور توفر الإنترنت
  Future<int> flushSyncQueue() async {
    final currentQueue = getPendingQueue();
    if (currentQueue.isEmpty) return 0;

    if (!AppConstants.isSupabaseConfigured) {
      return 0;
    }

    final remaining = <SyncQueueOperation>[];
    int syncedCount = 0;

    for (final op in currentQueue) {
      try {
        final normalized = _normalizePayloadForSupabase(op.table, op.payload);
        final client = Supabase.instance.client.from(op.table);
        await client.insert(normalized);
        syncedCount++;
      } catch (e) {
        remaining.add(op);
      }
    }

    await _saveJsonList(
      _keySyncQueue,
      remaining.map((e) => e.toJson()).toList(),
    );
    pendingSyncCountNotifier.value = remaining.length;

    if (remaining.isEmpty) {
      isOnlineNotifier.value = true;
    }
    return syncedCount;
  }

  /// تفريغ ومزامنة الطابور يدوياً (عند الضغط على زر المزامنة اليدوية)
  Future<int> forceManualSync() async {
    if (AppConstants.isSupabaseConfigured) {
      return flushSyncQueue();
    }
    // في بيئة العرض المحلي نقوم بمحاكاة إتمام مزامنة الطابور بنجاح
    final count = pendingSyncCountNotifier.value;
    await _saveJsonList(_keySyncQueue, []);
    pendingSyncCountNotifier.value = 0;
    return count;
  }

  Future<void> _saveJsonList(
    String key,
    List<Map<String, dynamic>> items,
  ) async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setString(key, jsonEncode(items));
  }

  List<Map<String, dynamic>> _readJsonList(String key) {
    final raw = _prefs?.getString(key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } catch (e) {
      debugPrint('JSON cache read warning ($key): $e');
    }
    return [];
  }
}

