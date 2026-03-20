enum EventCategory {
  feeDiscount, // 수수료 혜택
  newAccount, // 신규 계좌 개설
  reward, // 적립금/리워드
  referral, // 추천인
  trading, // 매매 이벤트
  isa, // ISA
  irp, // IRP/퇴직연금
  pension, // 개인연금
  exchange, // 환율우대
  other, // 기타
}

enum BrokerageType {
  samsung, // 삼성증권
  miraeAsset, // 미래에셋증권
  kb, // KB증권
  koreaInvestment, // 한국투자증권
  nh, // NH투자증권
  kiwoom, // 키움증권
  shinhan, // 신한투자증권
  daeshin, // 대신증권
  meritz, // 메리츠증권
  hana, // 하나증권
}

extension BrokerageTypeExt on BrokerageType {
  String get name {
    switch (this) {
      case BrokerageType.samsung:
        return '삼성증권';
      case BrokerageType.miraeAsset:
        return '미래에셋증권';
      case BrokerageType.kb:
        return 'KB증권';
      case BrokerageType.koreaInvestment:
        return '한국투자증권';
      case BrokerageType.nh:
        return 'NH투자증권';
      case BrokerageType.kiwoom:
        return '키움증권';
      case BrokerageType.shinhan:
        return '신한투자증권';
      case BrokerageType.daeshin:
        return '대신증권';
      case BrokerageType.meritz:
        return '메리츠증권';
      case BrokerageType.hana:
        return '하나증권';
    }
  }

  String get logoUrl {
    switch (this) {
      case BrokerageType.samsung:
        return 'https://www.samsungsecurities.com/favicon.ico';
      case BrokerageType.miraeAsset:
        return 'https://www.miraeasset.com/favicon.ico';
      case BrokerageType.kb:
        return 'https://www.kbsec.com/favicon.ico';
      case BrokerageType.koreaInvestment:
        return 'https://www.truefriend.com/favicon.ico';
      case BrokerageType.nh:
        return 'https://www.nhqv.com/favicon.ico';
      case BrokerageType.kiwoom:
        return 'https://www.kiwoom.com/favicon.ico';
      case BrokerageType.shinhan:
        return 'https://www.shinhaninvest.com/favicon.ico';
      case BrokerageType.daeshin:
        return 'https://www.daishin.com/favicon.ico';
      case BrokerageType.meritz:
        return 'https://home.imeritz.com/favicon.ico';
      case BrokerageType.hana:
        return 'https://www.hanaw.com/favicon.ico';
    }
  }

  /// 증권사 앱 딥링크 스킴. 앱 미설치 시 canLaunchUrl = false → 웹사이트로 대체
  String? get appScheme {
    switch (this) {
      case BrokerageType.samsung:
        return 'mpop://'; // 삼성증권 mPOP
      case BrokerageType.miraeAsset:
        return 'miraeasset://'; // 미래에셋증권
      case BrokerageType.kb:
        return 'kbsec://'; // KB증권
      case BrokerageType.koreaInvestment:
        return 'trustmobile://'; // 한국투자증권
      case BrokerageType.nh:
        return 'nhqv://'; // NH투자증권
      case BrokerageType.kiwoom:
        return 'kiwoom://'; // 키움증권
      case BrokerageType.shinhan:
        return 'shinhansec://'; // 신한투자증권
      case BrokerageType.daeshin:
        return 'daishin://'; // 대신증권
      case BrokerageType.meritz:
        return 'meritz://'; // 메리츠증권
      case BrokerageType.hana:
        return 'hanaw://'; // 하나증권
    }
  }

