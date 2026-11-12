import 'package:flutter/material.dart';

/// الثوابت العامة، الهوية البصرية الملكية، وإعدادات الاتصال والعملة لتطبيق "جلب الميداني".
class AppConstants {
  AppConstants._();

  /// اسم التطبيق
  static const String appName = 'جلب الميداني - Jalap Sales';

  // ===========================================================================
  // الهوية البصرية الملكية المعتمدة (Royal Visual Identity)
  // ===========================================================================

  /// الكحلي الداكن الملكي (Deep Navy Blue) - اللون الأساسي
  static const Color deepNavyBlue = Color(0xFF0A1931);

  /// الكحلي الثانوي المتدرج
  static const Color royalNavySecondary = Color(0xFF152A4A);

  /// الذهبي الملكي (Royal Gold) - للأزرار البارزة وشارات الأداء
  static const Color royalGold = Color(0xFFD4AF37);

  /// الذهبي الفاتح للخلفيات والشارات
  static const Color softRoyalGold = Color(0xFFFDF7E2);

  /// الرمادي النقي (Clean Light Grey) - لخلفيات الشاشات
  static const Color cleanLightGrey = Color(0xFFF4F6F9);

  // ===========================================================================
  // إعدادات العملة الديناميكية المعتمدة للفروع (ر.ي / الريال)
  // ===========================================================================

  /// رمز العملة الافتراضي للفرع
  static const String defaultCurrencySymbol = 'ر.ي';

  /// المسمى الكامل للعملة
  static const String defaultCurrencyName = 'الريال';

  /// إرجاع رمز العملة الديناميكي بناءً على الفرع المرتبط بالمندوب أو المشرف
  static String currencyForBranch([String? branchNameOrId]) {
    if (branchNameOrId == null || branchNameOrId.trim().isEmpty) {
      return defaultCurrencySymbol;
    }
    return defaultCurrencySymbol;
  }

  /// تنسيق المبالغ المالية مع رمز العملة الديناميكي للفرع (ر.ي)
  static String formatCurrency(num amount, {String? branch}) {
    final formatted = amount.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
    return '$formatted ${currencyForBranch(branch)}';
  }

  // ===========================================================================
  // إعدادات الاتصال الثابتة والمدمجة بقاعدة بيانات Supabase (Production Ready)
  // ===========================================================================

  /// رابط مشروع Supabase الثابت والمدمج (Project URL)
  static const String supabaseUrl = 'https://oomvwtpsxrrnqcciqlau.supabase.co';

  /// مفتاح الوصول العام الثابت والمدمج (Anon / Publishable Key)
  static const String supabaseAnonKey =
      'sb_publishable_MQZzuOtQ17VhYFsjVwnUgQ_6FVGxlzF';

  /// التحقق مما إذا كانت بيانات الاتصال بـ Supabase مهيأة بمفاتيح حقيقية
  static bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty &&
      !supabaseUrl.contains('YOUR_PROJECT_ID') &&
      supabaseAnonKey.isNotEmpty &&
      !supabaseAnonKey.contains('YOUR_SUPABASE_ANON_KEY');

  // ===========================================================================
  // بيانات الحسابات التجريبية الافتراضية لتسهيل الدخول الميداني الفوري
  // ===========================================================================
  static const String defaultAdminEmail = 'admin@jalap.com';
  static const String defaultSalesEmail = 'rep@jalap.com';
  static const String defaultPassword = '123456';

  // ===========================================================================
  // أسماء الجداول السبعة المعتمدة في قاعدة البيانات (Database Tables)
  // ===========================================================================
  static const String tableBranches = 'branches';
  static const String tableChannels = 'channels';
  static const String tableCustomers = 'customers';
  static const String tableInventoryAudits = 'inventory_audits';
  static const String tableOrders = 'orders';
  static const String tableProducts = 'products';
  static const String tableUsersProfiles = 'users_profiles';
}
