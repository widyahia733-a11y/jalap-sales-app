import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  static const String _keyProductsCache = 'jalap_cache_products_v1';
  static const String _keyAuditsCache = 'jalap_cache_inventory_audits_v1';
  static const String _keyOrdersCache = 'jalap_cache_orders_v1';
  static const String _keyCustomersCache = 'jalap_cache_customers_v1';
  static const String _keySyncQueue = 'jalap_sync_queue_v1';

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
      final queue = getPendingQueue();
      pendingSyncCountNotifier.value = queue.length;
    } catch (error) {
      debugPrint('SharedPreferences init warning: $error');
    }

    await checkConnectivityAndFlush();
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
    if (AppConstants.isSupabaseConfigured && isOnlineNotifier.value) {
      try {
        final client = Supabase.instance.client.from(table);
        if (action == 'upsert') {
          await client.upsert(payload);
        } else {
          await client.insert(payload);
        }
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
      action: action,
      payload: payload,
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
        final client = Supabase.instance.client.from(op.table);
        if (op.action == 'upsert') {
          await client.upsert(op.payload);
        } else {
          await client.insert(op.payload);
        }
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

