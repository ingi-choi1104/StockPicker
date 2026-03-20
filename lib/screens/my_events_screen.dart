import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/participated_event.dart';
import '../models/brokerage_event.dart';
import '../providers/participated_events_provider.dart';
import '../widgets/banner_ad_widget.dart';

class MyEventsScreen extends StatelessWidget {
  const MyEventsScreen({super.key});

  /// 오늘 기준 6개월 전 ~ 12개월 후 (총 19개월)
  static List<DateTime> _buildMonthRange() {
    final now = DateTime.now();
    return List.generate(
      19,
      (i) => DateTime(now.year, now.month - 6 + i),
    );
  }

  @override
  Widget build(BuildContext context) {
    final months = _buildMonthRange();
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: const Text('나의 이벤트'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      backgroundColor: const Color(0xFFF5F7FA),
      body: Consumer<ParticipatedEventsProvider>(
        builder: (context, provider, _) {
          final events = provider.events;
          final totalThisYear = provider.totalReceivedThisYear;
          if (events.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bar_chart, size: 60, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    '참여한 이벤트가 없습니다',
                    style: TextStyle(color: Colors.grey[500], fontSize: 14),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '이벤트 상세 페이지에서 참여 기록을 남겨보세요',
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                ],
              ),
            );
          }
          return Column(
            children: [
              _YearSummaryBanner(year: now.year, total: totalThisYear),
              Expanded(
                child: _GanttBody(events: events, months: months, today: now),
              ),
              const BannerAdWidget(),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Gantt body — month-based layout
// ─────────────────────────────────────────────────────────────────
class _GanttBody extends StatelessWidget {
  final List<ParticipatedEvent> events;
  final List<DateTime> months;
  final DateTime today;

  const _GanttBody({
    required this.events,
    required this.months,
    required this.today,
  });

  static const double monthWidth = 60.0;
  static const double labelWidth = 112.0;
  static const double headerHeight = 46.0;
  static const double rowHeight = 54.0;

  // 오늘 달이 months 리스트에서 몇 번째인가
  int get _todayColIdx => months.indexWhere(
        (m) => m.year == today.year && m.month == today.month,
      );

  @override
  Widget build(BuildContext context) {
    final double totalTimelineWidth = months.length * monthWidth;
    final int todayIdx = _todayColIdx;

    return LayoutBuilder(
      builder: (context, constraints) {
        // 라벨 제외 남은 너비
        final double viewWidth = constraints.maxWidth - labelWidth;

        return Column(
          children: [
            // ── 헤더 (고정) ──────────────────────────────────────
            SizedBox(
              height: headerHeight,
              child: Row(
                children: [
                  // 라벨 헤더
                  Container(
                    width: labelWidth,
                    height: headerHeight,
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      border: Border(
                        bottom: BorderSide(color: Colors.grey[300]!),
                        right: BorderSide(color: Colors.grey[200]!),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '이벤트',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  // 월 헤더 스크롤 (이벤트 행과 동기화)
                  SizedBox(
                    width: viewWidth,
                    height: headerHeight,
                    child: _SyncedHeaderScroll(
                      totalTimelineWidth: totalTimelineWidth,
                      viewWidth: viewWidth,
                      monthWidth: monthWidth,
                      months: months,
                      todayIdx: todayIdx,
                    ),
                  ),
                ],
              ),
            ),

            // ── 이벤트 행들 (세로 스크롤) ──────────────────────────
            Expanded(
              child: SingleChildScrollView(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 라벨 열 (고정)
                    SizedBox(
                      width: labelWidth,
                      child: Column(
                        children: events
                            .map((e) => _LabelCell(
                                  event: e,
                                  height: rowHeight,
                                ))
                            .toList(),
                      ),
                    ),
                    // 간트 바 열 (가로 스크롤)
                    SizedBox(
                      width: viewWidth,
                      child: _SyncedBarsScroll(
                        events: events,
                        months: months,
                        today: today,
                        todayIdx: todayIdx,
                        totalTimelineWidth: totalTimelineWidth,
                        viewWidth: viewWidth,
                        monthWidth: monthWidth,
                        rowHeight: rowHeight,
                        context: context,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// 헤더와 바 영역을 동기화하는 가로 스크롤 — 공유 컨트롤러 사용
// ─────────────────────────────────────────────────────────────────
class _SyncedHeaderScroll extends StatefulWidget {
  final double totalTimelineWidth;
  final double viewWidth;
  final double monthWidth;
  final List<DateTime> months;
  final int todayIdx;

  const _SyncedHeaderScroll({
    required this.totalTimelineWidth,
    required this.viewWidth,
    required this.monthWidth,
    required this.months,
    required this.todayIdx,
  });

  @override
  State<_SyncedHeaderScroll> createState() => _SyncedHeaderScrollState();
}

class _SyncedHeaderScrollState extends State<_SyncedHeaderScroll> {
  @override
  void initState() {
    super.initState();
    _GanttScrollSync.headerController ??= ScrollController();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _GanttScrollSync.headerController,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: SizedBox(
        width: widget.totalTimelineWidth,
        child: Row(
          children: widget.months.asMap().entries.map((entry) {
            final idx = entry.key;
            final m = entry.value;
            final isCurrent = idx == widget.todayIdx;
            return Container(
              width: widget.monthWidth,
              height: double.infinity,
              decoration: BoxDecoration(
                color: isCurrent
                    ? Colors.blue.withValues(alpha: 0.07)
                    : null,
                border: Border(
                  bottom: BorderSide(color: Colors.grey[300]!),
                  right: BorderSide(color: Colors.grey[200]!),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (m.month == 1 || idx == 0)
                    Text(
                      '${m.year}',
                      style: TextStyle(
                        fontSize: 9,
                        color: isCurrent
                            ? Colors.blue[600]
                            : Colors.grey[400],
                      ),
                    ),
                  Text(
                    '${m.month}월',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isCurrent
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isCurrent
                          ? Colors.blue[700]
                          : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// 공유 스크롤 컨트롤러 보관소
class _GanttScrollSync {
  static ScrollController? headerController;
}

// ─────────────────────────────────────────────────────────────────
// 이벤트 바 가로 스크롤 (헤더와 동기화)
// ─────────────────────────────────────────────────────────────────
class _SyncedBarsScroll extends StatefulWidget {
  final List<ParticipatedEvent> events;
  final List<DateTime> months;
  final DateTime today;
  final int todayIdx;
  final double totalTimelineWidth;
  final double viewWidth;
  final double monthWidth;
  final double rowHeight;
  final BuildContext context;

  const _SyncedBarsScroll({
    required this.events,
    required this.months,
    required this.today,
    required this.todayIdx,
    required this.totalTimelineWidth,
    required this.viewWidth,
    required this.monthWidth,
    required this.rowHeight,
    required this.context,
  });

  @override
  State<_SyncedBarsScroll> createState() => _SyncedBarsScrollState();
}

class _SyncedBarsScrollState extends State<_SyncedBarsScroll> {
  late ScrollController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = ScrollController();
    _GanttScrollSync.headerController ??= ScrollController();
    _ctrl.addListener(_syncHeader);
    // 현재 월(index 6)이 뷰 중앙에 오도록 초기 스크롤
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_ctrl.hasClients) return;
      final double centerOffset =
          widget.todayIdx * widget.monthWidth -
          widget.viewWidth / 2 +
          widget.monthWidth / 2;
      _ctrl.jumpTo(centerOffset.clamp(
          0.0, _ctrl.position.maxScrollExtent));
    });
  }

  void _syncHeader() {
    final hc = _GanttScrollSync.headerController;
    if (hc != null &&
        hc.hasClients &&
        hc.offset != _ctrl.offset) {
      hc.jumpTo(_ctrl.offset);
    }
  }

  @override
  void dispose() {
    _ctrl.removeListener(_syncHeader);
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _ctrl,
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: widget.totalTimelineWidth,
        child: Column(
          children: widget.events
              .map((e) => _GanttRow(
                    event: e,
                    months: widget.months,
                    today: widget.today,
                    todayIdx: widget.todayIdx,
                    monthWidth: widget.monthWidth,
                    rowHeight: widget.rowHeight,
                  ))
              .toList(),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// 라벨 셀
// ─────────────────────────────────────────────────────────────────
class _LabelCell extends StatelessWidget {
  final ParticipatedEvent event;
  final double height;

  const _LabelCell({required this.event, required this.height});

  @override
  Widget build(BuildContext context) {
    final color = Color(event.brokerage.color);
    return Container(
      height: height,
      padding: const EdgeInsets.fromLTRB(8, 6, 4, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey[100]!),
          right: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                    color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  event.brokerage.name,
                  style: TextStyle(
                      fontSize: 10,
                      color: color,
                      fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            event.eventTitle,
            style: const TextStyle(fontSize: 11, height: 1.2),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// 개별 간트 행
// ─────────────────────────────────────────────────────────────────
class _GanttRow extends StatelessWidget {
  final ParticipatedEvent event;
  final List<DateTime> months;
  final DateTime today;
  final int todayIdx;
  final double monthWidth;
  final double rowHeight;

  const _GanttRow({
    required this.event,
    required this.months,
    required this.today,
    required this.todayIdx,
    required this.monthWidth,
    required this.rowHeight,
  });

  @override
  Widget build(BuildContext context) {
    final color = Color(event.brokerage.color);
    final firstMonth = months.first;
    final lastMonth = months.last;

    final startMonth =
        DateTime(event.participatedAt.year, event.participatedAt.month);
    final endMonth =
        DateTime(event.rewardDate.year, event.rewardDate.month);

    // 범위 밖 이벤트: 빈 행
    if (endMonth.isBefore(firstMonth) || startMonth.isAfter(lastMonth)) {
      return Container(
        height: rowHeight,
        color: Colors.white,
        child: const SizedBox.expand(),
      );
    }

    final bool clippedLeft = startMonth.isBefore(firstMonth);
    final bool clippedRight = endMonth.isAfter(lastMonth);

    int startIdx = clippedLeft
        ? 0
        : months.indexWhere(
            (m) => m.year == startMonth.year && m.month == startMonth.month);
    int endIdx = clippedRight
        ? months.length - 1
        : months.indexWhere(
            (m) => m.year == endMonth.year && m.month == endMonth.month);

    if (startIdx < 0) startIdx = 0;
    if (endIdx < 0) endIdx = months.length - 1;

    final double barLeft = startIdx * monthWidth;
    final double barWidth =
        ((endIdx - startIdx + 1) * monthWidth).clamp(4.0, double.infinity);

    // 오늘 선 위치 (오늘 달 안에서 일 비율)
    final double todayLineLeft = todayIdx >= 0
        ? todayIdx * monthWidth +
            (today.day / _daysInMonth(today.year, today.month)) * monthWidth
        : -1;

    return GestureDetector(
      onTap: () => _showDetail(context),
      child: Container(
        height: rowHeight,
        color: Colors.white,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            // 월 구분 세로선
            ...List.generate(months.length, (i) => Positioned(
                  left: i * monthWidth,
                  top: 0,
                  bottom: 0,
                  width: 1,
                  child: ColoredBox(color: Colors.grey[100]!),
                )),

            // 오늘 선
            if (todayLineLeft >= 0)
              Positioned(
                left: todayLineLeft,
                top: 0,
                bottom: 0,
                width: 1.5,
                child: ColoredBox(color: Colors.blue.shade300),
              ),

            // 간트 바
            Positioned(
              left: barLeft,
              top: rowHeight * 0.22,
              height: rowHeight * 0.56,
              width: barWidth,
              child: ClipRRect(
                borderRadius: BorderRadius.horizontal(
                  left: clippedLeft
                      ? Radius.zero
                      : const Radius.circular(6),
                  right: clippedRight
                      ? Radius.zero
                      : const Radius.circular(6),
                ),
                child: ColoredBox(
                  color: color,
                  child: Row(
                    children: [
                      if (clippedLeft)
                        const Icon(Icons.arrow_left,
                            color: Colors.white, size: 14),
                      Expanded(
                        child: Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 5),
                          child: Text(
                            event.prizeDisplayText ??
                                event.category.label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ),
                      if (clippedRight)
                        const Icon(Icons.arrow_right,
                            color: Colors.white, size: 14),
                    ],
                  ),
                ),
              ),
            ),

            // 행 구분선
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 1,
              child: ColoredBox(color: Colors.grey[100]!),
            ),
          ],
        ),
      ),
    );
  }

  int _daysInMonth(int year, int month) =>
      DateTime(year, month + 1, 0).day;

  void _showDetail(BuildContext context) {
    String fmt(DateTime dt) =>
        '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
    final brokerageColor = Color(event.brokerage.color);
    final catColor = Color(event.category.color);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                    color: brokerageColor,
                    borderRadius: BorderRadius.circular(6)),
                child: Center(
                    child: Text(event.brokerage.name[0],
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold))),
              ),
              const SizedBox(width: 8),
              Text(event.brokerage.name,
                  style: TextStyle(
                      color: brokerageColor,
                      fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: catColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10)),
                child: Text(event.category.label,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: catColor)),
              ),
            ]),
            const SizedBox(height: 10),
            Text(event.eventTitle,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 12),
            if (event.prizeDisplayText != null) ...[
              _row(Icons.redeem, '경품', event.prizeDisplayText!),
              const SizedBox(height: 8),
            ],
            _row(Icons.how_to_reg, '참여일', fmt(event.participatedAt)),
            const SizedBox(height: 8),
            _row(Icons.flag, '경품 지급일', fmt(event.rewardDate)),
            if (event.nextEligibleDate != null) ...[
              const SizedBox(height: 8),
              _row(Icons.event_repeat, '다음 참여 가능일',
                  fmt(event.nextEligibleDate!)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) => Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[500]),
          const SizedBox(width: 8),
          Text('$label: ',
              style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          Expanded(
              child: Text(value,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500))),
        ],
      );
}

// ─────────────────────────────────────────────────────────────────
// 올해 수령 경품 요약 배너
// ─────────────────────────────────────────────────────────────────
class _YearSummaryBanner extends StatelessWidget {
  final int year;
  final int total;

  const _YearSummaryBanner({required this.year, required this.total});

  String _fmt(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          Icon(Icons.card_giftcard, size: 18, color: Colors.green[600]),
          const SizedBox(width: 8),
          Text(
            '$year년 수령 경품',
            style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500),
          ),
          const Spacer(),
          Text(
            total > 0 ? '${_fmt(total)}원' : '-',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: total > 0 ? Colors.green[700] : Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }
}
