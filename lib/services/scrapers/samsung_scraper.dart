import 'dart:convert';
import 'package:html/parser.dart' as html_parser;
import '../../models/brokerage_event.dart';
import 'base_scraper.dart';

/// 삼성증권 이벤트 스크래퍼
/// GET https://www.samsungpop.com/mbw/customer/noticeEvent.do?cmd=getEventList
/// JSON 응답 필드: ntcTitle1, period, dateDiff, ImgFileNm, menuSeqNo, EtcConts5
class SamsungScraper extends BaseScraper {
  @override
  BrokerageType get brokerageType => BrokerageType.samsung;

  static const String _baseUrl = 'https://www.samsungpop.com';
  static const String _listUrl =
      '$_baseUrl/mbw/customer/noticeEvent.do?cmd=getEventList';
  static const int _pageSize = 50;

  @override
  Future<List<BrokerageEvent>> scrape() async {
    try {
      // 1페이지 먼저 → totalCount 확인 → 전체 페이지 병렬 fetch
      final first = await _fetchPage(1);
      if (first == null) return [];

      final total = first['totalCount'] as int? ?? 0;
      final List firstList = first['list'] as List? ?? [];
      if (firstList.isEmpty) return [];

      final totalPages = (total / _pageSize).ceil();
      List<dynamic> allItems = List.from(firstList);

      if (totalPages > 1) {
        final futures = List.generate(
          totalPages - 1,
          (i) => _fetchPage(i + 2),
        );
        final pages = await Future.wait(futures);
        for (final page in pages) {
          if (page != null) {
            allItems.addAll(page['list'] as List? ?? []);
          }
        }
      }

      return allItems.map((raw) {
        final item = raw as Map<String, dynamic>;

        final title = (item['ntcTitle1'] ?? '').toString().trim();
        if (title.isEmpty) return null;

        final menuSeqNo = item['menuSeqNo']?.toString() ?? '';
        final period = (item['period'] ?? '').toString(); // "2026-03-03 ~ 2026-04-17"
        final imgFileNm = (item['ImgFileNm'] ?? '').toString();
        final descHtml = (item['EtcConts5'] ?? item['Etcconts1'] ?? '').toString();

        // 기간 파싱
        final dates = RegExp(r'\d{4}-\d{2}-\d{2}').allMatches(period).toList();
        final startDate = dates.isNotEmpty
            ? parseDate(dates.first.group(0)) ?? DateTime.now()
            : DateTime.now();
        final endDate = dates.length > 1 ? parseDate(dates.last.group(0)) : null;

        // 이미지 URL
        final imageUrl = imgFileNm.isNotEmpty
            ? '$_baseUrl/common.do?cmd=down&saveKey=event.file&fileName=$imgFileNm&inlineYn=N'
            : null;

        // 이벤트 URL
        final eventUrl = menuSeqNo.isNotEmpty
            ? '$_baseUrl/mbw/customer/noticeEvent.do?cmd=ingView&menuSeqNo=$menuSeqNo'
            : null;

        // 설명: HTML 태그 제거
        final description = descHtml.isNotEmpty
            ? html_parser.parse(descHtml).body?.text.trim() ?? title
            : title;

        return BrokerageEvent(
          id: 'samsung_$menuSeqNo',
          title: title,
          description: description.length > 200 ? '${description.substring(0, 200)}...' : description,
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

  Future<Map<String, dynamic>?> _fetchPage(int page) async {
    try {
      final response = await get(
        '$_listUrl&pageNo=$page&pageSize=$_pageSize',
        headers: {
          ...BaseScraper.defaultHeaders,
          'Referer': '$_baseUrl/mbw/customer/noticeEvent.do?cmd=eventList',
        },
      );
      if (response.statusCode != 200) return null;
      final json = jsonDecode(response.body);
      if (json is! Map<String, dynamic>) return null;
      return json;
    } catch (_) {
      return null;
    }
  }

}
