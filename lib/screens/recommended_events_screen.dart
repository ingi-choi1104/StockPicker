import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_account.dart';
import '../providers/events_provider.dart';
import '../providers/user_accounts_provider.dart';
import '../widgets/event_card.dart';
import 'event_detail_screen.dart';
import 'account_registration_screen.dart';

class RecommendedEventsScreen extends StatelessWidget {
  const RecommendedEventsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('추천 이벤트'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const AccountRegistrationScreen()),
            ),
            child: const Text('계좌 관리'),
          ),
        ],
      ),
      body: Consumer2<UserAccountsProvider, EventsProvider>(
        builder: (context, accountsProvider, eventsProvider, _) {
          if (!accountsProvider.hasAccounts) {
            return _EmptyAccounts(
              onRegister: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const AccountRegistrationScreen()),
              ),
            );
          }

          final allEvents = eventsProvider.allEvents;
          final recommendations = accountsProvider.getRecommendations(allEvents);

          if (recommendations.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_outline,
                      size: 64, color: Colors.green[300]),
                  const SizedBox(height: 16),
                  Text(
                    '현재 추천할 이벤트가 없습니다',
                    style: TextStyle(fontSize: 15, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '다른 증권사에서 관련 이벤트가 시작되면 알려드릴게요',
                    style: TextStyle(fontSize: 13, color: Colors.grey[400]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          // AccountType별로 그룹핑
          final grouped = <AccountType, List<_Item>>{};
          for (final rec in recommendations) {
            grouped.putIfAbsent(rec.reason, () => []);
            grouped[rec.reason]!.add(_Item(rec));
          }

          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 12),
            children: [
              for (final type in AccountType.values)
                if (grouped.containsKey(type)) ...[
                  _SectionHeader(
                    type: type,
                    heldBrokerages: accountsProvider
                        .accountsOfType(type)
                        .map((a) => a.brokerage.name)
                        .join(', '),
                  ),
                  ...grouped[type]!.map(
                    (item) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: EventCard(
                        event: item.rec.event,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                EventDetailScreen(event: item.rec.event),
                          ),
                        ),
                        onBookmark: () => eventsProvider
                            .toggleBookmark(item.rec.event.id),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
            ],
          );
        },
      ),
    );
  }
}

class _Item {
  final dynamic rec;
  _Item(this.rec);
}

// ─── 섹션 헤더 ───────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final AccountType type;
  final String heldBrokerages;

  const _SectionHeader(
      {required this.type, required this.heldBrokerages});

  @override
  Widget build(BuildContext context) {
    final color = Color(type.color);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              type.label,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '현재: $heldBrokerages',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 계좌 미등록 안내 ─────────────────────────────────────────────
class _EmptyAccounts extends StatelessWidget {
  final VoidCallback onRegister;
  const _EmptyAccounts({required this.onRegister});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.account_balance_outlined,
              size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            '등록된 계좌가 없습니다',
            style: TextStyle(fontSize: 15, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            '보유 계좌를 등록하면 맞춤 이벤트를 추천해드려요',
            style: TextStyle(fontSize: 13, color: Colors.grey[400]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onRegister,
            icon: const Icon(Icons.add),
            label: const Text('계좌 등록하기'),
          ),
        ],
      ),
    );
  }
}