  int get color {
    switch (this) {
      case BrokerageType.samsung:
        return 0xFF1428A0;
      case BrokerageType.miraeAsset:
        return 0xFFF18721; // 미래에셋 오렌지
      case BrokerageType.kb:
        return 0xFFFFD600;
      case BrokerageType.koreaInvestment:
        return 0xFF7A5C47;
      case BrokerageType.nh:
        return 0xFFE7C14A;
      case BrokerageType.kiwoom:
        return 0xFFD92B7C;
      case BrokerageType.shinhan:
        return 0xFF0046FF;
      case BrokerageType.daeshin:
        return 0xFF145A32;
      case BrokerageType.meritz:
        return 0xFFE8001B; // 메리츠 레드
      case BrokerageType.hana:
        return 0xFF009B77; // 하나 그린
    }
  }
}

extension EventCategoryExt on EventCategory {
  String get label {
    switch (this) {
      case EventCategory.feeDiscount:
        return '수수료 혜택';
      case EventCategory.newAccount:
        return '신규 계좌';
      case EventCategory.reward:
        return '적립금';
      case EventCategory.referral:
        return '추천인';
      case EventCategory.trading:
        return '매매 이벤트';
      case EventCategory.isa:
        return 'ISA';
      case EventCategory.irp:
        return 'IRP';
      case EventCategory.pension:
        return '개인연금';
      case EventCategory.exchange:
        return '환율우대';
      case EventCategory.other:
        return '기타';
    }
  }

  int get color {
    switch (this) {
      case EventCategory.feeDiscount:
        return 0xFF2196F3;
      case EventCategory.newAccount:
        return 0xFF4CAF50;
      case EventCategory.reward:
        return 0xFFFF9800;
      case EventCategory.referral:
        return 0xFF9C27B0;
      case EventCategory.trading:
        return 0xFFE91E63;
      case EventCategory.isa:
        return 0xFF00897B; // 틸
      case EventCategory.irp:
        return 0xFF7B1FA2; // 보라
      case EventCategory.pension:
        return 0xFF0288D1; // 하늘
      case EventCategory.exchange:
        return 0xFFF57C00; // 주황
      case EventCategory.other:
        return 0xFF607D8B;
    }
  }
}

class BrokerageEvent {
  final String id;
  final String title;
  final String description;
  final BrokerageType brokerage;
  final EventCategory category;
  final DateTime startDate;
  final DateTime? endDate;
  final String? eventUrl;
  final String? imageUrl;
  final List<String> benefits;
  final bool isBookmarked;
  final DateTime createdAt;

  const BrokerageEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.brokerage,
    required this.category,
    required this.startDate,
    this.endDate,
    this.eventUrl,
    this.imageUrl,
    this.benefits = const [],
    this.isBookmarked = false,
    required this.createdAt,
  });

  bool get isActive {
    final now = DateTime.now();
    if (endDate == null) return now.isAfter(startDate);
    return now.isAfter(startDate) && now.isBefore(endDate!);
  }

  int get daysLeft {
    if (endDate == null) return -1;
    return endDate!.difference(DateTime.now()).inDays;
  }

  factory BrokerageEvent.fromJson(Map<String, dynamic> json) {
    return BrokerageEvent(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      brokerage: BrokerageType.values.firstWhere(
        (e) => e.toString() == json['brokerage'],
      ),
      category: EventCategory.values.firstWhere(
        (e) => e.toString() == json['category'],
      ),
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: json['endDate'] != null
          ? DateTime.parse(json['endDate'] as String)
          : null,
      eventUrl: json['eventUrl'] as String?,
      imageUrl: json['imageUrl'] as String?,
      benefits: List<String>.from(json['benefits'] as List),
      isBookmarked: json['isBookmarked'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'brokerage': brokerage.toString(),
      'category': category.toString(),
      'startDate': startDate.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'eventUrl': eventUrl,
      'imageUrl': imageUrl,
      'benefits': benefits,
      'isBookmarked': isBookmarked,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  BrokerageEvent copyWith({bool? isBookmarked}) {
    return BrokerageEvent(
      id: id,
      title: title,
      description: description,
      brokerage: brokerage,
      category: category,
      startDate: startDate,
      endDate: endDate,
      eventUrl: eventUrl,
      imageUrl: imageUrl,
      benefits: benefits,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      createdAt: createdAt,
    );
  }
}
