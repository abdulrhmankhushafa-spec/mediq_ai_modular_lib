import 'package:flutter/material.dart';
import '../controllers/app_controller.dart';
import 'mediq_logo.dart';

class SidebarDrawer extends StatelessWidget {
  final int selectedIndex;
  final VoidCallback onNewChat;
  final Function(int) onSelectNav;
  final Function(Map<String, dynamic>) onSelectChat;

  const SidebarDrawer({
    super.key,
    required this.selectedIndex,
    required this.onNewChat,
    required this.onSelectNav,
    required this.onSelectChat,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF061222),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // الشعار العلوي
              const MediqLogo(
                size: 40,
                forceDark: true,
                customSubtitle: 'مساعدك الطبي الذكي',
              ),
              const SizedBox(height: 14),

              // بطاقة المستخدم
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 18,
                      backgroundColor: Color(0xFF0077B6),
                      child: Icon(Icons.person_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            appController.userName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5,
                            ),
                          ),
                          Text(
                            appController.userHandle,
                            style: const TextStyle(color: Colors.white54, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // زر محادثة جديدة
              InkWell(
                onTap: onNewChat,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0077B6), Color(0xFF0096C7)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0077B6).withOpacity(0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 18),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'محادثة جديدة',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                      Icon(Icons.add_rounded, color: Colors.white, size: 20),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // حقل البحث في المحادثات داخل القائمة الجانبية
              Container(
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: TextField(
                  onChanged: appController.setSearchQuery,
                  style: const TextStyle(color: Colors.white, fontSize: 12.5),
                  decoration: const InputDecoration(
                    hintText: 'البحث في المحادثات...',
                    hintStyle: TextStyle(color: Colors.white54, fontSize: 12),
                    prefixIcon: Icon(Icons.search_rounded, color: Colors.white54, size: 18),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // عناصر القائمة الجانبية + سجل المحادثات السريع
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _navItem(
                      icon: Icons.history_rounded,
                      title: 'المحادثات السابقة',
                      active: selectedIndex == 0 && !appController.showFavoritesOnly,
                      onTap: () {
                        appController.setShowFavoritesOnly(false);
                        onSelectNav(0);
                      },
                    ),
                    _navItem(
                      icon: Icons.chat_rounded,
                      title: 'واجهة المحادثة الذكية',
                      active: selectedIndex == 2,
                      onTap: () => onSelectNav(2),
                    ),
                    _navItem(
                      icon: Icons.manage_search_rounded,
                      title: 'البحث في المعلومة الطبية',
                      active: selectedIndex == 1,
                      onTap: () => onSelectNav(1),
                    ),
                    _navItem(
                      icon: Icons.star_outline_rounded,
                      title: 'المفضلة',
                      active: selectedIndex == 0 && appController.showFavoritesOnly,
                      onTap: () {
                        appController.setShowFavoritesOnly(true);
                        onSelectNav(0);
                      },
                    ),
                    _navItem(
                      icon: Icons.menu_book_rounded,
                      title: 'الملاحظات والحاسبات الطبية',
                      active: selectedIndex == 3,
                      onTap: () => onSelectNav(3),
                    ),
                    _navItem(
                      icon: Icons.school_outlined,
                      title: 'بوابة طالب الطب (OSCE & GCS)',
                      active: selectedIndex == 4,
                      onTap: () => onSelectNav(4),
                    ),
                    _navItem(
                      icon: Icons.settings_outlined,
                      title: 'الإعدادات',
                      active: selectedIndex == 5,
                      onTap: () => onSelectNav(5),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Divider(color: Colors.white12, height: 1),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 6, right: 4),
                      child: Text(
                        'آخر الاستشارات المحفوظة:',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    ...appController.filteredChats.take(4).map(
                          (c) => ListTile(
                            onTap: () => onSelectChat(c),
                            dense: true,
                            visualDensity: const VisualDensity(vertical: -3),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 6),
                            leading: Icon(
                              c['icon'] as IconData? ?? Icons.chat_bubble_outline,
                              color: const Color(0xFF00B4D8),
                              size: 16,
                            ),
                            title: Text(
                              c['title'].toString(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ),
                        ),
                  ],
                ),
              ),

              const SizedBox(height: 8),
              // بطاقة حالة العمل المحلي
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A1E36),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF00B4D8).withOpacity(0.25)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: appController.isLocalServerConnected
                            ? const Color(0xFF10B981)
                            : Colors.orange,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            appController.isLocalServerConnected
                                ? 'يعمل محلياً'
                                : 'الوضع الاحتياطي',
                            style: const TextStyle(
                              color: Color(0xFF10B981),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          const Text(
                            'بدون إنترنت • النموذج متصل بالشبكة المحلية',
                            style: TextStyle(color: Colors.white60, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.wifi_off_rounded, color: Colors.white54, size: 16),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // بطاقة النموذج المستخدم
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A1E36),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.memory_rounded, color: Color(0xFF00E5FF), size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'النموذج المستخدم',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 11.5,
                            ),
                          ),
                          Text(
                            appController.selectedModel,
                            style: const TextStyle(color: Colors.white60, fontSize: 10.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // تذييل الإصدار (MEDIQ AI v1.0.0)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'MEDIQ AI v1.0.0',
                    style: TextStyle(
                      color: Color(0xFF38BDF8),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  InkWell(
                    onTap: () => onSelectNav(5),
                    child: const Icon(
                      Icons.settings_outlined,
                      color: Colors.white54,
                      size: 16,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem({
    required IconData icon,
    required String title,
    required bool active,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: active ? const Color(0xFF0077B6).withOpacity(0.22) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        onTap: onTap,
        dense: true,
        visualDensity: const VisualDensity(vertical: -2),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10),
        leading: Icon(
          icon,
          color: active ? const Color(0xFF00E5FF) : Colors.white70,
          size: 20,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: active ? Colors.white : Colors.white70,
            fontSize: 13,
            fontWeight: active ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
