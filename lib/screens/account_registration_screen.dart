import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_account.dart';
import '../models/brokerage_event.dart';
import '../providers/user_accounts_provider.dart';
import '../widgets/banner_ad_widget.dart';

class AccountRegistrationScreen extends StatelessWidget {
  const AccountRegistrationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('내 계좌 관리'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: Consumer<UserAccountsProvider>(
        builder: (context, provider, _) {
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _infoCard(),
                    const SizedBox(height: 16),
                    ...AccountType.values.map(
                      (type) => _AccountSection(type: type, provider: provider),
                    ),
                  ],
                ),
              ),
              const BannerAdWidget(),
            ],
          );
        },
      ),
    );
  }

  Widget _infoCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Colors.blue[700], size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '현재 보유 계좌를 등록하면, 다른 증권사에서 진행 중인 관련 이벤트를 추천해 드려요.',
              style: TextStyle(fontSize: 13, color: Colors.blue[800]),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 계좌 타입별 섹션 ────────────────────────────────────────────
class _AccountSection extends StatelessWidget {
  final AccountType type;
  final UserAccountsProvider provider;

  const _AccountSection({required this.type, required this.provider});

  @override
  Widget build(BuildContext context) {
    final accounts = provider.accountsOfType(type);
    final color = Color(type.color);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    type.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    type.description,
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                TextButton.icon(
                  onPressed: () => _showAddDialog(context),
                  icon: Icon(Icons.add, size: 16, color: color),
                  label: Text('추가', style: TextStyle(fontSize: 13, color: color)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),

          if (accounts.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Text(
                '등록된 계좌가 없습니다',
                style: TextStyle(fontSize: 13, color: Colors.grey[400]),
              ),
            )
          else ...[
            const Divider(height: 1),
            ...accounts.map((acc) => _accountTile(context, acc, color)),
          ],
        ],
      ),
    );
  }

  Widget _accountTile(
      BuildContext context, UserAccount acc, Color color) {
    return ListTile(
      dense: true,
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Color(acc.brokerage.color),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            acc.brokerage.name[0],
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
      ),
      title: Text(
        acc.brokerage.name,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      trailing: IconButton(
        icon: Icon(Icons.close, size: 18, color: Colors.grey[400]),
        onPressed: () => provider.removeAccount(acc.id),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
      ),
    );
  }

  void _showAddDialog(BuildContext context) {
    final registered = provider
        .accountsOfType(type)
        .map((a) => a.brokerage)
        .toSet();
    final available = BrokerageType.values
        .where((b) => !registered.contains(b))
        .toList();

    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('모든 증권사 계좌가 이미 등록됐습니다')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.6,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: Text(
                    '${type.label} 계좌 증권사 선택',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                const Divider(height: 1),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      ...available.map(
                        (b) => ListTile(
                          leading: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Color(b.color),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Center(
                              child: Text(
                                b.name[0],
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14),
                              ),
                            ),
                          ),
                          title: Text(b.name),
                          onTap: () {
                            provider.addAccount(type, b);
                            Navigator.pop(ctx);
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
