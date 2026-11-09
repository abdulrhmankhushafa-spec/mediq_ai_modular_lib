import 'package:flutter/material.dart';
import '../data/initial_medical_data.dart';
import '../services/medical_rag_service.dart';

/// وحدة التحكم بالحالة والبيانات (MVVM ViewModel)
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

  // الهوية الطبية والعلامات الحيوية
  Map<String, String> medicalId = InitialMedicalData.defaultMedicalId;
  List<Map<String, dynamic>> vitalsLog = InitialMedicalData.defaultVitalsLog;
  List<Map<String, dynamic>> medsList = InitialMedicalData.defaultMedsList;
  List<Map<String, String>> knowledgeDocs = InitialMedicalData.defaultKnowledgeDocs;
  final List<Map<String, dynamic>> chats = InitialMedicalData.defaultChats;

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
      notifyListeners();
    }
  }

  void deleteChat(String id) {
    chats.removeWhere((c) => c['id'] == id);
    notifyListeners();
  }

  void clearAllChats() {
    chats.clear();
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
    vitalsLog.insert(0, {'date': 'الآن', 'type': type, 'val': val, 'status': status});
    notifyListeners();
  }

  void toggleMed(int index) {
    medsList[index]['status'] = !medsList[index]['status'];
    notifyListeners();
  }

  Map<String, dynamic> generateReply(String q) {
    final reply = MedicalRagService.generateReply(
      query: q,
      knowledgeVersion: knowledgeVersion,
    );

    if (saveChats) {
      chats.insert(0, reply);
      notifyListeners();
    }
    return reply;
  }
}

final AppController appController = AppController();
