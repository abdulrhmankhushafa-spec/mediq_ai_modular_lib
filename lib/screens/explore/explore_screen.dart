import 'package:flutter/material.dart';

class ExploreScreen extends StatelessWidget {
  final Function(String) onAskQuestion;
  final VoidCallback onOpenDrawer;

  const ExploreScreen({
    super.key,
    required this.onAskQuestion,
    required this.onOpenDrawer,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topics = [
      {
        'title': 'صحة القلب والشرايين',
        'sub': 'ضغط الدم، ECG، والكوليسترول',
        'icon': Icons.monitor_heart_rounded,
        'color': 0xFFE11D48,
        'q': 'ما هي أعراض ارتفاع ضغط الدم؟'
      },
      {
        'title': 'السكري والغدد',
        'sub': 'مستوى السكر، HbA1c، والأنسولين',
        'icon': Icons.water_drop_rounded,
        'color': 0xFF0096C7,
        'q': 'ما هي أعراض مرض السكري؟'
      },
      {
        'title': 'المناعة والفيتامينات',
        'sub': 'فيتامين D، الحديد، والمناعة',
        'icon': Icons.shield_rounded,
        'color': 0xFF10B981,
        'q': 'كيف يعمل الجهاز المناعي وما فائدة فيتامين D للجسم؟'
      },
      {
        'title': 'الجهاز الهضمي',
        'sub': 'جرثومة المعدة والقولون',
        'icon': Icons.restaurant_menu_rounded,
        'color': 0xFFF59E0B,
        'q': 'ما هي أسباب التهاب المعدة؟'
      },
      {
        'title': 'أمراض الدم والأنيميا',
        'sub': 'نقص الحديد، الهيموجلوبين، CBC',
        'icon': Icons.bloodtype_rounded,
        'color': 0xFF8B5CF6,
        'q': 'ما هي أعراض فقر الدم؟'
      },
      {
        'title': 'الإسعافات والسلامة الطبية',
        'sub': 'التنبيهات الحرجة والطوارئ',
        'icon': Icons.medical_services_rounded,
        'color': 0xFFEC4899,
        'q': 'ما هي الإسعافات الأولية لحالات الإغماء وانخفاض السكر؟'
      },
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.menu_rounded,
            color: isDark ? Colors.white : const Color(0xFF0A192F),
          ),
          onPressed: onOpenDrawer,
        ),
        title: Text(
          'الموسوعة والبحث في المعلومة الطبية',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : const Color(0xFF0A192F),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'اختر أي تخصص طبي لبدء استرجاع المعرفة وتوليد الإجابة عبر محرك (RAG) المحلي:',
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: topics.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.05,
            ),
            itemBuilder: (context, i) {
              final t = topics[i];
              final c = Color(t['color'] as int);
              return InkWell(
                onTap: () => onAskQuestion(t['q'] as String),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: c.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(t['icon'] as IconData, color: c, size: 24),
                      ),
                      const Spacer(),
                      Text(
                        t['title'] as String,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: isDark ? Colors.white : const Color(0xFF0A192F),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        t['sub'] as String,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
