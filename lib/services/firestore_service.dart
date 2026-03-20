import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/brokerage_event.dart';

class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  final _db = FirebaseFirestore.instance;
  static const String _collection = 'events';

  /// Firestore에서 전체 이벤트 조회
  Future<List<BrokerageEvent>> fetchEvents() async {
    final snapshot = await _db
        .collection(_collection)
        .get();

    return snapshot.docs
        .map((doc) => _fromDoc(doc))
        .whereType<BrokerageEvent>()
        .toList();
  }

  /// Firestore 데이터 유무 확인
  Future<bool> hasData() async {
    final snapshot = await _db
        .collection(_collection)
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  /// Firestore 문서 → BrokerageEvent 변환
  BrokerageEvent? _fromDoc(DocumentSnapshot doc) {
    try {
      final data = doc.data() as Map<String, dynamic>;

      final brokerageStr = data['brokerage'] as String? ?? '';
      final categoryStr = data['category'] as String? ?? '';

      final brokerage = BrokerageType.values.firstWhere(
        (e) => e.toString() == brokerageStr,
        orElse: () => BrokerageType.samsung, // unknown → 삼성 fallback
      );
      final category = EventCategory.values.firstWhere(
        (e) => e.toString() == categoryStr,
        orElse: () => EventCategory.other,
      );

      DateTime parseTs(dynamic val) {
        if (val is Timestamp) return val.toDate();
        if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
        return DateTime.now();
      }

      return BrokerageEvent(
        id: doc.id,
        title: data['title'] as String? ?? '',
        description: data['description'] as String? ?? '',
        brokerage: brokerage,
        category: category,
        startDate: parseTs(data['startDate']),
        endDate: data['endDate'] != null ? parseTs(data['endDate']) : null,
        eventUrl: data['eventUrl'] as String?,
        imageUrl: data['imageUrl'] as String?,
        benefits: List<String>.from(data['benefits'] as List? ?? []),
        createdAt: parseTs(data['createdAt']),
      );
    } catch (_) {
      return null;
    }
  }
}
