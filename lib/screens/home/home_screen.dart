import 'package:flutter/material.dart';
import '../../controllers/app_controller.dart';
import '../../widgets/mediq_logo.dart';

class HomeScreen extends StatelessWidget {
  final Function(Map<String, dynamic>) onOpenChat;
  final VoidCallback onNewChat;
  final VoidCallback onOpenDrawer;

  const HomeScreen({
    super.key,
    required this.onOpenChat,
    required this.onNewChat,
    required this.onOpenDrawer,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chats = appController.filteredChats;

    return SafeArea(
      child: Column(
        children: [
          // الشريط العلوي
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                InkWell(
                  onTap: onOpenDrawer,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Icon(
                      Icons.menu_rounded,
                      color: isDark ? Colors.white : const Color(0xFF0A192F),
                      size: 22,
                    ),
                  ),
                ),
                const Spacer(),
                const MediqLogo(size: 36),
                const Spacer(),
                IconButton(
                  onPressed: appController.toggleTheme,
                  style: IconButton.styleFrom(
                    backgroundColor: Theme.of(context).cardColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: Icon(
                    isDark ? Icons.wb_sunny_rounded : Icons.dark_mode_rounded,
                    color: isDark ? const Color(0xFFFFB703) : const Color(0xFF023E8A),
                    size: 20,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                // شريط حالة العمل المحلي
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'يعمل محلياً',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13.5,
                                color: isDark ? Colors.white : const Color(0xFF0A192F),
                              ),
                            ),
                            const Text(
                              'المساعد المحلي متصل • قاعدة المعرفة جاهزة',
                              style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.dns_rounded, color: Color(0xFF0077B6), size: 22),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // حقل البحث في المحادثات
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: TextField(
                    onChanged: appController.setSearchQuery,
                    decoration: const InputDecoration(
                      hintText: 'ابحث في المحادثات...',
                      hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
                      prefixIcon: Icon(Icons.search_rounded, color: Color(0xFF0077B6)),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // زر محادثة جديدة العريض
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onNewChat,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0077B6),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: const Text(
                      'محادثة جديدة',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // عنوان المحادثات الأخيرة
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      appController.showFavoritesOnly
                          ? 'المحادثات المفضلة ⭐'
                          : 'المحادثات الأخيرة',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF0A192F),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => appController
                          .setShowFavoritesOnly(!appController.showFavoritesOnly),
                      icon: Icon(
                        appController.showFavoritesOnly
                            ? Icons.view_list_rounded
                            : Icons.star_rounded,
                        size: 18,
                      ),
                      label: Text(
                        appController.showFavoritesOnly ? 'عرض الكل' : 'المفضلة فقط',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // قائمة المحادثات
                ...chats.map((chat) {
                  final isFav = chat['isFavorite'] == true;
                  final accentColor = Color(chat['color'] as int? ?? 0xFF0077B6);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: InkWell(
                      onTap: () => onOpenChat(chat),
                      borderRadius: BorderRadius.circular(18),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: accentColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                chat['icon'] as IconData? ?? Icons.medical_services,
                                color: accentColor,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    chat['title'].toString(),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14.5,
                                      color: isDark
                                          ? Colors.white
                                          : const Color(0xFF0A192F),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    chat['subtitle'].toString(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  chat['time'].toString(),
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () =>
                                      appController.toggleFavorite(chat['id'].toString()),
                                  icon: Icon(
                                    isFav ? Icons.star_rounded : Icons.star_border_rounded,
                                    color: isFav
                                        ? const Color(0xFFFFB703)
                                        : const Color(0xFF94A3B8),
                                    size: 20,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
