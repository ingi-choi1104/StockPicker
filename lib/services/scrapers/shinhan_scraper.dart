import 'dart:convert';
import 'package:html/parser.dart' as html_parser;
import '../../models/brokerage_event.dart';
import 'base_scraper.dart';

/// 신한투자증권 이벤트 스크래퍼
/// 1차: AJAX JSON 엔드포인트 시도
/// 2차: HTML 파싱
class ShinhanScraper extends BaseScraper {
  @override
  BrokerageType get brokerageType => BrokerageType.shinhan;

  static const String _baseUrl = 'https://www.shinhansec.com';
  static const String _htmlUrl =
      '$_baseUrl/siw/customer-center/event/giEventView/view.do';

  // 신한 AJAX 후보 엔드포인트들
  static const List<String> _ajaxCandidates = [
    '$_baseUrl/siw/customer-center/event/giEventView/getList.do',
    '$_baseUrl/siw/customer-center/event/getEventList.do',
    '$_baseUrl/siw/event/getList.do',
  ];

  @override
  Future<List<BrokerageEvent>> scrape() async {
    // 1차: AJAX 시도
    for (final url in _ajaxCandidates) {
      final result = await _tryAjax(url);
      if (result.isNotEmpty) return result;
    }
    // 2차: HTML 파싱
    return _tryHtml();
  }

  Future<List<BrokerageEvent>> _tryAjax(String url) async {
    try {
      final response = await get(url, headers: {
        ...BaseScraper.jsonHeaders,
        'Referer': _htmlUrl,
      });
      if (response.statusCode != 200) return [];

      final json = jsonDecode(response.body);
      final List? list = json['list'] ?? json['data'] ?? json['eventList'] ?? json['result'];
      if (list == null || list.isEmpty) return [];

      return list.asMap().entries.map((entry) {
        final i = entry.key;
        final item = entry.value as Map<String, dynamic>;
        final title = (item['eventNm'] ?? item['title'] ?? item['evtNm'] ?? item['evntTitle'] ?? '').toString().trim();
        if (title.isEmpty) return null;

        final startDate = parseDate(
          item['startDate']?.toString() ?? item['strtDt']?.toString() ?? item['evtStDt']?.toString(),
        ) ?? DateTime.now();
        final endDate = parseDate(
          item['endDate']?.toString() ?? item['endDt']?.toString() ?? item['evtEdDt']?.toString(),
        );
        final imgSrc = item['imgUrl']?.toString() ?? item['listImgUrl']?.toString() ?? item['thumbnail']?.toString();
        String? imageUrl;
        if (imgSrc != null && imgSrc.isNotEmpty) {
          imageUrl = imgSrc.startsWith('http') ? imgSrc : '$_baseUrl$imgSrc';
        }
        final linkUrl = item['linkUrl']?.toString() ?? item['url']?.toString();
        String? eventUrl;
        if (linkUrl != null && linkUrl.isNotEmpty) {
          eventUrl = linkUrl.startsWith('http') ? linkUrl : '$_baseUrl$linkUrl';
        }

        return BrokerageEvent(
          id: 'shinhan_${item['eventSeq'] ?? item['evtSeq'] ?? i}',
          title: title,
          description: title,
          brokerage: brokerageType,
          category: guessCategory(title),
          startDate: startDate,
          endDate: endDate,
          eventUrl: eventUrl,
          imageUrl: imageUrl,
          benefits: const [],
          createdAt: DateTime.now(),
        );
      }).whereType<BrokerageEvent>().toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<BrokerageEvent>> _tryHtml() async {
    try {
      final response = await get(_htmlUrl);
      if (response.statusCode != 200) return [];

      final document = html_parser.parse(response.body);
      final events = <BrokerageEvent>[];

      // 다양한 선택자 시도
      final items = document.querySelectorAll(
        'ul.event-list > li, .event_list li, ul.evtList > li, .board_list tbody tr',
      );

      for (var i = 0; i < items.length; i++) {
        final item = items[i];
        final titleEl = item.querySelector('h3, h4, .tit, strong, a, .event-title');
        final title = titleEl?.text.trim() ?? '';
        if (title.isEmpty) continue;

        final href = item.querySelector('a')?.attributes['href'];
        String? eventUrl;
        if (href != null) {
          eventUrl = href.startsWith('http') ? href : '$_baseUrl$href';
        }

        final imgSrc = item.querySelector('img')?.attributes['src'];
        String? imageUrl;
        if (imgSrc != null) {
          imageUrl = imgSrc.startsWith('http') ? imgSrc : '$_baseUrl$imgSrc';
        }

        final dateText = item.querySelector('span.date, .date, .period')?.text.trim() ?? '';
        final dateMatches = RegExp(r'\d{4}[.\-]\d{2}[.\-]\d{2}').allMatches(dateText).toList();

        events.add(BrokerageEvent(
          id: 'shinhan_$i',
          title: title,
          description: title,
          brokerage: brokerageType,
          category: guessCategory(title),
          startDate: dateMatches.isNotEmpty
              ? parseDate(dateMatches.first.group(0)) ?? DateTime.now()
              : DateTime.now(),
          endDate: dateMatches.length > 1 ? parseDate(dateMatches.last.group(0)) : null,
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

}
