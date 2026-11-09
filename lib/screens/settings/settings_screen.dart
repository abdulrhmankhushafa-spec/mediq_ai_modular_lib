import 'package:flutter/material.dart';
import '../../core/constants/app_keys.dart';
import '../../controllers/app_controller.dart';
import '../splash/splash_screen.dart';

class SettingsScreen extends StatefulWidget {
  final bool embedded;
  final VoidCallback? onOpenDrawer;

  const SettingsScreen({
    super.key,
    this.embedded = false,
    this.onOpenDrawer,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _pathCtrl = TextEditingController(
    text: '/storage/emulated/0/Download/qwen2.5-3b-instruct-q4_k_m.gguf',
  );
  bool _picking = false;

  @override
  void dispose() {
    _pathCtrl.dispose();
    super.dispose();
  }

  Future<void> _handlePickModel() async {
    if (_picking) return;
    setState(() => _picking = true);
    final res = await appController.pickModelFromPhone();
    if (mounted) {
      setState(() => _picking = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message']?.toString() ?? ''),
          backgroundColor: res['success'] == true ? const Color(0xFF10B981) : const Color(0xFFDC2626),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _showManualPathDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'إدخال مسار ملف النموذج (.gguf) في الهاتف',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'إذا كان الملف داخل مجلد التنزيلات أو أي مجلد معروف في الهاتف، يمكنك كتابة مساره المباشر هنا:',
              style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 10),
            Directionality(
              textDirection: TextDirection.ltr,
              child: TextField(
                controller: _pathCtrl,
                style: const TextStyle(fontSize: 12.5),
                decoration: InputDecoration(
                  hintText: '/storage/emulated/0/Download/model.gguf',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await appController.linkModelByManualPath(_pathCtrl.text);
              if (mounted) {
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      ok
                          ? 'تم ربط ملف النموذج من المسار المباشر بنجاح ✓'
                          : appController.modelStatusText,
                    ),
                    backgroundColor: ok ? const Color(0xFF10B981) : const Color(0xFFDC2626),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0077B6),
              foregroundColor: Colors.white,
            ),
            child: const Text('ربط وفحص الملف'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final modelInfo = appController.linkedModelInfo;
    final isLinked = appController.isModelLinked;

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
            if (widget.onOpenDrawer != null) {
              widget.onOpenDrawer!();
            } else {
              mainScaffoldKey.currentState?.openDrawer();
            }
          },
        ),
        title: Text(
          'الإعدادات وربط النموذج المحلي',
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF0A192F),
            fontWeight: FontWeight.w900,
            fontSize: 17,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. بطاقة اختيار وتجربة النموذج اللغوي (GGUF) من ذاكرة الهاتف مباشرة
          const Padding(
            padding: EdgeInsets.only(bottom: 8, right: 4),
            child: Text(
              'ربط وتجربة النموذج اللغوي (GGUF) من ذاكرة الهاتف',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 18),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isLinked
                    ? const Color(0xFF10B981).withOpacity(0.5)
                    : const Color(0xFF0077B6).withOpacity(0.35),
                width: 1.4,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: (isLinked ? const Color(0xFF10B981) : const Color(0xFF0077B6))
                            .withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isLinked ? Icons.check_circle_rounded : Icons.folder_open_rounded,
                        color: isLinked ? const Color(0xFF10B981) : const Color(0xFF0077B6),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isLinked
                                ? 'النموذج اللغوي مربوط وجاهز للتجربة ✓'
                                : 'اختر ملف النموذج (.gguf) من أي مجلد بالهاتف',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              color: isDark ? Colors.white : const Color(0xFF0A192F),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            appController.modelStatusText,
                            style: TextStyle(
                              fontSize: 12,
                              color: isLinked ? const Color(0xFF10B981) : const Color(0xFF64748B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (modelInfo != null) ...[
                  const Divider(height: 22),
                  _infoRow('اسم الملف:', modelInfo.fileName, isDark),
                  _infoRow('الحجم الفعلي:', modelInfo.formattedSize, isDark),
                  _infoRow('إصدار صيغة GGUF:', 'GGUF v${modelInfo.ggufVersion}', isDark),
                  _infoRow('عدد المصفوفات (Tensors):', '${modelInfo.tensorCount} مصفوفة', isDark),
                  _infoRow('بيانات الترويسة (Metadata):', '${modelInfo.metadataKvCount} مفتاحاً', isDark),
                  _infoRow('المسار في الهاتف:', modelInfo.filePath, isDark, isLtr: true),
                ],
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _picking ? null : _handlePickModel,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0077B6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: _picking
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.file_open_rounded, size: 19),
                    label: Text(
                      _picking
                          ? 'جاري فتح الملف وفحص الترويسة...'
                          : (isLinked
                              ? 'تغيير ملف النموذج (.gguf) من الهاتف'
                              : 'اختيار ملف النموذج (.gguf) من مجلدات الهاتف'),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _showManualPathDialog,
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.edit_road_rounded, size: 17),
                        label: const Text(
                          'إدخال مسار مباشر',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    if (isLinked) ...[
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () async {
                          await appController.unlinkCurrentModel();
                          if (mounted) setState(() {});
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.link_off_rounded, size: 17),
                        label: const Text(
                          'إلغاء الربط',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // 2. قسم إعدادات العرض والتطبيق
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

          const SizedBox(height: 20),
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

  Widget _infoRow(String label, String val, bool isDark, {bool isLtr = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Directionality(
              textDirection: isLtr ? TextDirection.ltr : TextDirection.rtl,
              child: Text(
                val,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
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
