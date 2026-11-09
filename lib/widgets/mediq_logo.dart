import 'package:flutter/material.dart';

class MediqLogo extends StatelessWidget {
  final double size;
  final bool showText;
  final bool forceDark;
  final String? customSubtitle;

  const MediqLogo({
    super.key,
    this.size = 42,
    this.showText = true,
    this.forceDark = false,
    this.customSubtitle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = forceDark || Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size * 0.30),
            gradient: const LinearGradient(
              colors: [Color(0xFF00E5FF), Color(0xFF0077B6), Color(0xFF023E8A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00B4D8).withOpacity(0.28),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                Icons.chat_bubble_rounded,
                color: Colors.white.withOpacity(0.18),
                size: size * 0.74,
              ),
              Container(
                width: size * 0.56,
                height: size * 0.56,
                decoration: BoxDecoration(
                  color: const Color(0xFF051324).withOpacity(0.92),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.add_box_rounded,
                  color: const Color(0xFF00E5FF),
                  size: size * 0.36,
                ),
              ),
            ],
          ),
        ),
        if (showText) ...[
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontSize: size * 0.42,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.7,
                  ),
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
              Text(
                customSubtitle ?? 'مساعدك الطبي الذكي',
                style: TextStyle(
                  fontSize: size * 0.23,
                  color: isDark ? Colors.white70 : const Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
