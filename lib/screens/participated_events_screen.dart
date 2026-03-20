import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/participated_event.dart';
import '../models/brokerage_event.dart';
import '../providers/participated_events_provider.dart';
import '../widgets/banner_ad_widget.dart';
import 'my_events_screen.dart';

class ParticipatedEventsScreen extends StatelessWidget {
  const ParticipatedEventsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('내가 참여한 이벤트'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: '간트 차트로 보기',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MyEventsScreen()),
            ),
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF5F7FA),
      body: Consumer<ParticipatedEventsProvider>(
        builder: (context, provider, _) {
          final events = provider.events;

          return Column(
            children: [
              // 올해 수령 금액 배너
              _YearSummaryBanner(total: provider.totalReceivedThisYear),

              // 이벤트 목록
              if (events.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.event_busy,
                            size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text('참여한 이벤트가 없습니다',
                            style: TextStyle(
                                color: Colors.grey[500], fontSize: 15)),
                        const SizedBox(height: 8),
                        Text('이벤트 상세 페이지에서 참여 기록을 남겨보세요',
                            style: TextStyle(
                                color: Colors.grey[400], fontSize: 13)),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 16),
                    itemCount: events.length,
                    itemBuilder: (context, index) =>
                        _ParticipatedEventCard(entry: events[index]),
                  ),
                ),
              const BannerAdWidget(),
            ],
          );
        },
      ),
    );
  }
}

// ─── 올해 수령 금액 배너 ─────────────────────────────────────────
class _YearSummaryBanner extends StatelessWidget {
  final int total;
  const _YearSummaryBanner({required this.total});

