/// نموذج بيانات ملف المستخدم المرتبط بجدول `users_profiles` في قاعدة بيانات Supabase.
class UserProfileModel {
  /// المعرف الفريد للمستخدم (UUID المرتبط بـ auth.users)
  final String id;

  /// البريد الإلكتروني للمستخدم
  final String email;

  /// الاسم الكامل للمستخدم أو المندوب
  final String fullName;

  /// الدور الوظيفي والصلاحية ('admin' أو 'sales_rep')
  final String role;

  /// معرف الفرع المرتبط بالمستخدم (قد يكون فارغاً للمشرف العام)
  final String? branchId;

  /// حالة تفعيل الحساب
  final bool isActive;

  /// تاريخ إنشاء الحساب
  final DateTime? createdAt;

  const UserProfileModel({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    this.branchId,
    this.isActive = true,
    this.createdAt,
  });

  // ===========================================================================
  // الخصائص المساعدة للصلاحيات والأدوار (Role Helpers)
  // ===========================================================================

  /// هل المستخدم يمتلك صلاحية مشرف / مدير نظام؟
  bool get isAdmin => role.trim().toLowerCase() == 'admin';

  /// هل المستخدم يمتلك صلاحية مندوب مبيعات ميداني؟
  bool get isSales =>
      role.trim().toLowerCase() == 'sales_rep' ||
      role.trim().toLowerCase() == 'sales';

  /// المسمى الوظيفي باللغة العربية للعرض في الواجهات
  String get roleArabicLabel => isAdmin ? 'مشرف نظام' : 'مندوب مبيعات';

  // ===========================================================================
  // دوال التحويل من وإلى JSON (Serialization) مع التعامل الآمن مع القيم الفارغة
  // ===========================================================================

  /// إنشاء كائن [UserProfileModel] من خريطة بيانات JSON قادمة من Supabase
  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    return UserProfileModel(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      fullName: (json['full_name'] ?? json['fullName'])?.toString() ?? 'مستخدم',
      role: json['role']?.toString() ?? 'sales_rep',
      branchId: (json['branch_id'] ?? json['branchId'])?.toString(),
      isActive: _parseBool(json['is_active'] ?? json['isActive'], defaultValue: true),
      createdAt: _parseDateTime(json['created_at'] ?? json['createdAt']),
    );
  }

  /// تحويل كائن [UserProfileModel] إلى خريطة بيانات JSON لإرسالها إلى Supabase
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'role': role,
      'branch_id': branchId,
      'is_active': isActive,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  /// إنشاء نسخة معدلة من الكائن الحالي
  UserProfileModel copyWith({
    String? id,
    String? email,
    String? fullName,
    String? role,
    String? branchId,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return UserProfileModel(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      branchId: branchId ?? this.branchId,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static bool _parseBool(dynamic value, {required bool defaultValue}) {
    if (value == null) return defaultValue;
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1') return true;
      if (normalized == 'false' || normalized == '0') return false;
    }
    return defaultValue;
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}

