import 'brokerage_event.dart';

enum AccountType { isa, irp, pension, ria, general }

extension AccountTypeExt on AccountType {
  String get label {
    switch (this) {
      case AccountType.isa:
        return 'ISA';
      case AccountType.irp:
        return 'IRP';
      case AccountType.pension:
        return '개인연금';
      case AccountType.ria:
        return 'RIA';
      case AccountType.general:
        return '일반 주거래';
    }
  }

  String get description {
    switch (this) {
      case AccountType.isa:
        return '개인종합자산관리계좌';
      case AccountType.irp:
        return '개인형 퇴직연금';
      case AccountType.pension:
        return '개인연금';
      case AccountType.ria:
        return '로보어드바이저 투자일임';
      case AccountType.general:
        return '순입금 이벤트 탐색';
    }
  }

  int get color {
    switch (this) {
      case AccountType.isa:
        return 0xFF00897B;
      case AccountType.irp:
        return 0xFF7B1FA2;
      case AccountType.pension:
        return 0xFF0288D1;
      case AccountType.ria:
        return 0xFF5C6BC0;
      case AccountType.general:
        return 0xFF455A64;
    }
  }

  /// ISA/IRP/개인연금/RIA는 매칭 카테고리, 일반주거래는 null (키워드 매칭)
  List<EventCategory>? get matchingCategories {
    switch (this) {
      case AccountType.isa:
        return [EventCategory.isa];
      case AccountType.irp:
        return [EventCategory.irp];
      case AccountType.pension:
        return [EventCategory.pension];
      case AccountType.ria:
        return [EventCategory.ria];
      case AccountType.general:
        return null;
    }
  }
}

class UserAccount {
  final String id;
  final AccountType type;
  final BrokerageType brokerage;

  const UserAccount({
    required this.id,
    required this.type,
    required this.brokerage,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'brokerage': brokerage.toString(),
      };

  factory UserAccount.fromJson(Map<String, dynamic> json) {
    return UserAccount(
      id: json['id'] as String,
      type: AccountType.values.firstWhere((e) => e.name == json['type']),
      brokerage: BrokerageType.values.firstWhere(
        (e) => e.toString() == json['brokerage'],
      ),
    );
  }
}