  @override
  Widget build(BuildContext context) {
    if (total == 0) return const SizedBox.shrink();
    final year = DateTime.now().year;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.account_balance_wallet_outlined,
              color: Colors.green[700], size: 22),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$year년 수령 경품',
                  style:
                      TextStyle(fontSize: 11, color: Colors.green[600])),
              Text(
                '${_fmtAmount(total)}원',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[700],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── 이벤트 카드 ─────────────────────────────────────────────────
class _ParticipatedEventCard extends StatelessWidget {
  final ParticipatedEvent entry;
  const _ParticipatedEventCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final brokerageColor = Color(entry.brokerage.color);
    final now = DateTime.now();
    final isCompleted = entry.isCompleted;
    final rewardPassed = isCompleted;
    final canParticipateAgain = entry.nextEligibleDate != null &&
        entry.nextEligibleDate!.isBefore(now);

    return Opacity(
      opacity: isCompleted ? 0.55 : 1.0,
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        color: isCompleted ? Colors.grey[100] : Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onLongPress: () => _confirmDelete(context),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 증권사 + 완료 뱃지 + 수정/삭제
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: brokerageColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Text(
                          entry.brokerage.name[0],
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      entry.brokerage.name,
                      style: TextStyle(
                          color: brokerageColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 13),
                    ),
                    const SizedBox(width: 6),
                    if (isCompleted)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('완료',
                            style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[700])),
                      ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(Icons.edit_outlined,
                          size: 18, color: Colors.grey[500]),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => _showEditDialog(context),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(Icons.delete_outline,
                          size: 18, color: Colors.grey[400]),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => _confirmDelete(context),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // 카테고리 태그
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Color(entry.category.color)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    entry.category.label,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(entry.category.color)),
                  ),
                ),
                const SizedBox(height: 6),

                // 이벤트 제목
                Text(
                  entry.eventTitle,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.3),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),

                // 경품 내용
                if (entry.hasPrize) ...[
                  Row(
                    children: [
                      Icon(Icons.redeem,
                          size: 15, color: Colors.grey[500]),
                      const SizedBox(width: 6),
                      Text('경품: ',
                          style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600])),
                      Expanded(
                        child: Text(
                          entry.prizeDisplayText ?? '',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],

                // 날짜 정보
                _dateRow(Icons.how_to_reg, '참여일',
                    entry.participatedAt),
                const SizedBox(height: 6),
                _dateRow(
                  Icons.card_giftcard,
                  '경품 지급일',
                  entry.rewardDate,
                  trailing: rewardPassed
                      ? _badge('수령 완료', Colors.green)
                      : _badge(
                          '${entry.rewardDate.difference(now).inDays + 1}일 후',
                          Colors.orange),
                ),
                if (entry.nextEligibleDate != null) ...[
                  const SizedBox(height: 6),
                  _dateRow(
                    Icons.event_repeat,
                    '다음 참여 가능일',
                    entry.nextEligibleDate!,
                    trailing: canParticipateAgain
                        ? _badge('참여 가능', Colors.blue)
                        : null,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dateRow(IconData icon, String label, DateTime date,
      {Widget? trailing}) {
    final formatted =
        '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
    return Row(
      children: [
        Icon(icon, size: 15, color: Colors.grey[500]),
        const SizedBox(width: 6),
        Text('$label: ',
            style: TextStyle(fontSize: 13, color: Colors.grey[600])),
        Text(formatted,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w500)),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          trailing,
        ],
      ],
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color)),
    );
  }

  // ─── 수정 다이얼로그 ─────────────────────────────────────────
  void _showEditDialog(BuildContext context) {
    DateTime participatedAt = entry.participatedAt;
    DateTime rewardDate = entry.rewardDate;
    DateTime? nextEligibleDate = entry.nextEligibleDate;
    bool hasNextEligible = entry.nextEligibleDate != null;
    EventCategory selectedCategory = entry.category;
    String? selectedPrizeType = entry.prizeType;
    final amountController = TextEditingController(
        text: entry.prizeAmount != null ? _fmtAmount(entry.prizeAmount!) : '');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
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
            title: const Text('참여 기록 수정'),
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
                      final sel = cat == selectedCategory;
                      final c = Color(cat.color);
                      return GestureDetector(
                        onTap: () =>
                            setState(() => selectedCategory = cat),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: sel ? c : c.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: sel
                                    ? c
                                    : c.withValues(alpha: 0.3)),
                          ),
                          child: Text(cat.label,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: sel ? Colors.white : c)),
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
                      if (d != null) {
                        setState(() => rewardDate = d);
                      }
                    },
                  ),

                  // 경품 종류 선택
                  const Text('경품 종류',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: kPrizeTypes.map((type) {
                      final sel = type == selectedPrizeType;
                      return GestureDetector(
                        onTap: () => setState(() =>
                            selectedPrizeType =
                                sel ? null : type),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: sel
                                ? Colors.blueGrey[700]
                                : Colors.grey[100],
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: sel
                                    ? Colors.blueGrey.shade700
                                    : Colors.grey.shade300),
                          ),
                          child: Text(type,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: sel
                                      ? Colors.white
                                      : Colors.grey[700])),
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
                      labelText: '경품 금액 (선택)',
                      suffixText: '원',
                      prefixIcon:
                          const Icon(Icons.monetization_on, size: 20),
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
                  const SizedBox(height: 4),

                  // 다음 참여 가능일
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('다음 참여 가능일'),
                    value: hasNextEligible,
                    onChanged: (v) => setState(() {
                      hasNextEligible = v;
                      nextEligibleDate = v
                          ? (entry.nextEligibleDate ??
                              DateTime.now()
                                  .add(const Duration(days: 90)))
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
                      amtText.isEmpty ? null : int.tryParse(amtText);
                  context.read<ParticipatedEventsProvider>().update(
                        entry.copyWith(
                          category: selectedCategory,
                          prizeType: selectedPrizeType,
                          prizeAmount: amt,
                          clearPrize: selectedPrizeType == null &&
                              amt == null,
                          participatedAt: participatedAt,
                          rewardDate: rewardDate,
                          nextEligibleDate: nextEligibleDate,
                          clearNextEligibleDate: !hasNextEligible,
                        ),
                      );
                  Navigator.pop(ctx);
                },
                child: const Text('저장'),
              ),
            ],
          );
        },
      ),
    );
    // TextEditingController는 GC에 의해 정리됨
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('참여 기록 삭제'),
        content: const Text('이 참여 기록을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              context
                  .read<ParticipatedEventsProvider>()
                  .remove(entry.id);
              Navigator.pop(ctx);
            },
            child: const Text('삭제',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
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
    final formatted = _fmtAmount(n);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

String _fmtAmount(int amount) {
  final s = amount.toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}
