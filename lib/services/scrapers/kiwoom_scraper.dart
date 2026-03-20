import '../../models/brokerage_event.dart';
import 'base_scraper.dart';

/// 키움증권 이벤트 스크래퍼
/// 현재 상태: 세션/Referer 검증으로 외부 접근 차단됨 (403)
/// TODO: 세션 기반 접근 방법 확인 후 구현
class KiwoomScraper extends BaseScraper {
  @override
  BrokerageType get brokerageType => BrokerageType.kiwoom;

  @override
  Future<List<BrokerageEvent>> scrape() async => [];
}
