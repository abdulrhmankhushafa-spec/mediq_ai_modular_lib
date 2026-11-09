import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_keys.dart';
import '../../controllers/app_controller.dart';
import '../../services/medical_rag_service.dart';
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
  final ScrollController _scrollCtrl = ScrollController();
  final List<Map<String, dynamic>> _exchanges = [];
  bool _loading = false;
  bool _isStreaming = false;
  Timer? _streamTimer;
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
    _streamTimer?.cancel();
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  /// التمرير التلقائي السلس إلى أسفل المحادثة عند إرسال رسالة أو وصول رد
  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollCtrl.hasClients) return;
      final target = _scrollCtrl.position.maxScrollExtent;
      if (animated) {
        _scrollCtrl.animateTo(
          target,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        );
      } else {
        _scrollCtrl.jumpTo(target);
      }
    });
  }

  /// إيقاف التوليد الحي فوراً عند ضغط المستخدم على زر الإيقاف
  void _stopGeneration() {
    _streamTimer?.cancel();
    if (mounted) {
      setState(() {
        _loading = false;
        _isStreaming = false;
      });
    }
  }

  void _send([String? preset]) async {
    final txt = preset ?? _ctrl.text.trim();
    if (txt.isEmpty || _loading || _isStreaming) return;
    _ctrl.clear();

    final sentTime = MedicalRagService.formatTimeNow();
    final sentFullDate = MedicalRagService.formatFullDateTime();

    // 1. إظهار رسالة المستخدم فوراً في المحادثة ورفع الشاشة تلقائياً
    final pendingExchange = <String, dynamic>{
      'id': 'pending_${DateTime.now().millisecondsSinceEpoch}',
      'question': txt,
      'userTime': sentTime,
      'time': sentTime,
      'fullDate': sentFullDate,
      'isPendingAi': true,
    };

    setState(() {
      _exchanges.add(pendingExchange);
      _loading = true;
    });
    _scrollToBottom();

    await Future.delayed(const Duration(milliseconds: 280));
    final fullReply = await appController.generateReplyAsync(txt);

    if (!mounted || !_loading) return;

    // 2. بدء تأثير الكتابة الحية المتدرجة (Streaming Text Effect) مع التمرير التلقائي
    final fullIntro = fullReply['answerIntro']?.toString() ?? '';
    final fullBullets = (fullReply['bullets'] as List?)?.cast<String>() ?? <String>[];
    final words = fullIntro.split(' ');

    final activeReply = Map<String, dynamic>.from(fullReply);
    activeReply['userTime'] = sentTime;
    activeReply['isPendingAi'] = false;
    activeReply['answerIntro'] = '';
    activeReply['bullets'] = <String>[];
    activeReply['showExtras'] = false;

    final int targetIdx = _exchanges.length - 1;
    setState(() {
      _loading = false;
      _isStreaming = true;
      _exchanges[targetIdx] = activeReply;
    });
    _scrollToBottom();

    int wordIndex = 0;
    _streamTimer?.cancel();
    _streamTimer = Timer.periodic(const Duration(milliseconds: 28), (timer) {
      if (!mounted || !_isStreaming) {
        timer.cancel();
        return;
      }

      if (wordIndex < words.length) {
        final step = (wordIndex + 2 <= words.length) ? 2 : 1;
        wordIndex += step;
        setState(() {
          _exchanges[targetIdx]['answerIntro'] = words.take(wordIndex).join(' ');
        });
        _scrollToBottom(animated: false);
      } else {
        timer.cancel();
        setState(() {
          _exchanges[targetIdx]['answerIntro'] = fullIntro;
          _exchanges[targetIdx]['bullets'] = fullBullets;
          _exchanges[targetIdx]['showExtras'] = true;
          _isStreaming = false;
        });
        _scrollToBottom();
      }
    });
  }

  /// نافذة قارئ ومفسّر التقارير والتحاليل الطبية الذكي (OCR & Lab Analyzer)
  void _scanMedicalTextOcr() {
    final TextEditingController ocrCtrl = TextEditingController(
      text: 'تقرير مختبر طبي (OCR): Hb: 9.2 g/dL | Ferritin: 8 ng/mL | Vit D: 12 ng/mL',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.document_scanner_rounded,
                    color: Color(0xFF0077B6), size: 24),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'قارئ ومفسّر التقارير والتحاليل الطبية (OCR)',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'اختر نموذج تقرير طبي مستخلص أو أدخل أرقام التحليل المخبري ليقوم المساعد بتفسيرها فوراً:',
              style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  label: const Text('تقرير فقر دم ونقص حديد (CBC)',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    ocrCtrl.text =
                        'تقرير مختبر طبي (OCR): Hb: 9.2 g/dL | Ferritin: 8 ng/mL | Vit D: 12 ng/mL';
                  },
                ),
                ActionChip(
                  label: const Text('تقرير سكر صائم وتراكمي (HbA1c)',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    ocrCtrl.text =
                        'نتيجة تحليل السكر (OCR): FBS: 148 mg/dL | HbA1c: 7.4%';
                  },
                ),
                ActionChip(
                  label: const Text('تقرير التهاب وعدوى (WBC)',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    ocrCtrl.text =
                        'تقرير مختبر طبي (OCR): WBC: 13.5 x10^3/uL | CRP: Positive';
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: ocrCtrl,
              maxLines: 3,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                labelText: 'النص الطبي المستخلص من الصورة أو التقرير',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  final textToAnalyze = ocrCtrl.text.trim();
                  Navigator.pop(ctx);
                  if (textToAnalyze.isNotEmpty) {
                    _send(textToAnalyze);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0077B6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.analytics_outlined, size: 20),
                label: const Text(
                  'تحليل وتفسير التقرير الطبي في المحادثة',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                ),
              ),
            ),
          ],
        ),
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
          IconButton(
            tooltip: 'اختيار ملف النموذج (.gguf) من الهاتف للتجربة',
            onPressed: () async {
              final res = await appController.pickModelFromPhone(context);
              if (mounted) {
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(res['message']?.toString() ?? ''),
                    backgroundColor: res['success'] == true
                        ? const Color(0xFF10B981)
                        : const Color(0xFFDC2626),
                  ),
                );
              }
            },
            icon: Icon(
              appController.isModelLinked
                  ? Icons.memory_rounded
                  : Icons.folder_open_rounded,
              size: 20,
              color: appController.isModelLinked
                  ? const Color(0xFF10B981)
                  : const Color(0xFF0077B6),
            ),
          ),
          if (!showWelcome)
            IconButton(
              tooltip: 'بدء محادثة جديدة',
              onPressed: () {
                _stopGeneration();
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
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                    children: [
                      if (hasInitialBuiltInAnswer) ...[
                        _userBubble(
                          widget.chatData['question'].toString(),
                          widget.chatData['time']?.toString() ??
                              MedicalRagService.formatTimeNow(),
                        ),
                        const SizedBox(height: 14),
                        _aiBubble(widget.chatData, isDark),
                      ],
                      ..._exchanges.map(
                        (ex) => Padding(
                          padding: const EdgeInsets.only(top: 18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _userBubble(
                                ex['question'].toString(),
                                ex['userTime']?.toString() ??
                                    ex['time']?.toString() ??
                                    MedicalRagService.formatTimeNow(),
                              ),
                              const SizedBox(height: 14),
                              if (ex['isPendingAi'] == true)
                                _loadingIndicatorCard(isDark)
                              else
                                _aiBubble(ex, isDark),
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

  Widget _loadingIndicatorCard(bool isDark) {
    return Container(
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
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: Color(0xFF0096C7),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'جاري تحليل سؤالك وصياغة التقييم الطبي محلياً...',
              style: TextStyle(
                color: Color(0xFF0096C7),
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeView(bool isDark) {
    final quickCards = [
      {
        't': 'ما هي أنواع المغص؟',
        'sub': 'البطن والجهاز الهضمي',
        'i': Icons.medical_information_outlined,
        'c': 0xFF0077B6
      },
      {
        't': 'وجع في الراس',
        'sub': 'تقييم الصداع والشقيقة',
        'i': Icons.psychology_outlined,
        'c': 0xFF0096C7
      },
      {
        't': 'ما هي الأطعمة التي ترفع الحديد بسرعة؟',
        'sub': 'فقر الدم والتغذية',
        'i': Icons.bloodtype_outlined,
        'c': 0xFFE11D48
      },
      {
        't': 'ما الفرق بين السكر الصائم والتراكمي؟',
        'sub': 'السكري والتحاليل',
        'i': Icons.biotech_outlined,
        'c': 0xFF10B981
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
              'مساعدك الطبي الذكي • يفهم اللهجات ويعمل بدون إنترنت',
              style: TextStyle(
                fontSize: 12.5,
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
                          '${c['title']} (${c['time'] ?? ''})',
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
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
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: Color(0xFF475569),
                    fontWeight: FontWeight.w600,
                  ),
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
    final followUps = (data['followUps'] as List?)?.cast<String>() ?? [];
    final isEmergency = data['isEmergency'] == true;
    final showExtras = data['showExtras'] != false;
    final isConversational = data['isConversational'] == true ||
        (bullets.isEmpty && (sections == null || sections.isEmpty));
    final importantNote = data['importantNote']?.toString() ?? '';
    final source = data['source']?.toString() ?? '';
    final msgTime = data['time']?.toString() ?? MedicalRagService.formatTimeNow();
    final msgDate = data['fullDate']?.toString() ?? msgTime;

    return Container(
      padding: EdgeInsets.all(isConversational ? 14 : 18),
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
              const MediqLogo(size: 26, showText: false),
              const SizedBox(width: 8),
              Text(
                'MEDIQ AI',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  color: isDark ? Colors.white : const Color(0xFF0A192F),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                msgDate,
                style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
              ),
              const Spacer(),
              if (!isConversational)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0096C7).withOpacity(0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    data['category']?.toString() ?? 'تقييم سريري',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0096C7),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            data['answerIntro']?.toString() ?? '',
            style: TextStyle(
              fontSize: 14,
              height: 1.55,
              fontWeight: isConversational ? FontWeight.w600 : FontWeight.w700,
              color: isEmergency
                  ? Colors.redAccent
                  : (isDark ? Colors.white : const Color(0xFF1E293B)),
            ),
          ),
          if (!isConversational && showExtras) ...[
            const SizedBox(height: 10),
            if (sections != null && sections.isNotEmpty)
              ...sections.map((sec) {
                final mapSec = sec as Map<String, dynamic>;
                final secItems = (mapSec['items'] as List).cast<String>();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
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
          ],
          if (!isConversational && showExtras && importantNote.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(11),
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
                    size: 17,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      importantNote,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF1E3A8A),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (showExtras && followUps.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text(
              'أسئلة متابعة مقترحة لتفصيل حالتك:',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: followUps.map((fq) {
                return ActionChip(
                  visualDensity: VisualDensity.compact,
                  backgroundColor: const Color(0xFF0077B6).withOpacity(isDark ? 0.22 : 0.08),
                  side: BorderSide(color: const Color(0xFF0077B6).withOpacity(0.28)),
                  label: Text(
                    fq,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0077B6),
                    ),
                  ),
                  onPressed: () => _send(fq),
                );
              }).toList(),
            ),
          ],
          if (!isConversational && showExtras) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                if (source.isNotEmpty)
                  Expanded(
                    child: Text(
                      '📖 $source',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                    ),
                  ),
                const SizedBox(width: 8),
                _actionBtn(
                  icon: Icons.copy_rounded,
                  label: 'نسخ التقرير',
                  onTap: () {
                    final report = '📋 استشارة طبية - MEDIQ AI\n'
                        'التاريخ والوقت: $msgDate\n'
                        'السؤال: ${data['question']}\n\n'
                        '${data['answerIntro']}\n'
                        '${bullets.map((b) => "• $b").join("\n")}\n'
                        '${importantNote.isNotEmpty ? "\nتنويه: $importantNote" : ""}';
                    Clipboard.setData(ClipboardData(text: report));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم نسخ التقرير الطبي المنسق إلى الحافظة ✓')),
                    );
                  },
                ),
              ],
            ),
          ],
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFCBD5E1).withOpacity(0.6)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: const Color(0xFF64748B)),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _inputBar(bool isDark) {
    final isBusy = _loading || _isStreaming;

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
                        hintText: 'اكتب سؤالك أو العرض الطبي بأي لهجة...',
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
                                  color: Color(0xFF0077B6),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'قراءة وتفسير تحليل طبي (OCR)',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF0077B6),
                                    fontWeight: FontWeight.w700,
                                  ),
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
              onTap: isBusy ? _stopGeneration : () => _send(),
              borderRadius: BorderRadius.circular(30),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isBusy
                        ? [const Color(0xFFEF4444), const Color(0xFFDC2626)]
                        : [const Color(0xFF0096C7), const Color(0xFF0077B6)],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isBusy ? Icons.stop_rounded : Icons.send_rounded,
                  color: Colors.white,
                  size: 21,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
