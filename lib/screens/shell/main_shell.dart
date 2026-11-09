import 'package:flutter/material.dart';
import '../../core/constants/app_keys.dart';
import '../../controllers/app_controller.dart';
import '../../widgets/sidebar_drawer.dart';
import '../../widgets/info_panel.dart';
import '../home/home_screen.dart';
import '../explore/explore_screen.dart';
import '../chat/chat_screen.dart';
import '../tools/medical_tools_screen.dart';
import '../student/medical_student_hub_screen.dart';
import '../settings/settings_screen.dart';

class MainShell extends StatefulWidget {
  final int initialIndex;
  const MainShell({super.key, this.initialIndex = 2});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _navIndex;
  Map<String, dynamic>? _activeChatData;

  @override
  void initState() {
    super.initState();
    _navIndex = widget.initialIndex;
    _activeChatData = {
      'id': 'new',
      'title': 'استفسار طبي',
      'question': '',
      'answerIntro': '',
      'bullets': <String>[],
      'footer': '',
    };
  }

  void _openSpecificChat(Map<String, dynamic> chat) {
    setState(() {
      _activeChatData = Map<String, dynamic>.from(chat);
      _navIndex = 2; // الانتقال مباشرة إلى تبويب واجهة المحادثة
    });
  }

  void _startNewChat([String? initialQuestion]) {
    setState(() {
      _activeChatData = {
        'id': 'new_${DateTime.now().millisecondsSinceEpoch}',
        'isNewSession': true,
        'title': 'استفسار طبي جديد',
        'question': initialQuestion ?? '',
        'answerIntro': '',
        'bullets': <String>[],
        'footer': '',
      };
      _navIndex = 2; // فتح واجهة المحادثة فوراً
    });
  }

  void _openDrawer() {
    mainScaffoldKey.currentState?.openDrawer();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 960;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final currentChat = _activeChatData ??
        (appController.chats.isNotEmpty
            ? appController.chats.first
            : {
                'id': 'new',
                'isNewSession': true,
                'title': 'استفسار طبي',
                'question': '',
                'answerIntro': '',
                'bullets': <String>[],
                'footer': '',
              });

    final pages = [
      HomeScreen(
        onOpenChat: _openSpecificChat,
        onNewChat: () => _startNewChat(),
        onOpenDrawer: _openDrawer,
      ),
      ExploreScreen(
        onAskQuestion: (q) => _startNewChat(q),
        onOpenDrawer: _openDrawer,
      ),
      ChatScreen(
        key: ValueKey(currentChat['id']),
        chatData: currentChat,
        embedded: true,
        onOpenDrawer: _openDrawer,
        onOpenSettings: () => setState(() => _navIndex = 5),
        onSelectChatFromHistory: _openSpecificChat,
        onStartNewChat: () => _startNewChat(),
      ),
      MedicalToolsScreen(
        embedded: true,
        onOpenDrawer: _openDrawer,
      ),
      MedicalStudentHubScreen(
        embedded: true,
        onOpenDrawer: _openDrawer,
      ),
      SettingsScreen(
        embedded: true,
        onOpenDrawer: _openDrawer,
      ),
    ];

    if (isDesktop) {
      return Scaffold(
        key: mainScaffoldKey,
        body: Row(
          children: [
            SizedBox(
              width: 280,
              child: SidebarDrawer(
                selectedIndex: _navIndex,
                onNewChat: () => _startNewChat(),
                onSelectNav: (idx) => setState(() => _navIndex = idx),
                onSelectChat: _openSpecificChat,
              ),
            ),
            Expanded(
              flex: 3,
              child: pages[_navIndex],
            ),
            Container(
              width: 310,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF091524) : Colors.white,
                border: Border(
                  right: BorderSide(
                    color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
              child: const InfoPanel(),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      key: mainScaffoldKey,
      drawer: Drawer(
        width: 295,
        backgroundColor: const Color(0xFF061222),
        child: SidebarDrawer(
          selectedIndex: _navIndex,
          onNewChat: () {
            Navigator.pop(context);
            _startNewChat();
          },
          onSelectNav: (idx) {
            Navigator.pop(context);
            setState(() => _navIndex = idx);
          },
          onSelectChat: (chat) {
            Navigator.pop(context);
            _openSpecificChat(chat);
          },
        ),
      ),
      body: IndexedStack(
        index: _navIndex,
        children: pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF091524) : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: _navIndex > 5 ? 0 : _navIndex,
          onDestinationSelected: (i) => setState(() => _navIndex = i),
          backgroundColor: Colors.transparent,
          elevation: 0,
          height: 68,
          indicatorColor: const Color(0xFF0077B6).withOpacity(isDark ? 0.30 : 0.14),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded, color: Color(0xFF0096C7)),
              label: 'الرئيسية',
            ),
            NavigationDestination(
              icon: Icon(Icons.explore_outlined),
              selectedIcon: Icon(Icons.explore_rounded, color: Color(0xFF0096C7)),
              label: 'استكشاف',
            ),
            NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline_rounded),
              selectedIcon: Icon(Icons.chat_bubble_rounded, color: Color(0xFF0096C7)),
              label: 'المحادثات',
            ),
            NavigationDestination(
              icon: Icon(Icons.medical_services_outlined),
              selectedIcon: Icon(Icons.medical_services_rounded, color: Color(0xFF0096C7)),
              label: 'الحاسبات',
            ),
            NavigationDestination(
              icon: Icon(Icons.school_outlined),
              selectedIcon: Icon(Icons.school_rounded, color: Color(0xFF0096C7)),
              label: 'الطلاب',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings_rounded, color: Color(0xFF0096C7)),
              label: 'الإعدادات',
            ),
          ],
        ),
      ),
    );
  }
}
