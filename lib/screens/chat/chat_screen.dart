import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_keys.dart';
import '../../controllers/app_controller.dart';
import '../../widgets/mediq_logo.dart';
import '../../widgets/info_panel.dart';

class ChatScreen extends StatefulWidget {
  final Map<String, dynamic> chatData;
  final bool embedded;
  final VoidCallback? onOpenDrawer;
  final VoidCallback? onOpenSettings;
  final Function(Map<String, dynamic>)? onSelectChatFromHistory;
  final VoidCallback? onStartNewChat;

  const ChatScreen({
    super.key,
    required this.chatData,
    this.embedded = false,
    this.onOpenDrawer,
    this.onOpenSettings,
    this.onSelectChatFromHistory,
    this.onStartNewChat,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _ctrl = TextEditingController();
  final List<Map<String, dynamic>> _exchanges = [];
  bool _loading = false;
  int _charCount = 0;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() {
      if (mounted) {
        setState(() => _charCount = _ctrl.text.length);
      }
    });

    final initialQ = widget.chatData['question']?.toString() ?? '';
    final isNewSession = widget.chatData['isNewSession'] == true ||
        widget.chatData['id'].toString().startsWith('new');
    if (isNewSession && initialQ.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _send(initialQ));
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _send([String? preset]) async {
    final txt = preset ?? _ctrl.text.trim();
    if (txt.isEmpty || _loading) return;
    _ctrl.clear();

    Map<String, dynamic>? matchedPrebuilt;
    for (final c in appController.chats) {
      if (c['question'].toString().trim() == txt ||
          txt.contains('فقر الدم') && c['id'] == 'anemia' ||
          txt.contains('السكري') && c['id'] == 'diabetes' ||
          txt.contains('التهاب المعدة') && c['id'] == 'gastritis' ||
          txt.contains('فيتامين D') && c['id'] == 'vitamind') {
        matchedPrebuilt = Map<String, dynamic>.from(c);
        matchedPrebuilt['question'] = txt;
        break;
      }
    }

    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 650));

