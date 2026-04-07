import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_account.dart';
import '../models/brokerage_event.dart';
import '../models/participated_event.dart';

class RecommendedEvent {
  final BrokerageEvent event;
  final AccountType reason; // 어떤 계좌 타입 때문에 추천됐는지

  const RecommendedEvent({required this.event, required this.reason});
}

class UserAccountsProvider extends ChangeNotifier {
  static const _key = 'user_accounts';

  List<UserAccount> _accounts = [];
  List<UserAccount> get accounts => List.unmodifiable(_accounts);
  bool get hasAccounts => _accounts.isNotEmpty;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      final list = jsonDecode(raw) as List;
      _accounts = list
          .map((e) => UserAccount.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode(_accounts.map((e) => e.toJson()).toList()));
  }

  Future<void> addAccount(AccountType type, BrokerageType brokerage) async {
    if (_accounts.any((a) => a.type == type && a.brokerage == brokerage)) {
      return; // 중복 방지
    }
    _accounts.add(UserAccount(
      id: '${type.name}_${brokerage.toString()}',
      type: type,
      brokerage: brokerage,
    ));
    await _save();
    notifyListeners();
  }

  Future<void> removeAccount(String id) async {
    _accounts.removeWhere((a) => a.id == id);
    await _save();
    notifyListeners();
  }

  List<UserAccount> accountsOfType(AccountType type) =>
      _accounts.where((a) => a.type == type).toList();

  /// 계좌 정보 기반 추천 이벤트 목록
  /// - ISA/IRP/개인연금/RIA: 현재 보유 증권사 제외, 해당 카테고리 진행 이벤트
  /// - 일반 주거래: 현재 보유 증권사 제외, 순입금 관련 이벤트
  /// - 참여 후 수령 전 계좌 종류는 해당 카테고리 전체 추천에서 제외
  List<RecommendedEvent> getRecommendations(
    List<BrokerageEvent> allEvents, {
    List<ParticipatedEvent> participatedEvents = const [],
  }) {
    if (_accounts.isEmpty) return [];

    // 수령 전(미완료) 참여 이벤트의 카테고리 → 해당 계좌 종류 전체 제외
    final excludedCategories = <EventCategory>{};
    for (final p in participatedEvents) {
      if (!p.isCompleted) {
        excludedCategories.add(p.category);
      }
    }

    final active = allEvents.where((e) => e.isActive).toList();
    final result = <RecommendedEvent>[];
    final seen = <String>{};

    void add(BrokerageEvent event, AccountType reason) {
      final key = '${reason.name}_${event.id}';
      if (seen.add(key)) {
        result.add(RecommendedEvent(event: event, reason: reason));
      }
    }

    // ISA / IRP / 개인연금 / RIA: 카테고리 매칭
    for (final type in [AccountType.isa, AccountType.irp, AccountType.pension, AccountType.ria]) {
      // 해당 계좌 종류로 참여 후 수령 대기중이면 전체 스킵
      final categories = type.matchingCategories!;
      if (categories.any((c) => excludedCategories.contains(c))) continue;

      final held = accountsOfType(type).map((a) => a.brokerage).toSet();
      if (held.isEmpty) continue;

      for (final e in active) {
        if (categories.contains(e.category) && !held.contains(e.brokerage)) {
          add(e, type);
        }
      }
    }

    // 일반 주거래: 순입금 이벤트 (title/description에 "입금" 포함)
    final generalHeld =
        accountsOfType(AccountType.general).map((a) => a.brokerage).toSet();
    if (generalHeld.isNotEmpty) {
      const excludeKeywords = ['ISA', 'IRP', '연금', 'DC'];
      for (final e in active) {
        if (!generalHeld.contains(e.brokerage)) {
          final text = e.title + e.description;
          final hasDeposit =
              text.contains('입금') || text.contains('순입금');
          final hasExcluded =
              excludeKeywords.any((kw) => text.contains(kw));
          if (hasDeposit && !hasExcluded) {
            add(e, AccountType.general);
          }
        }
      }
    }

    return result;
  }
}
