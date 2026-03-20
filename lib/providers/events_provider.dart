import 'package:flutter/foundation.dart';
import '../models/brokerage_event.dart';
import '../services/event_service.dart';

enum LoadingState { initial, loading, loaded, error }

enum SortOrder { deadline, brokerage, category }

extension SortOrderExt on SortOrder {
  String get label {
    switch (this) {
      case SortOrder.deadline:
        return '마감 임박순';
      case SortOrder.brokerage:
        return '증권사 순';
      case SortOrder.category:
        return '카테고리 순';
    }
  }
}

class EventsProvider extends ChangeNotifier {
  final EventService _service = EventService();

  List<BrokerageEvent> _allEvents = [];
  LoadingState _loadingState = LoadingState.initial;
  String? _errorMessage;
  FetchResult? _lastResult;

  // 필터 상태
  final Set<BrokerageType> _selectedBrokerages = {};
  final Set<EventCategory> _selectedCategories = {};
  bool _showActiveOnly = false;
  bool _showBookmarkedOnly = false;
  String _searchQuery = '';

  // 정렬
  SortOrder _sortOrder = SortOrder.deadline;

  // 북마크
  final Set<String> _bookmarkedIds = {};

  // Getters
  LoadingState get loadingState => _loadingState;
  String? get errorMessage => _errorMessage;
  Set<BrokerageType> get selectedBrokerages => Set.unmodifiable(_selectedBrokerages);
  Set<EventCategory> get selectedCategories => Set.unmodifiable(_selectedCategories);
  bool get showActiveOnly => _showActiveOnly;
  bool get showBookmarkedOnly => _showBookmarkedOnly;
  String get searchQuery => _searchQuery;
  FetchResult? get lastResult => _lastResult;
  SortOrder get sortOrder => _sortOrder;

  /// 마지막 수집 시각
  DateTime? get lastFetchedAt => _lastResult?.lastFetchedAt;

  /// 데이터 출처 라벨
  String get dataSourceLabel => _lastResult?.sourceLabel ?? '';

  List<BrokerageEvent> get events {
    return _allEvents.map((e) => e.copyWith(
      isBookmarked: _bookmarkedIds.contains(e.id),
    )).where((e) {
      if (_selectedBrokerages.isNotEmpty && !_selectedBrokerages.contains(e.brokerage)) return false;
      if (_selectedCategories.isNotEmpty && !_selectedCategories.contains(e.category)) return false;
      if (_showActiveOnly && !e.isActive) return false;
      if (_showBookmarkedOnly && !_bookmarkedIds.contains(e.id)) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        return e.title.toLowerCase().contains(q) ||
               e.description.toLowerCase().contains(q) ||
               e.brokerage.name.toLowerCase().contains(q) ||
               e.category.label.toLowerCase().contains(q);
      }
      return true;
    }).toList()
      ..sort((a, b) {
        switch (_sortOrder) {
          case SortOrder.deadline:
            if (a.endDate != null && b.endDate != null) {
              return a.endDate!.compareTo(b.endDate!);
            }
            if (a.endDate != null) return -1;
            if (b.endDate != null) return 1;
            return b.createdAt.compareTo(a.createdAt);
          case SortOrder.brokerage:
            final cmp = a.brokerage.name.compareTo(b.brokerage.name);
            if (cmp != 0) return cmp;
            if (a.endDate != null && b.endDate != null) {
              return a.endDate!.compareTo(b.endDate!);
            }
            return 0;
          case SortOrder.category:
            final cmp = a.category.label.compareTo(b.category.label);
            if (cmp != 0) return cmp;
            if (a.endDate != null && b.endDate != null) {
              return a.endDate!.compareTo(b.endDate!);
            }
            return 0;
        }
      });
  }

  /// 필터 미적용 목록 (북마크 상태 반영, 추천 로직에서 사용)
  List<BrokerageEvent> get allEvents => _allEvents
      .map((e) => e.copyWith(isBookmarked: _bookmarkedIds.contains(e.id)))
      .toList();

  int get activeEventCount => _allEvents.where((e) => e.isActive).length;
  int get bookmarkCount => _bookmarkedIds.length;

  /// 이벤트 로드 — 앱 시작 시 Firestore 우선 조회
  Future<void> loadEvents() async {
    _loadingState = LoadingState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _service.fetchFromServer();
      _allEvents = result.events;
      _lastResult = result;
      _loadingState = LoadingState.loaded;
    } catch (e) {
      _errorMessage = '이벤트를 불러오는 데 실패했습니다.';
      _loadingState = LoadingState.error;
    }

    notifyListeners();
  }

  /// 강제 새로고침 (실시간 스크래핑)
  Future<void> refreshEvents() async {
    _loadingState = LoadingState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _service.fetchEvents(forceRefresh: true);
      _allEvents = result.events;
      _lastResult = result;
      _loadingState = LoadingState.loaded;
    } catch (e) {
      _errorMessage = '새로고침에 실패했습니다.';
      _loadingState = LoadingState.error;
    }

    notifyListeners();
  }

  void toggleBrokerage(BrokerageType brokerage) {
    if (_selectedBrokerages.contains(brokerage)) {
      _selectedBrokerages.remove(brokerage);
    } else {
      _selectedBrokerages.add(brokerage);
    }
    notifyListeners();
  }

  void clearBrokerages() {
    _selectedBrokerages.clear();
    notifyListeners();
  }

  void toggleCategory(EventCategory category) {
    if (_selectedCategories.contains(category)) {
      _selectedCategories.remove(category);
    } else {
      _selectedCategories.add(category);
    }
    notifyListeners();
  }

  void clearCategories() {
    _selectedCategories.clear();
    notifyListeners();
  }

  void toggleActiveOnly() {
    _showActiveOnly = !_showActiveOnly;
    notifyListeners();
  }

  void toggleBookmarkedOnly() {
    _showBookmarkedOnly = !_showBookmarkedOnly;
    notifyListeners();
  }

  void setSortOrder(SortOrder order) {
    _sortOrder = order;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void toggleBookmark(String eventId) {
    if (_bookmarkedIds.contains(eventId)) {
      _bookmarkedIds.remove(eventId);
    } else {
      _bookmarkedIds.add(eventId);
    }
    notifyListeners();
  }

  void clearFilters() {
    _selectedBrokerages.clear();
    _selectedCategories.clear();
    _showActiveOnly = false;
    _showBookmarkedOnly = false;
    _searchQuery = '';
    notifyListeners();
  }

  bool get hasActiveFilters =>
      _selectedBrokerages.isNotEmpty ||
      _selectedCategories.isNotEmpty ||
      _showActiveOnly ||
      _showBookmarkedOnly ||
      _searchQuery.isNotEmpty;
}
