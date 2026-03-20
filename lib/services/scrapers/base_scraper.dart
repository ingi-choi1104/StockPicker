import 'package:http/http.dart' as http;
import '../../models/brokerage_event.dart';

abstract class BaseScraper {
  BrokerageType get brokerageType;

  /// User-Agent: 일반 브라우저로 위장
  static const Map<String, String> defaultHeaders = {
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 10; SM-G973F) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language': 'ko-KR,ko;q=0.9',
    'Accept-Encoding': 'gzip, deflate, br',
    'Connection': 'keep-alive',
  };

  static const Map<String, String> jsonHeaders = {
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 10; SM-G973F) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
    'Accept': 'application/json, text/javascript, */*; q=0.01',
    'Accept-Language': 'ko-KR,ko;q=0.9',
    'X-Requested-With': 'XMLHttpRequest',
  };

  /// 스크래핑 실행. 실패 시 빈 리스트 반환
  Future<List<BrokerageEvent>> scrape();

  /// HTTP GET 요청 (타임아웃 10초)
  Future<http.Response> get(String url, {Map<String, String>? headers}) async {
    return http.get(
      Uri.parse(url),
      headers: headers ?? defaultHeaders,
    ).timeout(const Duration(seconds: 10));
  }

  /// HTTP POST 요청
  Future<http.Response> post(
    String url, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    return http.post(
      Uri.parse(url),
      headers: headers ?? defaultHeaders,
      body: body,
    ).timeout(const Duration(seconds: 10));
  }

  /// 날짜 파싱 (한국 증권사 공통 패턴)
  /// 예: "2026.03.31", "2026-03-31", "20260331"
  DateTime? parseDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final cleaned = raw.trim().replaceAll(RegExp(r'[^\d]'), '');
    if (cleaned.length < 8) return null;
    try {
      return DateTime(
        int.parse(cleaned.substring(0, 4)),
        int.parse(cleaned.substring(4, 6)),
        int.parse(cleaned.substring(6, 8)),
      );
    } catch (_) {
      return null;
    }
  }

  /// 이벤트 ID 생성 (증권사 코드 + 인덱스 + 타임스탬프)
  String makeId(int index) =>
      '${brokerageType.name.replaceAll(' ', '_')}_${index}_${DateTime.now().millisecondsSinceEpoch}';
}