    final reply = matchedPrebuilt ?? appController.generateReply(txt);
    if (mounted) {
      setState(() {
        _loading = false;
        _exchanges.add(reply);
      });
    }
  }

  // استخلاص النصوص المطبوعة من الصور الطبية عبر OCR فقط (كما في ص 25 و 31 من الخطة)
  void _scanMedicalTextOcr() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'قارئ النصوص الطبية (OCR): مخصص لاستخلاص النصوص المطبوعة من التقارير والوصفات لتحليلها في المحادثة.',
        ),
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isNewSession = widget.chatData['isNewSession'] == true ||
        widget.chatData['id'].toString().startsWith('new');
    final hasInitialBuiltInAnswer =
        !isNewSession && (widget.chatData['question']?.toString().isNotEmpty ?? false);
    final showWelcome = !hasInitialBuiltInAnswer && _exchanges.isEmpty && !_loading;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).cardColor,
        elevation: 0,
        leading: IconButton(
          tooltip: 'القائمة الجانبية',
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
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.edit_outlined, size: 14, color: Color(0xFF0077B6)),
                  const SizedBox(width: 5),
                  Text(
                    widget.chatData['title']?.toString() ?? 'استفسار طبي',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0A192F),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Flexible(
                    child: Text(
                      'متصل محلياً بدون إنترنت',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF10B981),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (!showWelcome)
            IconButton(
              tooltip: 'بدء محادثة جديدة',
              onPressed: () {
                setState(() => _exchanges.clear());
                if (widget.onStartNewChat != null) widget.onStartNewChat!();
              },
              icon: const Icon(Icons.add_comment_outlined, size: 20),
            ),
          IconButton(
            tooltip: 'معلومات النظام والتنويه الطبي',
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Theme.of(context).cardColor,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                builder: (_) => const SizedBox(height: 520, child: InfoPanel()),
              );
            },
            icon: const Icon(Icons.info_outline_rounded, size: 20),
          ),
          if (widget.onOpenSettings != null)
            IconButton(
              tooltip: 'الإعدادات',
              onPressed: widget.onOpenSettings,
              icon: const Icon(Icons.settings_outlined, size: 20),
            ),
        ],
      ),
      body: Column(
        children: [
          // لافتة التنويه الطبي الثابتة
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            color: const Color(0xFF0077B6).withOpacity(isDark ? 0.18 : 0.08),
            child: const Row(
              children: [
                Icon(Icons.verified_user_outlined, size: 15, color: Color(0xFF0077B6)),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'مساعد طبي محلي: المعلومات المقدمة للتثقيف الصحي العام ولا تغني عن استشارة الطبيب المختص.',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0077B6),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: showWelcome
                ? _buildWelcomeView(isDark)
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (hasInitialBuiltInAnswer) ...[
                        _userBubble(
                          widget.chatData['question'].toString(),
                          widget.chatData['time']?.toString() ?? '10:24 م',
                        ),
                        const SizedBox(height: 14),
                        _aiBubble(widget.chatData, isDark),
                      ],
                      ..._exchanges.map(
                        (ex) => Padding(
                          padding: const EdgeInsets.only(top: 18),
                          child: Column(
                            children: [
                              _userBubble(
                                ex['question'].toString(),
                                ex['time']?.toString() ?? 'الآن',
                              ),
                              const SizedBox(height: 14),
                              _aiBubble(ex, isDark),
                            ],
                          ),
                        ),
                      ),
                      if (_loading)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: const Row(
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Color(0xFF0096C7),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'جاري البحث في المراجع الطبية المعتمدة وصياغة الإجابة محلياً...',
                                    style: TextStyle(
                                      color: Color(0xFF0096C7),
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
          _inputBar(isDark),
        ],
      ),
    );
  }

  Widget _buildWelcomeView(bool isDark) {
    final quickCards = [
      {
        't': 'ما هي أعراض ارتفاع ضغط الدم؟',
        'sub': 'القلب والشرايين',
        'i': Icons.favorite_border_rounded,
        'c': 0xFF0077B6
      },
      {
        't': 'كيف يعمل الجهاز المناعي؟',
        'sub': 'المناعة والوقاية',
        'i': Icons.shield_outlined,
        'c': 0xFF0096C7
      },
      {
        't': 'ما فائدة فيتامين D للجسم؟',
        'sub': 'الفيتامينات',
        'i': Icons.medication_outlined,
        'c': 0xFF10B981
      },
      {
        't': 'ما هي أعراض فقر الدم؟',
        'sub': 'أمراض الدم (الأنيميا)',
        'i': Icons.bloodtype_outlined,
        'c': 0xFFE11D48
      },
    ];

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const MediqLogo(size: 74, showText: false),
            const SizedBox(height: 12),
            RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                children: [
                  TextSpan(
                    text: 'MEDIQ ',
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0A192F),
                    ),
                  ),
                  const TextSpan(
                    text: 'AI',
                    style: TextStyle(color: Color(0xFF00B4D8)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'مساعدك الطبي الذكي',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'كيف يمكنني مساعدتك اليوم؟',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : const Color(0xFF0A192F),
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: quickCards.map((item) {
                final c = Color(item['c'] as int);
                return InkWell(
                  onTap: () => _send(item['t'] as String),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 162,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: c.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(item['i'] as IconData, color: c, size: 18),
                            ),
                            const Spacer(),
                            const Icon(
                              Icons.arrow_outward_rounded,
                              size: 14,
                              color: Color(0xFF94A3B8),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          item['t'] as String,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            height: 1.35,
                            color: isDark ? Colors.white : const Color(0xFF0A192F),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 22),
            if (appController.chats.isNotEmpty) ...[
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'أو استكمل إحدى المحادثات الطبية السابقة:',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white70 : const Color(0xFF475569),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: appController.chats.map((c) {
                    return Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: ActionChip(
                        avatar: Icon(
                          c['icon'] as IconData? ?? Icons.chat_bubble_outline,
                          size: 16,
                          color: const Color(0xFF0077B6),
                        ),
                        label: Text(
                          c['title'].toString(),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        onPressed: () {
                          if (widget.onSelectChatFromHistory != null) {
                            widget.onSelectChatFromHistory!(c);
                          } else {
                            _send(c['question'].toString());
                          }
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _userBubble(String txt, String time) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CircleAvatar(
          radius: 17,
          backgroundColor: Color(0xFFDBEAFE),
          child: Icon(Icons.person_rounded, color: Color(0xFF0284C7), size: 20),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFDCEBFA),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(4),
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(18),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  time,
                  style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 4),
                Text(
                  txt,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _aiBubble(Map<String, dynamic> data, bool isDark) {
    final sections = data['sections'] as List?;
    final bullets = (data['bullets'] as List?)?.cast<String>() ?? [];
    final isEmergency = data['isEmergency'] == true;
    final importantNote = data['importantNote']?.toString() ?? '';
    final source =
        data['source']?.toString() ?? 'المراجع الطبية المعتمدة في قاعدة المعرفة المحلية';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isEmergency
              ? Colors.redAccent
              : (isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
          width: isEmergency ? 1.6 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const MediqLogo(size: 30, showText: false),
              const SizedBox(width: 8),
              Text(
                'MEDIQ AI',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13.5,
                  color: isDark ? Colors.white : const Color(0xFF0A192F),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                data['time']?.toString() ?? '10:25 م',
                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF0096C7).withOpacity(0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'معلومة موثقة',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0096C7),
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 22),
          Text(
            data['answerIntro']?.toString() ?? '',
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              fontWeight: FontWeight.w700,
              color: isEmergency
                  ? Colors.redAccent
                  : (isDark ? Colors.white : const Color(0xFF1E293B)),
            ),
          ),
          const SizedBox(height: 12),
          if (sections != null && sections.isNotEmpty)
            ...sections.map((sec) {
              final mapSec = sec as Map<String, dynamic>;
              final secItems = (mapSec['items'] as List).cast<String>();
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mapSec['heading'].toString(),
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13.5,
                        color: isDark
                            ? const Color(0xFF38BDF8)
                            : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...secItems.map(
                      (itm) => Padding(
                        padding: const EdgeInsets.only(bottom: 5, right: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '• ',
                              style: TextStyle(
                                color: Color(0xFF0096C7),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                itm,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  height: 1.45,
                                  color: isDark
                                      ? Colors.white.withOpacity(0.9)
                                      : const Color(0xFF334155),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            })
          else
            ...bullets.map(
              (b) => Padding(
                padding: const EdgeInsets.only(bottom: 7, right: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Icon(Icons.circle, color: Color(0xFF0096C7), size: 7),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        b,
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.5,
                          color: isDark
                              ? Colors.white.withOpacity(0.88)
                              : const Color(0xFF334155),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 10),
          if (importantNote.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isEmergency
                    ? Colors.red.withOpacity(0.10)
                    : const Color(0xFF0284C7).withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isEmergency
                      ? Colors.redAccent.withOpacity(0.4)
                      : const Color(0xFF0284C7).withOpacity(0.25),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_rounded,
                    color: isEmergency ? Colors.redAccent : const Color(0xFF0284C7),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.5,
                          color: isDark ? Colors.white : const Color(0xFF1E3A8A),
                        ),
                        children: [
                          const TextSpan(
                            text: 'مهم: ',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                          TextSpan(text: importantNote),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (data['footer'] != null && data['footer'].toString().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              data['footer'].toString(),
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : const Color(0xFF475569),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.library_books_outlined, size: 14, color: Color(0xFF64748B)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'المصدر الطبي: $source',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _actionBtn(
                icon: Icons.thumb_up_alt_outlined,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('شكراً لتقييمك الإيجابي للإجابة الطبية ✓')),
                  );
                },
              ),
              _actionBtn(
                icon: Icons.thumb_down_alt_outlined,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم تسجيل ملاحظتك لتحسين جودة الإجابات')),
                  );
                },
              ),
              _actionBtn(
                icon: Icons.copy_rounded,
                label: 'نسخ الإجابة',
                onTap: () {
                  Clipboard.setData(
                    ClipboardData(
                      text:
                          '${data['answerIntro']}\n${bullets.join("\n")}\n$importantNote\n${data['footer']}',
                    ),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم نسخ الإجابة الطبية إلى الحافظة ✓')),
                  );
                },
              ),
              _actionBtn(
                icon: Icons.refresh_rounded,
                label: 'إعادة التوليد',
                onTap: () => _send(data['question'].toString()),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionBtn({
    required IconData icon,
    String label = '',
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFCBD5E1).withOpacity(0.6)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: const Color(0xFF64748B)),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // شريط الإدخال السفلي (يقتصر على إدخال النص أو قراءة نص طبي مطبوع OCR دون رفع ملفات خارجية لقاعدة المعرفة)
  Widget _inputBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          top: BorderSide(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF06101E) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? Colors.white12 : const Color(0xFFDCE4F0),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _ctrl,
                      maxLines: 3,
                      minLines: 1,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'اكتب سؤالك الطبي هنا...',
                        hintStyle: TextStyle(fontSize: 13.5, color: Color(0xFF94A3B8)),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                    Row(
                      children: [
                        InkWell(
                          onTap: _scanMedicalTextOcr,
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.document_scanner_outlined,
                                  size: 17,
                                  color: Color(0xFF64748B),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'قراءة نص طبي من صورة (OCR)',
                                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '$_charCount/4000',
                          style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            InkWell(
              onTap: () => _send(),
              borderRadius: BorderRadius.circular(30),
              child: Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0096C7), Color(0xFF0077B6)],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
