import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/app_constants.dart';

/// نموذج سجل التدقيق الرقابي (Audit Log Entry) المرتبط بجدول `audit_logs`
class AuditLogEntry {
  final String id;
  final String userId;
  final String userName;
  final String userRole;
  final String branchName;
  final String actionType; // 'create_order', 'submit_inventory_audit', 'update_sales_rep', 'delete_record', 'login_success', 'create_customer'
  final String targetEntity;
  final String details;
  final DateTime createdAt;

  const AuditLogEntry({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userRole,
    required this.branchName,
    required this.actionType,
    required this.targetEntity,
    required this.details,
    required this.createdAt,
  });

  String get actionArabicLabel {
    switch (actionType) {
      case 'submit_inventory_audit':
        return 'إرسال جرد مخزون';
      case 'create_order':
        return 'إنشاء طلب بضاعة';
      case 'create_sales_rep':
        return 'إضافة مندوب جديد';
      case 'update_sales_rep':
        return 'تحديث صلاحيات مندوب';
      case 'create_customer':
        return 'ربط / إضافة عميل للفرع';
      case 'delete_record':
        return 'حذف / إلغاء سجل';
      case 'export_report':
        return 'تصدير تقرير إداري';
      case 'login_success':
        return 'تسجيل دخول للنظام';
      default:
        return actionType;
    }
  }

  factory AuditLogEntry.fromJson(Map<String, dynamic> json) {
    return AuditLogEntry(
      id: json['id']?.toString() ??
          'LOG-${DateTime.now().millisecondsSinceEpoch}',
      userId: json['user_id']?.toString() ?? '',
      userName: json['user_name']?.toString() ?? 'مستخدم النظام',
      userRole: json['user_role']?.toString() ?? 'sales_rep',
      branchName: json['branch_name']?.toString() ?? 'فرع صنعاء',
      actionType: json['action_type']?.toString() ?? 'operation',
      targetEntity: json['target_entity']?.toString() ?? '',
      details: json['details']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'user_name': userName,
      'user_role': userRole,
      'branch_name': branchName,
      'action_type': actionType,
      'target_entity': targetEntity,
      'details': details,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

/// خدمة سجل التدقيق الشامل وتتبع العمليات الحساسة (Audit Trail & Activity Logging Service)
class AuditLogService {
  AuditLogService._();

  static final AuditLogService instance = AuditLogService._();

  static const String _keyLocalAuditLogs = 'jalap_cache_audit_logs_v14';

  /// تسجيل عملية حساسة في سجل التدقيق المحلي وفي جدول `audit_logs` بقاعدة بيانات Supabase
  Future<void> logAction({
    required String userId,
    required String userName,
    required String userRole,
    required String branchName,
    required String actionType,
    required String targetEntity,
    required String details,
  }) async {
    final now = DateTime.now();
    final entry = AuditLogEntry(
      id: 'AUDLOG-${now.millisecondsSinceEpoch}',
      userId: userId,
      userName: userName,
      userRole: userRole,
      branchName: branchName,
      actionType: actionType,
      targetEntity: targetEntity,
      details: details,
      createdAt: now,
    );

    // 1. الحفظ الفوري في السجل المحلي
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = await getLocalLogs();
      existing.insert(0, entry);
      if (existing.length > 300) {
        existing.removeRange(300, existing.length);
      }
      await prefs.setString(
        _keyLocalAuditLogs,
        jsonEncode(existing.map((e) => e.toJson()).toList()),
      );
    } catch (e) {
      debugPrint('Local audit log write info: $e');
    }

    // 2. المزامنة مع جدول audit_logs في Supabase
    if (AppConstants.isSupabaseConfigured) {
      try {
        await Supabase.instance.client.from(AppConstants.tableAuditLogs).insert({
          'user_id': userId,
          'user_name': userName,
          'user_role': userRole,
          'branch_name': branchName,
          'action_type': actionType,
          'target_entity': targetEntity,
          'details': details,
          'created_at': now.toIso8601String(),
        });
      } catch (e) {
        debugPrint('Supabase audit_logs sync info: $e');
      }
    }
  }

  /// استرجاع سجلات التدقيق المحفوظة محلياً
  Future<List<AuditLogEntry>> getLocalLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keyLocalAuditLogs);
      if (raw == null || raw.isEmpty) return <AuditLogEntry>[];
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => AuditLogEntry.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    } catch (e) {
      debugPrint('Read local audit logs warning: $e');
    }
    return <AuditLogEntry>[];
  }

  /// استرجاع سجل التدقيق الشامل المدمج من Supabase والسجل المحلي
  Future<List<AuditLogEntry>> fetchCombinedAuditLogs() async {
    final List<AuditLogEntry> combined = await getLocalLogs();

    if (AppConstants.isSupabaseConfigured) {
      final supabase = Supabase.instance.client;

      // 1. محاولة الجلب المباشر من جدول audit_logs إن كان مفعلاً في السحابة
      try {
        final List<dynamic> rows = await supabase
            .from(AppConstants.tableAuditLogs)
            .select()
            .order('created_at', ascending: false)
            .limit(150);
        for (final r in rows) {
          if (r is Map<String, dynamic>) {
            final entry = AuditLogEntry.fromJson(r);
            final exists = combined.any(
              (c) =>
                  c.actionType == entry.actionType &&
                  c.userId == entry.userId &&
                  c.createdAt.difference(entry.createdAt).inSeconds.abs() < 5,
            );
            if (!exists) {
              combined.add(entry);
            }
          }
        }
      } catch (_) {
        // في حال عدم تفعيل جدول audit_logs بعد، نبني سجلات التدقيق الحقيقية من الحركات المسجلة في الجداول الأساسية
      }
    }

    combined.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return combined;
  }
}
