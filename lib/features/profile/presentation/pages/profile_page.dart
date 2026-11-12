import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/offline_sync_service.dart';
import '../../../auth/data/models/user_profile_model.dart';

/// شاشة الملف الشخصي وإعدادات النظام والمزامنة وطابور العمليات (Sync Queue)
class ProfilePage extends StatefulWidget {
  final UserProfileModel userProfile;
  final bool isSigningOut;
  final VoidCallback onSignOut;

  const ProfilePage({
    super.key,
    required this.userProfile,
    required this.isSigningOut,
    required this.onSignOut,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final OfflineSyncService _offlineSync = OfflineSyncService.instance;
  bool _isSyncing = false;
  DateTime _lastSyncedAt = DateTime.now();

  /// تنفيذ مزامنة يدوية وتفريغ طابور المزامنة (Sync Queue) إلى Supabase
  Future<void> _handleManualSync() async {
    if (_isSyncing) return;

    setState(() => _isSyncing = true);

    try {
      final int flushedCount = await _offlineSync.forceManualSync();
      await Future<void>.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        setState(() {
          _lastSyncedAt = DateTime.now();
        });

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
                child: Row(
                  children: [
                    const Icon(
                      Icons.cloud_done_rounded,
                      color: AppConstants.royalGold,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        flushedCount > 0
                            ? 'تم رفع ومزامنة ($flushedCount) عمليات من طابور المزامنة بنجاح'
                            : 'تمت مزامنة كافة الجداول السبعة وحفظ النسخة المحلية بنجاح',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  String _formatSyncTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final user = widget.userProfile;

    return Scaffold(
      backgroundColor: AppConstants.cleanLightGrey,
      appBar: AppBar(
        title: const Text(
          'الملف الشخصي وإعدادات النظام',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        backgroundColor: AppConstants.deepNavyBlue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // =================================================================
            // 1. بطاقة الهوية الملكية للمندوب / المشرف
            // =================================================================
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    AppConstants.deepNavyBlue,
                    AppConstants.royalNavySecondary,
                  ],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 42,
                    backgroundColor: AppConstants.royalGold,
                    child: Icon(
                      user.isAdmin
                          ? Icons.admin_panel_settings_rounded
                          : Icons.badge_rounded,
                      size: 44,
                      color: AppConstants.deepNavyBlue,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    user.fullName,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.email,
                    textDirection: TextDirection.ltr,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppConstants.royalGold,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.verified_user_rounded,
                              size: 16,
                              color: AppConstants.deepNavyBlue,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              user.roleArabicLabel,
                              style: const TextStyle(
                                color: AppConstants.deepNavyBlue,
                                fontWeight: FontWeight.bold,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ValueListenableBuilder<bool>(
                        valueListenable: _offlineSync.isOnlineNotifier,
                        builder: (context, isOnline, _) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isOnline
                                  ? Colors.green.shade600
                                  : Colors.amber.shade700,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isOnline
                                      ? Icons.cloud_done_rounded
                                      : Icons.cloud_off_rounded,
                                  size: 16,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  isOnline
                                      ? 'متصل (Online)'
                                      : 'يعمل محلياً (Offline)',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // =================================================================
            // 2. تفاصيل الحساب والعملة وطابور المزامنة (Sync Queue)
            // =================================================================
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: colorScheme.outlineVariant),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: AppConstants.softRoyalGold,
                      child: Icon(
                        Icons.store_mall_directory_outlined,
                        color: AppConstants.deepNavyBlue,
                      ),
                    ),
                    title: const Text(
                      'الفرع والعملة المعتمدة (branches)',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${user.branchId ?? 'الفرع الرئيسي - صنعاء'} • العملة: ${AppConstants.defaultCurrencyName} (${AppConstants.currencyForBranch(user.branchId)})',
                    ),
                  ),
                  const Divider(height: 1),
                  ValueListenableBuilder<int>(
                    valueListenable: _offlineSync.pendingSyncCountNotifier,
                    builder: (context, pendingCount, _) {
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: pendingCount > 0
                              ? Colors.amber.shade100
                              : Colors.green.shade50,
                          child: Icon(
                            Icons.outbox_rounded,
                            color: pendingCount > 0
                                ? Colors.amber.shade900
                                : Colors.green.shade700,
                          ),
                        ),
                        title: const Text(
                          'طابور المزامنة المحلي (Sync Queue)',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          pendingCount > 0
                              ? 'توجد ($pendingCount) عمليات محفوظة محلياً بانتظار الرفع إلى Supabase'
                              : 'جميع العمليات الميدانية متزامنة ومحدثة بالكامل',
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: AppConstants.softRoyalGold,
                      child: Icon(
                        Icons.sync_rounded,
                        color: AppConstants.deepNavyBlue,
                      ),
                    ),
                    title: const Text(
                      'حالة التخزين المحلي (Offline-First)',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'الأصناف الـ 27 والعملاء والطلبات محفوظة محلياً • آخر تحديث: ${_formatSyncTime(_lastSyncedAt)}',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // =================================================================
            // 3. أزرار المزامنة اليدوية وتسجيل الخروج الآمن
            // =================================================================
            SizedBox(
              height: 54,
              child: FilledButton.icon(
                onPressed: _isSyncing ? null : _handleManualSync,
                style: FilledButton.styleFrom(
                  backgroundColor: AppConstants.deepNavyBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: _isSyncing
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.cloud_sync_rounded,
                        color: AppConstants.royalGold,
                      ),
                label: Text(
                  _isSyncing
                      ? 'جاري مزامنة الطابور مع Supabase...'
                      : 'مزامنة يدوية ورفع طابور العمليات',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 54,
              child: FilledButton.tonalIcon(
                onPressed: widget.isSigningOut ? null : widget.onSignOut,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red.shade50,
                  foregroundColor: Colors.red.shade700,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: widget.isSigningOut
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.red.shade700,
                        ),
                      )
                    : const Icon(Icons.logout_rounded),
                label: const Text(
                  'تسجيل الخروج الآمن من الحساب',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
