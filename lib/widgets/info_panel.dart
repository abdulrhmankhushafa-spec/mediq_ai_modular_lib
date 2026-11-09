import 'package:flutter/material.dart';
import 'animated_ecg_wave.dart';
import 'mediq_logo.dart';

class InfoPanel extends StatelessWidget {
  const InfoPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF10243A) : const Color(0xFFF0F7FF),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              const Icon(Icons.monitor_heart_rounded, color: Color(0xFF0096C7), size: 46),
              const SizedBox(height: 10),
              Text(
                'مساعدك الطبي الذكي',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: isDark ? Colors.white : const Color(0xFF0A192F),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'احصل على إجابات دقيقة وموثوقة لأسئلتك الطبية.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _feat(
          Icons.verified_user_outlined,
          'معلومات طبية موثوقة',
          'مبنية على مراجع وزارة الصحة ومنظمة الصحة العالمية',
          isDark,
        ),
        _feat(
          Icons.language_rounded,
          'دعم اللغة العربية',
          'تواصل بسهولة بلغتك الأم مع شرح المصطلحات الطبية',
          isDark,
        ),
        _feat(
          Icons.wifi_off_rounded,
          'يعمل محلياً',
          'بدون الحاجة للإنترنت (Offline-First)',
          isDark,
        ),
        _feat(
          Icons.shield_outlined,
          'خصوصيتك تهمنا',
          'تُعالج وتحفظ جميع استفساراتك محلياً على جهازك',
          isDark,
        ),
        const SizedBox(height: 12),

        // صندوق "تنويه مهم" الأزرق
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF0284C7).withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF0284C7).withOpacity(0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: Color(0xFF0284C7), size: 18),
                  SizedBox(width: 6),
                  Text(
                    'تنويه مهم',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 13.5,
                      color: Color(0xFF0284C7),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'المعلومات المقدمة في هذا التطبيق للتثقيف الطبي العام فقط، ولا تغني عن استشارة الطبيب المختص أو التشخيص السريري.\n\n'
                'في حالات الطوارئ، يرجى التوجه مباشرة إلى أقرب مركز طبي.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: isDark ? Colors.white70 : const Color(0xFF334155),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Center(
          child: AnimatedEcgWave(
            width: 180,
            height: 34,
            color: Color(0xFF0096C7),
          ),
        ),
        const SizedBox(height: 8),
        const Center(
          child: Text(
            'معاً نحو صحة أفضل',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Color(0xFF64748B),
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Center(child: MediqLogo(size: 32, showText: true)),
      ],
    );
  }

  Widget _feat(IconData icon, String title, String sub, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: const Color(0xFF0096C7).withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFF0096C7), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: isDark ? Colors.white : const Color(0xFF0A192F),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sub,
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
