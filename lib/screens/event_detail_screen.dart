import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/brokerage_event.dart';
import '../models/participated_event.dart';
import '../providers/events_provider.dart';
import '../providers/participated_events_provider.dart';

class EventDetailScreen extends StatelessWidget {
  final BrokerageEvent event;

  const EventDetailScreen({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final brokerageColor = Color(event.brokerage.color);
    final categoryColor = Color(event.category.color);

    return Consumer<EventsProvider>(
      builder: (context, provider, _) {
        final current = provider.events.firstWhere(
          (e) => e.id == event.id,
          orElse: () => event,
        );

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              // 헤더
              SliverAppBar(
                expandedHeight: 160,
                pinned: true,
                backgroundColor: brokerageColor,
                iconTheme: const IconThemeData(color: Colors.white),
                actions: [
                  IconButton(
                    icon: Icon(
                      current.isBookmarked ? Icons.bookmark : Icons.bookmark_outline,
                      color: Colors.white,
                    ),
                    onPressed: () => provider.toggleBookmark(event.id),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    color: brokerageColor,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Center(
                                      child: Text(
                                        event.brokerage.name[0],
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    event.brokerage.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 내용
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 카테고리 + 상태
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: categoryColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              event.category.label,
                              style: TextStyle(
                                color: categoryColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildStatusBadge(),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // 제목
                      Text(
                        event.title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 기간
                      _buildInfoRow(
                        Icons.calendar_today,
                        '이벤트 기간',
                        _formatDateRange(),
                      ),
                      if (event.isActive && event.daysLeft >= 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 4, left: 28),
                          child: Text(
                            event.daysLeft == 0 ? '오늘 마감!' : '${event.daysLeft}일 남음',
                            style: TextStyle(
                              color: event.daysLeft <= 3 ? Colors.red : Colors.orange[700],
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),

                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 16),

                      // 이벤트 설명
                      const Text(
                        '이벤트 안내',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        event.description,
                        style: const TextStyle(fontSize: 14, height: 1.6, color: Color(0xFF444444)),
                      ),

                      const SizedBox(height: 20),

                      // 혜택 목록
                      if (event.benefits.isNotEmpty) ...[
                        const Text(
                          '주요 혜택',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        ...event.benefits.map((benefit) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                margin: const EdgeInsets.only(top: 6),
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: brokerageColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  benefit,
                                  style: const TextStyle(fontSize: 14, height: 1.5),
                                ),
                              ),
                            ],
                          ),
                        )),
                      ],

                      const SizedBox(height: 30),

                      // 앱 열기 + 이벤트 페이지 버튼
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _openBrokerageApp(context),
                              icon: const Icon(Icons.smartphone),
                              label: Text('${event.brokerage.name} 앱'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: brokerageColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                          if (event.eventUrl != null) ...[
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _openEventUrl(context, event.eventUrl!),
                                icon: const Icon(Icons.open_in_browser),
                                label: const Text('이벤트 페이지'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: brokerageColor,
                                  side: BorderSide(color: brokerageColor),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),

                      const SizedBox(height: 12),

                      // 참여 기록 버튼
                      Consumer<ParticipatedEventsProvider>(
                        builder: (context, participatedProvider, _) {
                          final participated =
                              participatedProvider.hasParticipated(event.id);
                          return SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => _showParticipationDialog(
                                  context, participatedProvider),
                              icon: Icon(participated
                                  ? Icons.check_circle
                                  : Icons.add_task),
                              label: Text(participated
                                  ? '참여 기록 있음'
                                  : '참여 기록 남기기'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: participated
                                    ? Colors.green[700]
                                    : brokerageColor,
                                side: BorderSide(
                                  color: participated
                                      ? Colors.green
                                      : brokerageColor,
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge() {
    if (!event.isActive) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text('종료', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '진행중',
        style: TextStyle(fontSize: 12, color: Colors.green[700], fontWeight: FontWeight.w600),
      ),
    );
  }

  String _formatDateRange() {
    String format(DateTime dt) =>
        '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';

    if (event.endDate == null) return '${format(event.startDate)} ~';
    return '${format(event.startDate)} ~ ${format(event.endDate!)}';
  }

  Future<void> _showParticipationDialog(
      BuildContext context, ParticipatedEventsProvider provider) async {
    DateTime participatedAt = DateTime.now();
    DateTime rewardDate = DateTime.now().add(const Duration(days: 30));
    DateTime? nextEligibleDate;
    bool hasNextEligible = false;
    EventCategory selectedCategory = event.category;
    String? selectedPrizeType;
    // amountController는 GC에 의해 정리됨 — dispose() 호출 시 애니메이션 중 crash 발생
    final amountController = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            Future<DateTime?> pickDate(DateTime initial, String title) =>
                showDatePicker(
                  context: ctx,
                  initialDate: initial,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                  helpText: title,
                );

            String fmt(DateTime dt) =>
                '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';

            return AlertDialog(
              title: const Text('참여 기록 남기기'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 카테고리 선택
                    const Text('이벤트 종류',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: EventCategory.values.map((cat) {
                        final selected = cat == selectedCategory;
                        final color = Color(cat.color);
                        return GestureDetector(
                          onTap: () =>
                              setState(() => selectedCategory = cat),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: selected
                                  ? color
                                  : color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: selected
                                      ? color
                                      : color.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              cat.label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: selected ? Colors.white : color,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 4),
                    const Divider(),

                    // 참여일
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.how_to_reg),
                      title: const Text('참여일'),
                      subtitle: Text(fmt(participatedAt)),
                      onTap: () async {
                        final d =
                            await pickDate(participatedAt, '참여일 선택');
                        if (d != null) {
                          setState(() => participatedAt = d);
                        }
                      },
                    ),

                    // 경품 지급일
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.card_giftcard),
                      title: const Text('경품 지급일'),
                      subtitle: Text(fmt(rewardDate)),
                      onTap: () async {
                        final d =
                            await pickDate(rewardDate, '경품 지급일 선택');
                        if (d != null) setState(() => rewardDate = d);
                      },
                    ),

                    const Divider(),

                    // 경품 종류 선택
                    const Text('경품 종류 (선택)',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: kPrizeTypes.map((type) {
                        final selected = selectedPrizeType == type;
                        return GestureDetector(
                          onTap: () => setState(() =>
                              selectedPrizeType =
                                  selected ? null : type),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: selected
                                  ? Colors.orange[700]
                                  : Colors.orange.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: selected
                                      ? Colors.orange[700]!
                                      : Colors.orange.withValues(
                                          alpha: 0.3)),
                            ),
                            child: Text(
                              type,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: selected
                                    ? Colors.white
                                    : Colors.orange[800],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 10),

                    // 경품 금액
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        _ThousandsInputFormatter()
                      ],
                      decoration: InputDecoration(
                        labelText: '경품 금액 (원, 선택)',
                        hintText: '예: 30000',
                        prefixIcon:
                            const Icon(Icons.redeem, size: 20),
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 12),
                      ),
                      style: const TextStyle(fontSize: 13),
                    ),

                    // 다음 참여 가능일 (옵션)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('다음 참여 가능일'),
                      value: hasNextEligible,
                      onChanged: (v) => setState(() {
                        hasNextEligible = v;
                        nextEligibleDate = v
                            ? DateTime.now()
                                .add(const Duration(days: 90))
                            : null;
                      }),
                    ),
                    if (hasNextEligible && nextEligibleDate != null)
                      ListTile(
                        contentPadding: const EdgeInsets.only(left: 16),
                        leading: const Icon(Icons.event_repeat),
                        title: Text(fmt(nextEligibleDate!)),
                        onTap: () async {
                          final d = await pickDate(
                              nextEligibleDate!, '다음 참여 가능일 선택');
                          if (d != null) {
                            setState(() => nextEligibleDate = d);
                          }
                        },
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('취소'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final amtText = amountController.text.trim().replaceAll(',', '');
                    final amt =
                        amtText.isNotEmpty ? int.tryParse(amtText) : null;
                    final entry = ParticipatedEvent(
                      id: '${event.id}_${DateTime.now().millisecondsSinceEpoch}',
                      eventId: event.id,
                      eventTitle: event.title,
                      brokerage: event.brokerage,
                      category: selectedCategory,
                      prizeType: selectedPrizeType,
                      prizeAmount: amt,
                      participatedAt: participatedAt,
                      rewardDate: rewardDate,
                      nextEligibleDate: nextEligibleDate,
                    );
                    provider.add(entry);
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('참여 기록이 저장되었습니다')),
                    );
                  },
                  child: const Text('저장'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _openBrokerageApp(BuildContext context) async {
    final scheme = event.brokerage.appScheme;
    if (scheme != null) {
      final appUri = Uri.parse(scheme);
      if (await canLaunchUrl(appUri)) {
        await launchUrl(appUri, mode: LaunchMode.externalApplication);
        return;
      }
    }
    // 앱 미설치 → 이벤트 URL 또는 증권사 웹사이트 열기
    final fallback = event.eventUrl ?? event.brokerage.logoUrl
        .replaceAll('/favicon.ico', '');
    final fallbackUri = Uri.parse(fallback);
    if (await canLaunchUrl(fallbackUri)) {
      await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${event.brokerage.name} 앱 또는 웹사이트를 열 수 없습니다')),
      );
    }
  }

  Future<void> _openEventUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('브라우저를 열 수 없습니다')),
      );
    }
  }
}

class _ThousandsInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(',', '');
    if (digits.isEmpty) return newValue.copyWith(text: '');
    final n = int.tryParse(digits);
    if (n == null) return oldValue;
    final formatted = _fmt(n);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  String _fmt(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}
