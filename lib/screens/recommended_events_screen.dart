import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_account.dart';
import '../providers/events_provider.dart';
import '../providers/user_accounts_provider.dart';
import '../providers/participated_events_provider.dart';
import '../widgets/event_card.dart';
import 'event_detail_screen.dart';
import 'account_registration_screen.dart';

class RecommendedEventsScreen extends StatefulWidget {
  const RecommendedEventsScreen({super.key});

  @override
  State<RecommendedEventsScreen> createState() =>
      _RecommendedEventsScreenState();
}

class _RecommendedEventsScreenState extends State<RecommendedEventsScreen> {
  final Map<AccountType, bool> _expanded = {};

  bool _isExpanded(AccountType type) => _expanded[type] ?? true;

  void _toggle(AccountType type) {
    setState(() => _expanded[type] = !_isExpanded(type));
  }

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
      body: Consumer3<UserAccountsProvider, EventsProvider,
          ParticipatedEventsProvider>(
        builder: (context, accountsProvider, eventsProvider,
            participatedProvider, _) {
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
          final recommendations = accountsProvider.getRecommendations(
            allEvents,
            participatedEvents: participatedProvider.events,
          );

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
          final grouped = <AccountType, List<RecommendedEvent>>{};
          for (final rec in recommendations) {
            grouped.putIfAbsent(rec.reason, () => []);
            grouped[rec.reason]!.add(rec);
          }

          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 12),
            children: [
              for (final type in AccountType.values)
                if (grouped.containsKey(type)) ...[
                  _buildSectionHeader(
                    type: type,
                    count: grouped[type]!.length,
                    heldBrokerages: accountsProvider
                        .accountsOfType(type)
                        .map((a) => a.brokerage.name)
                        .join(', '),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    child: _isExpanded(type)
                        ? Column(
                            children: grouped[type]!
                                .map(
                                  (rec) => Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12),
                                    child: EventCard(
                                      event: rec.event,
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => EventDetailScreen(
                                              event: rec.event),
                                        ),
                                      ),
                                      onBookmark: () => eventsProvider
                                          .toggleBookmark(rec.event.id),
                                    ),
                                  ),
                                )
                                .toList(),
                          )
                        : const SizedBox(width: double.infinity, height: 0),
                  ),
                  const SizedBox(height: 8),
                ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader({
    required AccountType type,
    required int count,
    required String heldBrokerages,
  }) {
    final color = Color(type.color);
    final expanded = _isExpanded(type);
    return GestureDetector(
      onTap: () => _toggle(type),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
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
            Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '보유: $heldBrokerages',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            AnimatedRotation(
              turns: expanded ? 0.0 : 0.5,
              duration: const Duration(milliseconds: 200),
              child: Icon(Icons.expand_less,
                  size: 20, color: Colors.grey[400]),
            ),
          ],
        ),
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
