import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/participated_event.dart';
import '../models/brokerage_event.dart';

class ParticipatedEventsProvider extends ChangeNotifier {
  static const _prefsKey = 'participated_events';

  List<ParticipatedEvent> _events = [];

  /// 활성 → 지급일 오름차순, 완료 → 지급일 오름차순으로 뒤에 배치
  List<ParticipatedEvent> get events {
    final active = _events.where((e) => !e.isCompleted).toList()
      ..sort((a, b) => a.rewardDate.compareTo(b.rewardDate));
    final completed = _events.where((e) => e.isCompleted).toList()
      ..sort((a, b) => a.rewardDate.compareTo(b.rewardDate));
    return [...active, ...completed];
  }

  int get count => _events.length;

  /// 올해 경품 지급일이 지난 항목의 prizeAmount 합계
  int get totalReceivedThisYear {
    final now = DateTime.now();
    return _events
        .where((e) =>
            e.rewardDate.year == now.year &&
            e.isCompleted &&
            e.prizeAmount != null)
        .fold(0, (sum, e) => sum + e.prizeAmount!);
  }

  /// 선택된 증권사 AND 카테고리 조합 중 다음 참여 가능일이 미래인 기록 반환
  List<ParticipatedEvent> getRestrictions({
    Set<BrokerageType> brokerages = const {},
    Set<EventCategory> categories = const {},
  }) {
    if (brokerages.isEmpty || categories.isEmpty) return [];
    final now = DateTime.now();
    return _events.where((e) {
      if (e.nextEligibleDate == null) return false;
      if (!e.nextEligibleDate!.isAfter(now)) return false;
      return brokerages.contains(e.brokerage) && categories.contains(e.category);
    }).toList()
      ..sort((a, b) => a.nextEligibleDate!.compareTo(b.nextEligibleDate!));
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null) {
      final list = jsonDecode(raw) as List;
      _events = list
          .map((e) => ParticipatedEvent.fromJson(e as Map<String, dynamic>))
          .toList();

      // 참여일 기준 1년 이상 지난 항목 자동 삭제
      final cutoff = DateTime.now().subtract(const Duration(days: 365));
      final before = _events.length;
      _events.removeWhere((e) => e.participatedAt.isBefore(cutoff));
      if (_events.length != before) await _save();

      notifyListeners();
    }
  }

  Future<void> add(ParticipatedEvent event) async {
    _events.add(event);
    notifyListeners();
    await _save();
  }

  Future<void> update(ParticipatedEvent updated) async {
    final idx = _events.indexWhere((e) => e.id == updated.id);
    if (idx != -1) {
      _events[idx] = updated;
      notifyListeners();
      await _save();
    }
  }

  Future<void> remove(String id) async {
    _events.removeWhere((e) => e.id == id);
    notifyListeners();
    await _save();
  }

  bool hasParticipated(String eventId) =>
      _events.any((e) => e.eventId == eventId);

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode(_events.map((e) => e.toJson()).toList()),
    );
  }
}
