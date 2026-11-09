import 'package:flutter/material.dart';
import '../../core/constants/app_keys.dart';
import '../../controllers/app_controller.dart';
import '../splash/splash_screen.dart';

class SettingsScreen extends StatelessWidget {
  final bool embedded;
  final VoidCallback? onOpenDrawer;

  const SettingsScreen({
    super.key,
    this.embedded = false,
    this.onOpenDrawer,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            Icons.menu_rounded,
            color: isDark ? Colors.white : const Color(0xFF0A192F),
          ),
          onPressed: () {
            if (onOpenDrawer != null) {
              onOpenDrawer!();
            } else {
              mainScaffoldKey.currentState?.openDrawer();
            }
          },
        ),
        title: Text(
          'الإعدادات',
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF0A192F),
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // قسم إعدادات التطبيق بدون حساب مستخدم أو أدمن وبدون أسماء النماذج/المحركات
          const Padding(
            padding: EdgeInsets.only(bottom: 8, right: 4),
            child: Text(
              'إعدادات العرض والتطبيق',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
            ),
          ),
          _tile(
            context,
            isDark ? Icons.dark_mode_outlined : Icons.wb_sunny_outlined,
            'المظهر',
            isDark ? 'الوضع الداكن' : 'الوضع الفاتح',
            appController.toggleTheme,
          ),
          _tile(
            context,
            Icons.language_rounded,
            'اللغة',
            appController.language,
            () {},
          ),
          _tile(
            context,
            Icons.text_fields_rounded,
            'حجم الخط',
            appController.fontSizeLabel,
            appController.cycleFontSize,
          ),

          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.only(bottom: 8, right: 4),
            child: Text(
              'الخصوصية وإدارة المحادثات المحلية',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
            ),
          ),
          _switchTile(
            context,
            icon: Icons.save_outlined,
            title: 'حفظ سجل المحادثات محلياً على الجهاز',
            value: appController.saveChats,
            onChanged: appController.toggleSaveChats,
          ),
          _switchTile(
            context,
            icon: Icons.lock_outline_rounded,
            title: 'قفل سجل المحادثات (حماية الخصوصية المحلية)',
            value: appController.localLockEnabled,
            onChanged: appController.toggleLocalLock,
          ),
          _switchTile(
            context,
            icon: Icons.notifications_none_rounded,
            title: 'التنبيهات والإرشادات الصحية',
            value: appController.notificationsEnabled,
            onChanged: appController.toggleNotifications,
          ),
          _tile(
            context,
            Icons.delete_sweep_outlined,
            'مسح سجل المحادثات المحفوظة',
            '${appController.chats.length} محادثة',
            () {
              appController.clearAllChats();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم مسح سجل المحادثات المحلية بنجاح ✓')),
              );
            },
          ),

          const SizedBox(height: 16),
          // قسم حالة النظام والتحديث عبر تحديثات التطبيق المعتمدة فقط (بدون رفع PDF يدوي)
          const Padding(
            padding: EdgeInsets.only(bottom: 8, right: 4),
            child: Text(
              'حالة النظام وتحديث البيانات الطبية',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
            ),
          ),
          _tile(
            context,
            Icons.wifi_off_rounded,
            'وضع التشغيل',
            'يعمل محلياً بدون إنترنت ●',
            () {},
          ),
          _tile(
            context,
            Icons.verified_outlined,
            'إصدار البيانات الطبية',
            appController.knowledgeVersion,
            () {},
          ),
          _tile(
            context,
            Icons.system_update_alt_rounded,
            'تحديث التطبيق وقاعدة المعرفة',
            'فحص التحديثات',
            () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'التطبيق محدّث إلى آخر إصدار معتمد، ويتم تحديث البيانات الطبية تلقائياً مع تحديثات التطبيق الرسمية ✓',
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 20),
          // زر إعادة تهيئة واجهة التطبيق
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF0077B6).withOpacity(0.25)),
            ),
            child: ListTile(
              onTap: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const SplashScreen()),
              ),
              leading: const Icon(Icons.restart_alt_rounded, color: Color(0xFF0077B6)),
              title: const Text(
                'إعادة تشغيل واجهة المساعد الطبي',
                style: TextStyle(
                  color: Color(0xFF0077B6),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _switchTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: SwitchListTile.adaptive(
        value: value,
        onChanged: onChanged,
        activeColor: const Color(0xFF0096C7),
        secondary: Icon(icon, color: const Color(0xFF0077B6), size: 22),
        title: Text(
          title,
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _tile(
    BuildContext context,
    IconData icon,
    String title,
    String trailing,
    VoidCallback onTap,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: const Color(0xFF0077B6), size: 22),
        title: Text(
          title,
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              trailing,
              style: const TextStyle(
                fontSize: 12.5,
                color: Color(0xFF0077B6),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }
}
