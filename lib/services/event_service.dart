import '../models/brokerage_event.dart';
import 'cache_service.dart';
import 'firestore_service.dart';
import 'scrapers/samsung_scraper.dart';
import 'scrapers/miraeasset_scraper.dart';
import 'scrapers/koreainvestment_scraper.dart';
import 'scrapers/nh_scraper.dart';
import 'scrapers/kiwoom_scraper.dart';
import 'scrapers/shinhan_scraper.dart';
import 'scrapers/daeshin_scraper.dart';

class EventService {
  static final EventService _instance = EventService._internal();
  factory EventService() => _instance;
  EventService._internal();

  final _cache = CacheService();
  final _firestore = FirestoreService();

  final _scrapers = [
    SamsungScraper(),
    MiraeAssetScraper(),
    KoreaInvestmentScraper(),
    NhScraper(),
    KiwoomScraper(),
    ShinhanScraper(),
    DaeshinScraper(),
  ];

  /// 앱 시작 시 호출 — 캐시를 건너뛰고 Firestore 우선 조회.
  /// Firestore 실패 시 캐시 → 직접 스크래핑 → 목업 순으로 폴백.
  Future<FetchResult> fetchFromServer() async {
    try {
      final firestoreEvents = await _firestore.fetchEvents();
      if (firestoreEvents.isNotEmpty) {
        await _cache.saveToCache(firestoreEvents);
        return FetchResult(
          events: firestoreEvents,
          source: DataSource.firestore,
          lastFetchedAt: DateTime.now(),
        );
      }
    } catch (_) {}

    // Firestore 실패 → 캐시 fallback
    final cached = await _cache.loadFromCache();
    if (cached != null && cached.isNotEmpty) {
      return FetchResult(
        events: cached,
        source: DataSource.cache,
        lastFetchedAt: await _cache.getLastFetchedTime(),
      );
    }

    // 캐시도 없으면 직접 스크래핑
    final scraped = await _runScrapers();
    if (scraped.isNotEmpty) {
      await _cache.saveToCache(scraped);
      return FetchResult(
        events: scraped,
        source: DataSource.live,
        lastFetchedAt: DateTime.now(),
      );
    }

    return FetchResult(
      events: _fallbackEvents,
      source: DataSource.fallback,
      lastFetchedAt: null,
    );
  }

  /// 이벤트 조회 우선순위:
  /// 1. 로컬 캐시 (24시간 TTL)
  /// 2. Firestore (Cloud Functions가 수집한 최신 데이터)
  /// 3. 직접 스크래핑
  /// 4. 만료된 캐시
  /// 5. 목업 데이터
  Future<FetchResult> fetchEvents({bool forceRefresh = false}) async {
    // 1. Firestore 시도 (강제 새로고침이 아닐 때 + 캐시 만료됐을 때)
    if (!forceRefresh && await _cache.isCacheValid()) {
      final cached = await _cache.loadFromCache();
      if (cached != null && cached.isNotEmpty) {
        return FetchResult(
          events: cached,
          source: DataSource.cache,
          lastFetchedAt: await _cache.getLastFetchedTime(),
        );
      }
    }

    // 2. Firestore에서 조회
    try {
      final firestoreEvents = await _firestore.fetchEvents();
      if (firestoreEvents.isNotEmpty) {
        await _cache.saveToCache(firestoreEvents);
        return FetchResult(
          events: firestoreEvents,
          source: DataSource.firestore,
          lastFetchedAt: DateTime.now(),
        );
      }
    } catch (_) {}

    // 3. 직접 스크래핑 (Firestore 데이터 없을 때)
    final scraped = await _runScrapers();
    if (scraped.isNotEmpty) {
      await _cache.saveToCache(scraped);
      return FetchResult(
        events: scraped,
        source: DataSource.live,
        lastFetchedAt: DateTime.now(),
      );
    }

    // 4. 만료된 캐시
    final staleCache = await _cache.loadFromCache();
    if (staleCache != null && staleCache.isNotEmpty) {
      return FetchResult(
        events: staleCache,
        source: DataSource.staleCache,
        lastFetchedAt: await _cache.getLastFetchedTime(),
      );
    }

    // 5. 목업
    return FetchResult(
      events: _fallbackEvents,
      source: DataSource.fallback,
      lastFetchedAt: null,
    );
  }

  /// 모든 스크래퍼를 병렬로 실행
  Future<List<BrokerageEvent>> _runScrapers() async {
    final futures = _scrapers.map((s) => s.scrape());
    final results = await Future.wait(futures, eagerError: false);
    return results.expand((list) => list).toList();
  }

  // ===== 폴백 목업 데이터 (스크래핑 완전 실패 시 사용) =====
  static final List<BrokerageEvent> _fallbackEvents = [
    BrokerageEvent(
      id: 'fallback_001',
      title: '[오프라인] 삼성증권 신규 계좌 개설 이벤트',
      description: '삼성증권 앱에서 확인하세요.',
      brokerage: BrokerageType.samsung,
      category: EventCategory.newAccount,
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 12, 31),
      eventUrl: 'https://www.samsungpop.com',
      benefits: const ['신규 고객 전용 혜택'],
      createdAt: DateTime(2026, 1, 1),
    ),
    BrokerageEvent(
      id: 'fallback_002',
      title: '[오프라인] 미래에셋증권 수수료 혜택 이벤트',
      description: '미래에셋증권 앱에서 확인하세요.',
      brokerage: BrokerageType.miraeAsset,
      category: EventCategory.feeDiscount,
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 12, 31),
      eventUrl: 'https://securities.miraeasset.com',
      benefits: const ['수수료 혜택 제공'],
      createdAt: DateTime(2026, 1, 1),
    ),
    BrokerageEvent(
      id: 'fallback_003',
      title: '[오프라인] 키움증권 이벤트',
      description: '키움증권 앱에서 확인하세요.',
      brokerage: BrokerageType.kiwoom,
      category: EventCategory.other,
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 12, 31),
      eventUrl: 'https://www.kiwoom.com',
      benefits: const ['다양한 혜택 제공'],
      createdAt: DateTime(2026, 1, 1),
    ),
  ];
}

enum DataSource { firestore, cache, live, staleCache, fallback }

class FetchResult {
  final List<BrokerageEvent> events;
  final DataSource source;
  final DateTime? lastFetchedAt;

  const FetchResult({
    required this.events,
    required this.source,
    this.lastFetchedAt,
  });

  String get sourceLabel {
    switch (source) {
      case DataSource.firestore:
        return '서버 수집';
      case DataSource.live:
        return '직접 수집';
      case DataSource.cache:
        return '캐시';
      case DataSource.staleCache:
        return '캐시 (만료)';
      case DataSource.fallback:
        return '기본 데이터';
    }
  }

  bool get isFromCache =>
      source == DataSource.cache || source == DataSource.staleCache;
}
