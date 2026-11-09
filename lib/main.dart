import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app/mediq_ai_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );
  runApp(const MediqAiApp());
}
