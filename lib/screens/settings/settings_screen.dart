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
    final isAdmin = appController.userRole.contains('مدير');

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
          // بطاقة المستخدم العلوية
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 25,
                  backgroundColor: Color(0xFF0077B6),
                  child: Icon(Icons.person_rounded, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appController.userName,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                      Text(
                        appController.userHandle,
                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 12.5),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'الصلاحية (RBAC): ${appController.userRole}',
                        style: const TextStyle(
                          color: Color(0xFF0096C7),
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: appController.toggleRole,
                  child: const Text('تبديل الدور', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // قسم إعدادات التطبيق
          const Padding(
            padding: EdgeInsets.only(bottom: 8, right: 4),
            child: Text(
              'إعدادات التطبيق',
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
          _switchTile(
            context,
            icon: Icons.save_outlined,
            title: 'حفظ المحادثات محلياً (SQLite)',
            value: appController.saveChats,
            onChanged: appController.toggleSaveChats,
          ),
          _switchTile(
            context,
            icon: Icons.notifications_none_rounded,
            title: 'الإشعارات والتنبيهات الطبية',
            value: appController.notificationsEnabled,
            onChanged: appController.toggleNotifications,
          ),

          const SizedBox(height: 16),
          // قسم معلومات النموذج المحلي
          const Padding(
            padding: EdgeInsets.only(bottom: 8, right: 4),
            child: Text(
              'معلومات النموذج والمحرك المحلي',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
            ),
          ),
          _tile(
            context,
            Icons.memory_rounded,
            'اسم النموذج (Local LLM)',
            appController.selectedModel,
            appController.cycleModel,
          ),
          _tile(
            context,
            Icons.dns_outlined,
            'حالة الخادم المحلي (llama.cpp)',
            appController.isLocalServerConnected ? 'متصل ●' : 'متوقف ○',
            appController.toggleServerStatus,
          ),
          _tile(
            context,
            Icons.storage_rounded,
            'إصدار قاعدة المعرفة الطبية',
            appController.knowledgeVersion,
            () {},
          ),

          // قسم إدارة المعرفة والنماذج
          if (isAdmin) ...[
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.only(bottom: 8, right: 4),
              child: Text(
                'لوحة مدير المعرفة (Knowledge Admin & Ingestion)',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  color: Color(0xFF0077B6),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF0077B6).withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'مسار ملف النموذج المكمم (GGUF Model Path):',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    appController.ggufModelPath,
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                  ),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'الوثائق الطبية المفهرسة (FTS5 + Vectors):',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          appController.addKnowledgeDocument(
                            'تحديث البروتوكول العلاجي ${DateTime.now().minute}.pdf',
                            '64 فقرة',
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'تم استيراد الملف وتقسيمه (Chunking) وفهرسته في قاعدة المعرفة ✓',
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.upload_file_rounded, size: 16),
                        label: const Text('استيراد PDF طبي', style: TextStyle(fontSize: 11.5)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0077B6),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...appController.knowledgeDocs.map(
                    (doc) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.picture_as_pdf_rounded, color: Colors.redAccent, size: 20),
                      title: Text(doc['title']!, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                      subtitle: Text('${doc['chunks']} • ${doc['status']}'),
                      trailing: Text(
                        doc['version']!,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF10B981), fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),
          // زر تسجيل الخروج / إعادة تهيئة الجلسة
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE11D48).withOpacity(0.25)),
            ),
            child: ListTile(
              onTap: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const SplashScreen()),
              ),
              leading: const Icon(Icons.logout_rounded, color: Color(0xFFE11D48)),
              title: const Text(
                'تسجيل الخروج / إعادة تهيئة النظام',
                style: TextStyle(
                  color: Color(0xFFE11D48),
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
