import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../data/initial_medical_data.dart';
import '../services/local_llm_service.dart';
import '../services/medical_rag_service.dart';

/// وحدة التحكم بالحالة والبيانات (MVVM ViewModel) مع حفظ دائم لسجل المحادثات والتواريخ
class AppController extends ChangeNotifier {
  bool isDarkMode = false;
  String language = 'العربية';
  String fontSizeLabel = 'متوسط';
  bool saveChats = true;
  bool notificationsEnabled = true;
  bool isOfflineReady = true;
  bool localLockEnabled = false;
  String knowledgeVersion = 'الإصدار المعتمد 2026.1';
  String searchQuery = '';
  bool showFavoritesOnly = false;

  Map<String, String> medicalId = InitialMedicalData.defaultMedicalId;
  List<Map<String, dynamic>> vitalsLog = InitialMedicalData.defaultVitalsLog;
  List<Map<String, dynamic>> medsList = InitialMedicalData.defaultMedsList;
  List<Map<String, String>> knowledgeDocs = InitialMedicalData.defaultKnowledgeDocs;
  final List<Map<String, dynamic>> chats =
      List<Map<String, dynamic>>.from(InitialMedicalData.defaultChats);

  File get _chatsStorageFile =>
      File('${Directory.systemTemp.path}/mediq_ai_saved_chats_v2.json');

  AppController() {
    initLocalModel();
    _loadPersistedChats();
  }

  GgufModelInfo? get linkedModelInfo => LocalLlmService.instance.modelInfo;
  bool get isModelLinked =>
      LocalLlmService.instance.state == LocalModelState.ready &&
      linkedModelInfo != null;
  String get modelStatusText => LocalLlmService.instance.statusMessage;

  Future<void> initLocalModel() async {
    await LocalLlmService.instance.initialize();
    notifyListeners();
  }

  /// استعادة سجل المحادثات المحفوظة في الهاتف مع تواريخها الفعلية
  Future<void> _loadPersistedChats() async {
    try {
      if (await _chatsStorageFile.exists()) {
        final raw = await _chatsStorageFile.readAsString();
        final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
        if (decoded.isNotEmpty) {
          final loaded = decoded.map((item) {
            final map = Map<String, dynamic>.from(item as Map);
            map['icon'] = _iconFromCode(map['iconCode'] as int?);
            return map;
          }).toList();
          chats
            ..clear()
            ..addAll(loaded);
          notifyListeners();
        }
      }
    } catch (_) {}
  }

  /// حفظ سجل المحادثات محلياً على الجهاز
  Future<void> _persistChatsToDisk() async {
    if (!saveChats) return;
    try {
      final serializable = chats.take(40).map((c) {
        final copy = Map<String, dynamic>.from(c);
        final iconData = copy.remove('icon');
        if (iconData is IconData) {
          copy['iconCode'] = iconData.codePoint;
        }
        return copy;
      }).toList();
      await _chatsStorageFile.writeAsString(jsonEncode(serializable));
    } catch (_) {}
  }

  IconData _iconFromCode(int? code) {
    if (code == Icons.warning_amber_rounded.codePoint) {
      return Icons.warning_amber_rounded;
    }
    if (code == Icons.document_scanner_rounded.codePoint) {
      return Icons.document_scanner_rounded;
    }
    if (code == Icons.bloodtype_rounded.codePoint) {
      return Icons.bloodtype_rounded;
    }
    if (code == Icons.water_drop_rounded.codePoint) {
      return Icons.water_drop_rounded;
    }
    return Icons.health_and_safety_rounded;
  }

  Future<Map<String, dynamic>> pickModelFromPhone(BuildContext context) async {
    final res = await LocalLlmService.instance
        .pickModelWithNativeOrInAppBrowser(context);
    notifyListeners();
    return res;
  }

