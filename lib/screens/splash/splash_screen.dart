import 'package:flutter/material.dart';
import 'dart:async';
import '../../widgets/mediq_logo.dart';
import '../../widgets/animated_ecg_wave.dart';
import '../shell/main_shell.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainShell()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onTap: () => Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainShell()),
        ),
        child: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF040C18), Color(0xFF082242), Color(0xFF040B16)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF00E5FF).withOpacity(0.06),
                    border: Border.all(
                      color: const Color(0xFF00E5FF).withOpacity(0.22),
                      width: 1.5,
                    ),
                  ),
                  child: const MediqLogo(size: 112, showText: false),
                ),
                const SizedBox(height: 26),
                RichText(
                  text: const TextSpan(
                    style: TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                    children: [
                      TextSpan(text: 'MEDIQ ', style: TextStyle(color: Colors.white)),
                      TextSpan(text: 'AI', style: TextStyle(color: Color(0xFF00E5FF))),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Your Offline Medical AI Assistant',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'اسأل ... افهم ... تعلّم',
                  style: TextStyle(
                    color: Color(0xFF00E5FF),
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 28),
                const AnimatedEcgWave(width: 240, height: 48),
                const Spacer(flex: 2),
                const SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Color(0xFF00E5FF),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'جاري تهيئة المساعد الطبي الذكي...',
                  style: TextStyle(color: Colors.white70, fontSize: 13.5),
                ),
                const SizedBox(height: 36),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
