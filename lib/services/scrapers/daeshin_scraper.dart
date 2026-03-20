import 'package:html/parser.dart' as html_parser;
import '../../models/brokerage_event.dart';
import 'base_scraper.dart';

/// 대신증권 이벤트 스크래퍼 (SSR, 완전 파싱 가능)
/// 구조: <a href="eventDetail.ds?...cid=N"> > img + p(제목) + p(설명) + p(기간|조회수)
class DaeshinScraper extends BaseScraper {
  @override
  BrokerageType get brokerageType => BrokerageType.daeshin;

  static const String _baseUrl = 'https://www.daishin.com';
  static const String _url = '$_baseUrl/g.ds?m=1109&p=12931&v=12831';

  @override
  Future<List<BrokerageEvent>> scrape() async {
    try {
      final response = await get(_url);
      if (response.statusCode != 200) return [];

      final document = html_parser.parse(response.body);

      // 이벤트 항목: a[href*="eventDetail.ds"] 각각이 하나의 이벤트
      final links = document.querySelectorAll('a[href*="eventDetail.ds"]');
      final events = <BrokerageEvent>[];
      final seenIds = <String>{};

      for (var i = 0; i < links.length; i++) {
        final link = links[i];
        final href = link.attributes['href'] ?? '';

        // cid 추출 (중복 방지)
        final cidMatch = RegExp(r'cid=(\d+)').firstMatch(href);
        final cid = cidMatch?.group(1) ?? '$i';
        if (!seenIds.add(cid)) continue; // 중복 링크 스킵

        final img = link.querySelector('img');
        String? imageUrl;
        if (img != null) {
          final src = img.attributes['src'] ?? '';
          if (src.contains('/attach/event_image/')) {
            imageUrl = src.startsWith('http') ? src : '$_baseUrl$src';
          }
        }

        // <p> 태그들: 순서대로 제목, 설명, 기간
        final paragraphs = link.querySelectorAll('p');
        final title = paragraphs.isNotEmpty ? paragraphs[0].text.trim() : '';
        if (title.isEmpty) continue;

        final description = paragraphs.length > 1 ? paragraphs[1].text.trim() : '';
        final dateRaw = paragraphs.length > 2 ? paragraphs[2].text.trim() : '';

        // 기간 파싱: "2026.01.02 ~ 2026.12.31 조회수 : 337,914"
        final dateMatches = RegExp(r'\d{4}\.\d{2}\.\d{2}').allMatches(dateRaw).toList();
        final startDate = dateMatches.isNotEmpty
            ? parseDate(dateMatches.first.group(0)) ?? DateTime.now()
            : DateTime.now();
        final endDate = dateMatches.length > 1
            ? parseDate(dateMatches.last.group(0))
            : null;

        final eventUrl = href.startsWith('http') ? href : '$_baseUrl$href';

        events.add(BrokerageEvent(
          id: 'daeshin_$cid',
          title: title,
          description: description.isNotEmpty ? description : title,
          brokerage: brokerageType,
          category: _guessCategory(title),
          startDate: startDate,
          endDate: endDate,
          eventUrl: eventUrl,
          imageUrl: imageUrl,
          benefits: const [],
          createdAt: DateTime.now(),
        ));
      }

      return events;
    } catch (_) {
      return [];
    }
  }

  EventCategory _guessCategory(String title) {
    if (title.contains('수수료') || title.contains('할인') || title.contains('우대')) return EventCategory.feeDiscount;
    if (title.contains('신규') || title.contains('계좌')) return EventCategory.newAccount;
    if (title.contains('추천') || title.contains('친구')) return EventCategory.referral;
    if (title.contains('적립') || title.contains('포인트') || title.contains('리워드')) return EventCategory.reward;
    if (title.contains('매매') || title.contains('거래') || title.contains('ETF')) return EventCategory.trading;
    return EventCategory.other;
  }
}
