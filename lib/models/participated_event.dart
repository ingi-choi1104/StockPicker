import 'brokerage_event.dart';

/// 경품 종류 선택지
const List<String> kPrizeTypes = [
  '현금',
  '신세계상품권',
  '롯데상품권',
  '현대상품권',
  'CU상품권',
  'GS상품권',
  'SSG머니',
  '기타',
];

class ParticipatedEvent {
  final String id;
  final String eventId;
  final String eventTitle;
  final BrokerageType brokerage;
  final EventCategory category;
  // 구조화된 경품 (신규)
  final String? prizeType;
  final int? prizeAmount;
  // 레거시 텍스트 (구버전 데이터 호환용)
  final String? prizeDescription;
  final DateTime participatedAt;
  final DateTime rewardDate;
  final DateTime? nextEligibleDate;

  const ParticipatedEvent({
    required this.id,
    required this.eventId,
    required this.eventTitle,
    required this.brokerage,
    required this.category,
    this.prizeType,
    this.prizeAmount,
    this.prizeDescription,
    required this.participatedAt,
    required this.rewardDate,
    this.nextEligibleDate,
  });

  /// 경품 표시 문자열 (종류 + 금액)
  String? get prizeDisplayText {
    if (prizeType != null || prizeAmount != null) {
      final parts = <String>[];
      if (prizeType != null) parts.add(prizeType!);
      if (prizeAmount != null) parts.add('${_fmt(prizeAmount!)}원');
      return parts.join(' ');
    }
    return prizeDescription; // 레거시 fallback
  }

  bool get hasPrize =>
      prizeType != null || prizeAmount != null || prizeDescription != null;

  bool get isCompleted => rewardDate.isBefore(DateTime.now());

  Map<String, dynamic> toJson() => {
        'id': id,
        'eventId': eventId,
        'eventTitle': eventTitle,
        'brokerage': brokerage.toString(),
        'category': category.toString(),
        'prizeType': prizeType,
        'prizeAmount': prizeAmount,
        'prizeDescription': prizeDescription,
        'participatedAt': participatedAt.toIso8601String(),
        'rewardDate': rewardDate.toIso8601String(),
        'nextEligibleDate': nextEligibleDate?.toIso8601String(),
      };

  factory ParticipatedEvent.fromJson(Map<String, dynamic> json) =>
      ParticipatedEvent(
        id: json['id'] as String,
        eventId: json['eventId'] as String,
        eventTitle: json['eventTitle'] as String,
        brokerage: BrokerageType.values
            .firstWhere((e) => e.toString() == json['brokerage']),
        category: json['category'] != null
            ? EventCategory.values.firstWhere(
                (e) => e.toString() == json['category'],
                orElse: () => EventCategory.other,
              )
            : EventCategory.other,
        prizeType: json['prizeType'] as String?,
        prizeAmount: json['prizeAmount'] as int?,
        prizeDescription: json['prizeDescription'] as String?,
        participatedAt: DateTime.parse(json['participatedAt'] as String),
        rewardDate: DateTime.parse(json['rewardDate'] as String),
        nextEligibleDate: json['nextEligibleDate'] != null
            ? DateTime.parse(json['nextEligibleDate'] as String)
            : null,
      );

  ParticipatedEvent copyWith({
    EventCategory? category,
    String? prizeType,
    int? prizeAmount,
    bool clearPrize = false,
    DateTime? participatedAt,
    DateTime? rewardDate,
    DateTime? nextEligibleDate,
    bool clearNextEligibleDate = false,
  }) =>
      ParticipatedEvent(
        id: id,
        eventId: eventId,
        eventTitle: eventTitle,
        brokerage: brokerage,
        category: category ?? this.category,
        prizeType: clearPrize ? null : prizeType ?? this.prizeType,
        prizeAmount: clearPrize ? null : prizeAmount ?? this.prizeAmount,
        prizeDescription: prizeDescription, // 레거시 유지
        participatedAt: participatedAt ?? this.participatedAt,
        rewardDate: rewardDate ?? this.rewardDate,
        nextEligibleDate: clearNextEligibleDate
            ? null
            : nextEligibleDate ?? this.nextEligibleDate,
      );
}

String _fmt(int amount) {
  final s = amount.toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}
