import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/brokerage_event.dart';

class CacheService {
  static const String _eventsKey = 'cached_events';
  static const String _lastFetchedKey = 'last_fetched_at';
  static const Duration _cacheDuration = Duration(hours: 24);

  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  /// 캐시가 유효한지 확인 (24시간 이내)
  Future<bool> isCacheValid() async {
    final prefs = await SharedPreferences.getInstance();
    final lastFetchedStr = prefs.getString(_lastFetchedKey);
    if (lastFetchedStr == null) return false;

    final lastFetched = DateTime.parse(lastFetchedStr);
    return DateTime.now().difference(lastFetched) < _cacheDuration;
  }

  /// 캐시에서 이벤트 로드
  Future<List<BrokerageEvent>?> loadFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_eventsKey);
    if (jsonStr == null) return null;

    try {
      final List<dynamic> jsonList = jsonDecode(jsonStr);
      return jsonList.map((j) => BrokerageEvent.fromJson(j as Map<String, dynamic>)).toList();
    } catch (e) {
      return null;
    }
  }

  /// 캐시에 이벤트 저장
  Future<void> saveToCache(List<BrokerageEvent> events) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(events.map((e) => e.toJson()).toList());
    await prefs.setString(_eventsKey, jsonStr);
    await prefs.setString(_lastFetchedKey, DateTime.now().toIso8601String());
  }

  /// 마지막 수집 시간 반환
  Future<DateTime?> getLastFetchedTime() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_lastFetchedKey);
    return str != null ? DateTime.parse(str) : null;
  }

  /// 캐시 삭제 (강제 새로고침용)
  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_eventsKey);
    await prefs.remove(_lastFetchedKey);
  }
}
