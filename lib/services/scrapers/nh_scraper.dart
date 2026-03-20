import '../../models/brokerage_event.dart';
import 'base_scraper.dart';

/// NH투자증권 이벤트 스크래퍼
/// 현재 상태: nhsec.com SPA 구조로 정적 HTTP 접근 불가 (404/JS 렌더링)
/// TODO: 올바른 API 엔드포인트 확인 후 구현
class NhScraper extends BaseScraper {
  @override
  BrokerageType get brokerageType => BrokerageType.nh;

  @override
  Future<List<BrokerageEvent>> scrape() async => [];
}
