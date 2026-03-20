import 'package:html/parser.dart' as html_parser;
import '../../models/brokerage_event.dart';
import 'base_scraper.dart';

/// 미래에셋증권 이벤트 스크래퍼 (SSR)
/// 구조: ul > li > a[href*="doView"] > img, h3, span.date
/// 페이지네이션: form GET (currentPage 파라미터)
class MiraeAssetScraper extends BaseScraper {
  @override
  BrokerageType get brokerageType => BrokerageType.miraeAsset;

  static const String _baseUrl = 'https://securities.miraeasset.com';
  static const String _listUrl = '$_baseUrl/hki/hki7000/r05.do';

  @override
  Future<List<BrokerageEvent>> scrape() async {
    final allEvents = <BrokerageEvent>[];
    int page = 1;

    while (true) {
      final url = page == 1 ? _listUrl : '$_listUrl?currentPage=$page';
      final events = await _fetchPage(url, page);
      if (events.isEmpty) break;

      allEvents.addAll(events);

      // 중복 없으면 계속, 20개 미만이면 마지막 페이지
      if (events.length < 12) break;
      if (page >= 5) break; // 최대 5페이지 (안전 제한)
      page++;
    }

    return allEvents;
  }

  Future<List<BrokerageEvent>> _fetchPage(String url, int page) async {
    try {
      final response = await get(url);
      if (response.statusCode != 200) return [];

      final document = html_parser.parse(response.body);

      // ul > li > a[href*="doView"] 구조
      final items = document.querySelectorAll('li:has(a[href*="doView"])');

      // querySelectorAll :has 미지원 시 대체
      final listItems = items.isNotEmpty
          ? items
          : document.querySelectorAll('ul li').where((li) {
              return li.querySelector('a[href*="doView"]') != null ||
                     li.querySelector('img') != null;
            }).toList();

      final events = <BrokerageEvent>[];

      for (var i = 0; i < listItems.length; i++) {
        final item = listItems[i];
        final link = item.querySelector('a');
        if (link == null) continue;

        // 이벤트 ID 추출: doView('202602005','1','')
        final href = link.attributes['href'] ?? '';
        final idMatch = RegExp(r"doView\('([^']+)'").firstMatch(href);
        final eventId = idMatch?.group(1) ?? '';

        // 제목
        final h3 = item.querySelector('h3');
        final title = h3?.text.trim() ??
            item.querySelector('strong, .tit, p.title')?.text.trim() ??
            '';
        if (title.isEmpty) continue;

        // 날짜
        final dateEl = item.querySelector('span.date, .date, .period');
        final dateText = dateEl?.text.trim() ?? '';
        final dateMatches = RegExp(r'\d{4}\.\d{2}\.\d{2}').allMatches(dateText).toList();
        final startDate = dateMatches.isNotEmpty
            ? parseDate(dateMatches.first.group(0)) ?? DateTime.now()
            : DateTime.now();
        final endDate = dateMatches.length > 1
            ? parseDate(dateMatches.last.group(0))
            : null;

        // 이미지
        final img = item.querySelector('img');
        String? imageUrl;
        if (img != null) {
          final src = img.attributes['src'] ?? '';
          imageUrl = src.startsWith('http') ? src : '$_baseUrl$src';
        }

        // alt 텍스트에 날짜가 포함된 경우 활용
        final alt = img?.attributes['alt'] ?? '';

        // 이벤트 URL
        String? eventUrl;
        if (eventId.isNotEmpty) {
          eventUrl = '$_baseUrl/hki/hki7000/r05.do?cmd=doView&eventId=$eventId';
        }

        events.add(BrokerageEvent(
          id: 'miraeasset_${eventId.isNotEmpty ? eventId : "${page}_$i"}',
          title: title,
          description: alt.isNotEmpty && alt != title ? alt : title,
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
    if (title.contains('수수료') || title.contains('할인') || title.contains('ISA')) return EventCategory.feeDiscount;
    if (title.contains('신규') || title.contains('계좌')) return EventCategory.newAccount;
    if (title.contains('추천') || title.contains('친구')) return EventCategory.referral;
    if (title.contains('적립') || title.contains('포인트') || title.contains('리워드')) return EventCategory.reward;
    if (title.contains('매매') || title.contains('거래') || title.contains('ETF')) return EventCategory.trading;
    return EventCategory.other;
  }
}
