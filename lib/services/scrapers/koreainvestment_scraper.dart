import '../../models/brokerage_event.dart';
import 'base_scraper.dart';

/// 한국투자증권 이벤트 스크래퍼
/// 현재 상태: 봇 탐지로 접근 차단됨 (alert + reload)
/// TODO: 우회 방법 확인 후 구현
class KoreaInvestmentScraper extends BaseScraper {
  @override
  BrokerageType get brokerageType => BrokerageType.koreaInvestment;

  @override
  Future<List<BrokerageEvent>> scrape() async => [];
}