  Future<bool> linkModelByManualPath(String path) async {
    final ok = await LocalLlmService.instance
        .loadModelFromPath(path.trim(), saveConfig: true);
    notifyListeners();
    return ok;
  }

  Future<bool> linkDemoGgufModel() async {
    final path =
        await LocalLlmService.instance.createDemoGgufFileForTesting();
    final ok =
        await LocalLlmService.instance.loadModelFromPath(path, saveConfig: true);
    notifyListeners();
    return ok;
  }

  Future<void> unlinkCurrentModel() async {
    await LocalLlmService.instance.unlinkModel();
    notifyListeners();
  }

  double get fontScale {
    switch (fontSizeLabel) {
      case 'صغير':
        return 0.90;
      case 'كبير':
        return 1.12;
      default:
        return 1.0;
    }
  }

  List<Map<String, dynamic>> get filteredChats {
    return chats.where((chat) {
      final q = searchQuery.trim();
      final matchesSearch = q.isEmpty ||
          chat['title'].toString().contains(q) ||
          chat['subtitle'].toString().contains(q) ||
          chat['question'].toString().contains(q) ||
          (chat['category']?.toString().contains(q) ?? false);
      final matchesFav = !showFavoritesOnly || (chat['isFavorite'] == true);
      return matchesSearch && matchesFav;
    }).toList();
  }

  void toggleTheme() {
    isDarkMode = !isDarkMode;
    notifyListeners();
  }

  void cycleFontSize() {
    fontSizeLabel = fontSizeLabel == 'صغير'
        ? 'متوسط'
        : fontSizeLabel == 'متوسط'
            ? 'كبير'
            : 'صغير';
    notifyListeners();
  }

  void toggleSaveChats(bool v) {
    saveChats = v;
    notifyListeners();
  }

  void toggleNotifications(bool v) {
    notificationsEnabled = v;
    notifyListeners();
  }

  void toggleLocalLock(bool v) {
    localLockEnabled = v;
    notifyListeners();
  }

  void toggleFavorite(String id) {
    final idx = chats.indexWhere((c) => c['id'] == id);
    if (idx != -1) {
      chats[idx]['isFavorite'] = !(chats[idx]['isFavorite'] ?? false);
      _persistChatsToDisk();
      notifyListeners();
    }
  }

  void deleteChat(String id) {
    chats.removeWhere((c) => c['id'] == id);
    _persistChatsToDisk();
    notifyListeners();
  }

  void clearAllChats() {
    chats.clear();
    _persistChatsToDisk();
    notifyListeners();
  }

  void setSearchQuery(String q) {
    searchQuery = q;
    notifyListeners();
  }

  void setShowFavoritesOnly(bool v) {
    showFavoritesOnly = v;
    notifyListeners();
  }

  void addVital(String type, String val, String status) {
    vitalsLog.insert(0, {
      'date': MedicalRagService.formatFullDateTime(),
      'type': type,
      'val': val,
      'status': status,
    });
    notifyListeners();
  }

  void toggleMed(int index) {
    medsList[index]['status'] = !medsList[index]['status'];
    notifyListeners();
  }

  Future<Map<String, dynamic>> generateReplyAsync(String q) async {
    final reply = await MedicalRagService.generateReplyAsync(
      query: q,
      knowledgeVersion: knowledgeVersion,
    );

    if (saveChats && reply['isConversational'] != true) {
      chats.insert(0, Map<String, dynamic>.from(reply));
      _persistChatsToDisk();
      notifyListeners();
    }
    return reply;
  }

  Map<String, dynamic> generateReply(String q) {
    final reply = MedicalRagService.generateReply(
      query: q,
      knowledgeVersion: knowledgeVersion,
    );

    if (saveChats && reply['isConversational'] != true) {
      chats.insert(0, Map<String, dynamic>.from(reply));
      _persistChatsToDisk();
      notifyListeners();
    }
    return reply;
  }
}

final AppController appController = AppController();
