import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kTutorialShownKey = 'stockpicker_tutorial_shown_v1';
const _kPrimary = Color(0xFF3B5BDB); // indigo
const _kDark = Color(0xFF1A237E);
const _kMid = Color(0xFF283593);

// ═══════════════════════════════════════════════════════════════════════════════
// Step model
// ═══════════════════════════════════════════════════════════════════════════════

class _Step {
  final String? targetId;
  final String emoji;
  final String title;
  final String body;

  const _Step({
    this.targetId,
    required this.emoji,
    required this.title,
    required this.body,
  });
}

// GlobalKey 레지스트리
class TutorialKeys {
  static final GlobalKey participatedBtn = GlobalKey();
  static final GlobalKey myAccountBtn = GlobalKey();
  static final GlobalKey timelineBtn = GlobalKey();
  static final GlobalKey bookmarkBtn = GlobalKey();
  static final GlobalKey filterRow = GlobalKey();
}

const _steps = [
  _Step(
    emoji: '📈',
    title: '스탁피커에 오신 걸 환영해요!',
    body: '증권사 이벤트를 한눈에 모아보고\n스마트하게 관리해요!\n\n주요 기능들을 하나씩 소개할게요 😊',
  ),
  _Step(
    emoji: '🏦',
    title: '이벤트 목록',
    body: '진행 중인 증권사 이벤트를\n한 화면에서 확인해요!\n\n삼성·미래에셋·신한·대신 등\n주요 증권사의 이벤트를 수집해요.',
  ),
  _Step(
    targetId: 'filter',
    emoji: '🔍',
    title: '증권사 & 카테고리 필터',
    body: '원하는 증권사와 카테고리를\n선택해서 필터링하세요!\n\n수수료혜택·신규계좌·적립금 등\n다양한 카테고리를 지원해요.',
  ),
  _Step(
    emoji: '📋',
    title: '이벤트 상세 보기',
    body: '이벤트 카드를 탭하면\n상세 정보를 확인해요!\n\n이벤트 기간·조건·경품을\n한눈에 볼 수 있어요.',
  ),
  _Step(
    targetId: 'participated',
    emoji: '✅',
    title: '참여한 이벤트 등록',
    body: '이 버튼을 눌러\n참여한 이벤트를 기록하세요!\n\n참여 이력을 관리하면\n중복 참여를 방지할 수 있어요.',
  ),
  _Step(
    targetId: 'myAccount',
    emoji: '💼',
    title: '내 계좌 추가',
    body: 'my 버튼을 눌러\n보유한 증권 계좌를 등록하세요!\n\n계좌 정보를 기반으로\n맞춤 이벤트를 추천해 드려요.',
  ),
  _Step(
    emoji: '🎯',
    title: '맞춤 이벤트 추천',
    body: '계좌를 등록하면 상단에\n추천 이벤트 배너가 나타나요!\n\n내 계좌에 딱 맞는 이벤트만\n모아서 보여드려요 💡',
  ),
  _Step(
    targetId: 'timeline',
    emoji: '📊',
    title: '간트 차트로 보기',
    body: '이 버튼을 누르면\n참여 이벤트를 타임라인으로 봐요!\n\n경품 수령일·다음 참여 가능일을\n차트로 한눈에 확인할 수 있어요.',
  ),
  _Step(
    emoji: '🔖',
    title: '북마크',
    body: '관심 이벤트에 북마크를 달면\n상단 필터로 모아볼 수 있어요!\n\n놓치기 싫은 이벤트를\n즐겨찾기에 추가해 보세요.',
  ),
  _Step(
    emoji: '🎉',
    title: '준비 완료!',
    body: '이제 증권사 이벤트를\n스마트하게 관리해볼까요? 🚀\n\n우측 상단 ? 버튼으로\n언제든 이 안내를 다시 볼 수 있어요!',
  ),
];

// ═══════════════════════════════════════════════════════════════════════════════
// SharedPreferences helpers
// ═══════════════════════════════════════════════════════════════════════════════

Future<bool> checkShouldShowTutorial() async {
  final prefs = await SharedPreferences.getInstance();
  return !(prefs.getBool(_kTutorialShownKey) ?? false);
}

Future<void> markTutorialShown() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_kTutorialShownKey, true);
}

Future<void> resetTutorial() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_kTutorialShownKey);
}

// ═══════════════════════════════════════════════════════════════════════════════
// Entry point
// ═══════════════════════════════════════════════════════════════════════════════

void showTutorialOverlay(BuildContext context) {
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => Positioned.fill(
      child: _TutorialOverlayWidget(
        onDismiss: () => entry.remove(),
      ),
    ),
  );
  Overlay.of(context, rootOverlay: true).insert(entry);
}

// ═══════════════════════════════════════════════════════════════════════════════
// Main overlay widget
// ═══════════════════════════════════════════════════════════════════════════════

class _TutorialOverlayWidget extends StatefulWidget {
  final VoidCallback onDismiss;

  const _TutorialOverlayWidget({required this.onDismiss});

  @override
  State<_TutorialOverlayWidget> createState() => _TutorialOverlayWidgetState();
}

class _TutorialOverlayWidgetState extends State<_TutorialOverlayWidget> {
  bool _visible = false;
  bool _dismissing = false;
  int _step = 0;
  bool _dontShowAgain = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _visible = true);
    });
  }

  Rect? _spotlight() {
    final id = _steps[_step].targetId;
    if (id == null) return null;

    GlobalKey? key;
    switch (id) {
      case 'participated':
        key = TutorialKeys.participatedBtn;
      case 'myAccount':
        key = TutorialKeys.myAccountBtn;
      case 'timeline':
        key = TutorialKeys.timelineBtn;
      case 'bookmark':
        key = TutorialKeys.bookmarkBtn;
      case 'filter':
        key = TutorialKeys.filterRow;
    }

    final ctx = key?.currentContext;
    if (ctx == null) return null;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    final pos = box.localToGlobal(Offset.zero);
    return Rect.fromLTWH(pos.dx, pos.dy, box.size.width, box.size.height)
        .inflate(10);
  }

  Future<void> _dismiss() async {
    if (_dismissing || !mounted) return;
    _dismissing = true;
    if (_dontShowAgain) await markTutorialShown();
    if (!mounted) return;
    setState(() => _visible = false);
    await Future.delayed(const Duration(milliseconds: 320));
    widget.onDismiss();
  }

  void _next() {
    if (_step < _steps.length - 1) {
      setState(() => _step++);
    } else {
      _dismiss();
    }
  }

  void _prev() {
    if (_step > 0) setState(() => _step--);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final step = _steps[_step];
    final spotlight = _spotlight();

    return AnimatedOpacity(
      opacity: _visible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            // ① 어두운 배경 + 스포트라이트
            Positioned.fill(
              child: CustomPaint(
                painter: _SpotlightPainter(spotlight: spotlight),
              ),
            ),

            // ② 설명 카드
            if (spotlight == null)
              Positioned.fill(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 56, 24, 128),
                    child: _ContentCard(
                      key: ValueKey(_step),
                      step: step,
                      stepIndex: _step,
                    ),
                  ),
                ),
              )
            else
              _buildPositionedCard(step, spotlight, size),

            // ③ 건너뛰기 버튼
            Positioned(
              top: 0,
              right: 8,
              child: SafeArea(
                child: TextButton(
                  onPressed: _dismiss,
                  style: TextButton.styleFrom(foregroundColor: Colors.white70),
                  child: const Text('건너뛰기'),
                ),
              ),
            ),

            // ④ 페이지 인디케이터 + 네비게이션
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _PageDots(count: _steps.length, current: _step),
                      const SizedBox(height: 12),
                      // 다시 보지 않기 체크박스
                      GestureDetector(
                        onTap: () =>
                            setState(() => _dontShowAgain = !_dontShowAgain),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: _dontShowAgain
                                    ? _kPrimary
                                    : Colors.transparent,
                                border: Border.all(
                                  color: _dontShowAgain
                                      ? _kPrimary
                                      : Colors.white54,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: _dontShowAgain
                                  ? const Icon(Icons.check,
                                      size: 14, color: Colors.white)
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              '다시 보지 않기',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          if (_step > 0) ...[
                            OutlinedButton.icon(
                              onPressed: _prev,
                              icon: const Icon(Icons.arrow_back_rounded,
                                  size: 18),
                              label: const Text('이전'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                minimumSize: const Size(80, 44),
                                side: const BorderSide(
                                    color: Colors.white54, width: 1.5),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30)),
                              ),
                            ),
                            const Spacer(),
                          ] else
                            const Spacer(),
                          FilledButton.icon(
                            onPressed: _next,
                            icon: _step < _steps.length - 1
                                ? const Icon(Icons.arrow_forward_rounded,
                                    size: 18)
                                : const Icon(Icons.check_rounded, size: 18),
                            label: Text(
                              _step < _steps.length - 1 ? '다음' : '시작하기',
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: _kPrimary,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(100, 48),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 28, vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30)),
                              elevation: 4,
                              shadowColor:
                                  _kPrimary.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPositionedCard(_Step step, Rect spotlight, Size size) {
    const cardW = 300.0;
    const arrowSize = 36.0;
    const gap = 10.0;

    final left = (spotlight.center.dx - cardW / 2)
        .clamp(12.0, size.width - cardW - 12.0);
    final isAbove = spotlight.center.dy > size.height * 0.5;

    if (isAbove) {
      return Positioned(
        key: ValueKey('card_$_step'),
        left: left,
        bottom: size.height - spotlight.top + gap,
        width: cardW,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _CompactCard(step: step, stepIndex: _step),
            const SizedBox(height: 2),
            const Icon(Icons.keyboard_arrow_down_rounded,
                color: _kPrimary, size: arrowSize),
          ],
        ),
      );
    } else {
      return Positioned(
        key: ValueKey('card_$_step'),
        left: left,
        top: spotlight.bottom + gap,
        width: cardW,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.keyboard_arrow_up_rounded,
                color: _kPrimary, size: arrowSize),
            const SizedBox(height: 2),
            _CompactCard(step: step, stepIndex: _step),
          ],
        ),
      );
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Spotlight painter
// ═══════════════════════════════════════════════════════════════════════════════

class _SpotlightPainter extends CustomPainter {
  final Rect? spotlight;
  static const double _r = 14.0;

  const _SpotlightPainter({this.spotlight});

  @override
  void paint(Canvas canvas, Size size) {
    final full = Offset.zero & size;

    if (spotlight == null) {
      canvas.drawRect(full, Paint()..color = Colors.black.withValues(alpha: 0.82));
      return;
    }

    canvas.saveLayer(full, Paint());
    canvas.drawRect(full, Paint()..color = Colors.black.withValues(alpha: 0.82));
    canvas.drawRRect(
      RRect.fromRectAndRadius(spotlight!, const Radius.circular(_r)),
      Paint()..blendMode = BlendMode.clear,
    );
    canvas.restore();

    // 인디고 glow 테두리
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          spotlight!.inflate(3), const Radius.circular(_r + 3)),
      Paint()
        ..color = _kPrimary.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) => old.spotlight != spotlight;
}

// ═══════════════════════════════════════════════════════════════════════════════
// Page dots
// ═══════════════════════════════════════════════════════════════════════════════

class _PageDots extends StatelessWidget {
  final int count;
  final int current;

  const _PageDots({required this.count, required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 22 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active ? _kPrimary : Colors.white38,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 전체 화면 중앙 카드 (스포트라이트 없는 스텝용)
// ═══════════════════════════════════════════════════════════════════════════════

class _ContentCard extends StatelessWidget {
  final _Step step;
  final int stepIndex;

  const _ContentCard({super.key, required this.step, required this.stepIndex});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 340),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_kMid, _kDark],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 이모지 원형 배지
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25), width: 2),
              ),
              child: Center(
                child: Text(step.emoji,
                    style: const TextStyle(fontSize: 36)),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              step.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                color: Colors.white,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 16),
            _buildIllustration(stepIndex),
            const SizedBox(height: 14),
            Text(
              step.body,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.9),
                height: 1.7,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIllustration(int index) {
    switch (index) {
      case 1:
        return const _EventListIllustration();
      case 3:
        return const _EventDetailIllustration();
      case 6:
        return const _RecommendationIllustration();
      case 8:
        return const _BookmarkIllustration();
      case 9:
        return const _GanttPreviewIllustration();
      default:
        return const SizedBox.shrink();
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 스포트라이트 옆 작은 카드
// ═══════════════════════════════════════════════════════════════════════════════

class _CompactCard extends StatelessWidget {
  final _Step step;
  final int stepIndex;

  const _CompactCard({required this.step, required this.stepIndex});

  Widget _buildIllustration() {
    switch (stepIndex) {
      case 2:
        return const _FilterIllustration();
      case 4:
        return const _ParticipatedRegisterIllustration();
      case 5:
        return const _AccountAddIllustration();
      case 7:
        return const _GanttPreviewIllustration();
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final illust = _buildIllustration();
    final hasIllust = illust is! SizedBox;
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_kMid, _kDark],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(step.emoji, style: const TextStyle(fontSize: 30)),
          const SizedBox(height: 10),
          Text(
            step.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (hasIllust) ...[
            const SizedBox(height: 12),
            illust,
          ],
          const SizedBox(height: 10),
          Text(
            step.body,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.88),
              height: 1.65,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 일러스트: 이벤트 목록 모형
// ═══════════════════════════════════════════════════════════════════════════════

class _EventListIllustration extends StatefulWidget {
  const _EventListIllustration();

  @override
  State<_EventListIllustration> createState() => _EventListIllustrationState();
}

class _EventListIllustrationState extends State<_EventListIllustration> {
  int _highlighted = 0;

  static const _items = [
    {'brokerage': '삼성', 'color': 0xFF1E88E5, 'cat': '수수료혜택', 'title': '온라인 주식 거래 수수료 무료'},
    {'brokerage': '미래에셋', 'color': 0xFFE53935, 'cat': '신규계좌', 'title': '신규 계좌 개설 5만원 지급'},
    {'brokerage': '신한', 'color': 0xFF43A047, 'cat': '적립금', 'title': '첫 거래 시 포인트 2천원 지급'},
  ];

  @override
  void initState() {
    super.initState();
    _cycle();
  }

  Future<void> _cycle() async {
    for (var i = 0; i < _items.length; i++) {
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      setState(() => _highlighted = i);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: List.generate(_items.length, (i) {
          final item = _items[i];
          final color = Color(item['color'] as int);
          final active = i == _highlighted;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: active
                  ? color.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: active ? color.withValues(alpha: 0.6) : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                      color: color, borderRadius: BorderRadius.circular(7)),
                  child: Center(
                    child: Text(
                      (item['brokerage'] as String)[0],
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['title'] as String,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 11, height: 1.3),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          item['cat'] as String,
                          style: TextStyle(
                              color: color, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.bookmark_border,
                    color: Colors.white38, size: 16),
              ],
            ),
          );
        }),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 일러스트: 이벤트 상세 카드 모형
// ═══════════════════════════════════════════════════════════════════════════════

class _EventDetailIllustration extends StatelessWidget {
  const _EventDetailIllustration();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E88E5).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('삼성증권',
                    style: TextStyle(
                        color: Color(0xFF64B5F6),
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('수수료혜택',
                    style: TextStyle(
                        color: Colors.orange,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ),
              const Spacer(),
              const Icon(Icons.open_in_new, color: Colors.white54, size: 14),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '온라인 주식 거래 수수료 무료 이벤트',
            style: TextStyle(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _infoRow(Icons.calendar_today, '기간', '2026.03.01 ~ 2026.06.30'),
          const SizedBox(height: 4),
          _infoRow(Icons.redeem, '경품', '거래 수수료 0원'),
          const SizedBox(height: 8),
          // 참여하기 버튼 모형
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_kPrimary, _kPrimary.withValues(alpha: 0.7)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.assignment_turned_in_outlined,
                    color: Colors.white, size: 14),
                SizedBox(width: 6),
                Text('참여 완료 등록',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.white54, size: 13),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(color: Colors.white38, fontSize: 10)),
        const SizedBox(width: 6),
        Text(value,
            style: const TextStyle(
                color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 일러스트: 맞춤 추천 배너 모형
// ═══════════════════════════════════════════════════════════════════════════════

class _RecommendationIllustration extends StatefulWidget {
  const _RecommendationIllustration();

  @override
  State<_RecommendationIllustration> createState() =>
      _RecommendationIllustrationState();
}

class _RecommendationIllustrationState
    extends State<_RecommendationIllustration>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulse = Tween(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          // 계좌 등록 후 표시되는 배너
          ScaleTransition(
            scale: _pulse,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.indigo.shade600, Colors.indigo.shade400],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.recommend, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '내 계좌 기반 추천 이벤트 5개',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  const Icon(Icons.chevron_right,
                      color: Colors.white70, size: 18),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          // 추천 이유 설명
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _accountChip('삼성', const Color(0xFF1E88E5)),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_forward, color: Colors.white38, size: 12),
              const SizedBox(width: 4),
              _accountChip('미래에셋', const Color(0xFFE53935)),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_forward, color: Colors.white38, size: 12),
              const SizedBox(width: 4),
              _accountChip('신한', const Color(0xFF43A047)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _accountChip(String name, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(name,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 일러스트: 북마크 기능 모형
// ═══════════════════════════════════════════════════════════════════════════════

class _BookmarkIllustration extends StatefulWidget {
  const _BookmarkIllustration();

  @override
  State<_BookmarkIllustration> createState() => _BookmarkIllustrationState();
}

class _BookmarkIllustrationState extends State<_BookmarkIllustration> {
  bool _bookmarked = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _bookmarked = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          // 이벤트 카드 with 북마크
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                      color: const Color(0xFF1E88E5),
                      borderRadius: BorderRadius.circular(8)),
                  child: const Center(
                    child: Text('삼',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    '온라인 주식 거래 수수료 무료',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Icon(
                    _bookmarked ? Icons.bookmark : Icons.bookmark_border,
                    key: ValueKey(_bookmarked),
                    color:
                        _bookmarked ? Colors.amber[400] : Colors.white38,
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // 북마크 필터 힌트
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: Colors.amber.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.bookmark,
                    color: Colors.amber[400], size: 14),
                const SizedBox(width: 6),
                const Text(
                  '상단 북마크 버튼으로 모아보기',
                  style: TextStyle(color: Colors.amber, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 일러스트: 간트 차트 미리보기 모형
// ═══════════════════════════════════════════════════════════════════════════════

class _GanttPreviewIllustration extends StatelessWidget {
  const _GanttPreviewIllustration();

  static const _events = [
    {'brokerage': '삼성', 'color': 0xFF1E88E5, 'start': 4, 'end': 8},
    {'brokerage': '미래에셋', 'color': 0xFFE53935, 'start': 5, 'end': 10},
    {'brokerage': '신한', 'color': 0xFF43A047, 'start': 3, 'end': 7},
  ];

  static const _months = ['1월', '2월', '3월', '4월', '5월', '6월'];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 월 헤더
          Row(
            children: [
              const SizedBox(width: 44),
              ...List.generate(_months.length, (i) {
                final isCurrent = i == 3; // 4월 현재
                return Expanded(
                  child: Center(
                    child: Text(
                      _months[i],
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: isCurrent
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isCurrent ? Colors.blue[300] : Colors.white38,
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 4),
          // 이벤트 행들
          ..._events.map((e) {
            final color = Color(e['color'] as int);
            final start = e['start'] as int;
            final end = e['end'] as int;
            return Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                children: [
                  // 라벨
                  SizedBox(
                    width: 44,
                    child: Text(
                      e['brokerage'] as String,
                      style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // 간트 바
                  Expanded(
                    child: LayoutBuilder(
                      builder: (ctx, constraints) {
                        final colW = constraints.maxWidth / _months.length;
                        final barLeft = (start - 1) * colW;
                        final barW = (end - start + 1) * colW;
                        return SizedBox(
                          height: 18,
                          child: Stack(
                            children: [
                              // 배경 그리드
                              ...List.generate(_months.length, (i) {
                                final isCurrent = i == 3;
                                return Positioned(
                                  left: i * colW,
                                  top: 0,
                                  bottom: 0,
                                  width: colW,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: isCurrent
                                          ? Colors.blue.withValues(alpha: 0.07)
                                          : null,
                                      border: Border(
                                          right: BorderSide(
                                              color: Colors.white12,
                                              width: 0.5)),
                                    ),
                                  ),
                                );
                              }),
                              // 오늘선 (4월 중간쯤)
                              Positioned(
                                left: 3 * colW + colW * 0.5,
                                top: 0,
                                bottom: 0,
                                width: 1.5,
                                child: const ColoredBox(
                                    color: Color(0xFF64B5F6)),
                              ),
                              // 간트 바
                              Positioned(
                                left: barLeft,
                                top: 3,
                                bottom: 3,
                                width: barW,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: ColoredBox(
                                    color: color,
                                    child: Center(
                                      child: Text(
                                        '${e['brokerage']} 이벤트',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 8,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          }),
          // 오늘 표시 힌트
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                width: 10,
                height: 2,
                color: const Color(0xFF64B5F6),
              ),
              const SizedBox(width: 4),
              const Text('오늘',
                  style: TextStyle(color: Color(0xFF64B5F6), fontSize: 9)),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 일러스트: 증권사/카테고리 필터 모형 (step 2)
// ═══════════════════════════════════════════════════════════════════════════════

class _FilterIllustration extends StatefulWidget {
  const _FilterIllustration();

  @override
  State<_FilterIllustration> createState() => _FilterIllustrationState();
}

class _FilterIllustrationState extends State<_FilterIllustration> {
  int _selectedBrokerage = -1; // -1 = 전체
  int _selectedCategory = -1;

  static const _brokerages = [
    {'name': '삼성', 'color': 0xFF1E88E5},
    {'name': '미래에셋', 'color': 0xFFE53935},
    {'name': '신한', 'color': 0xFF43A047},
    {'name': '대신', 'color': 0xFFFF8F00},
  ];

  static const _categories = [
    {'name': '수수료혜택', 'color': 0xFF5C6BC0},
    {'name': '신규계좌', 'color': 0xFF26A69A},
    {'name': '적립금', 'color': 0xFFEC407A},
    {'name': '추천인', 'color': 0xFF7E57C2},
  ];

  @override
  void initState() {
    super.initState();
    _animate();
  }

  Future<void> _animate() async {
    // 순서대로 증권사 → 카테고리 선택 시연
    for (int i = 0; i < _brokerages.length; i++) {
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      setState(() => _selectedBrokerage = i);
    }
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    setState(() => _selectedBrokerage = 0);

    for (int i = 0; i < _categories.length; i++) {
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      setState(() => _selectedCategory = i);
    }
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    setState(() => _selectedCategory = 0);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 증권사 필터
          Row(
            children: [
              const Icon(Icons.tune, size: 11, color: Colors.white38),
              const SizedBox(width: 4),
              const Text('증권사',
                  style: TextStyle(color: Colors.white38, fontSize: 10)),
            ],
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip(
                  label: '전체',
                  selected: _selectedBrokerage == -1,
                  color: Colors.grey,
                  onTap: () => setState(() => _selectedBrokerage = -1),
                ),
                ..._brokerages.asMap().entries.map((e) => _filterChip(
                      label: e.value['name'] as String,
                      selected: _selectedBrokerage == e.key,
                      color: Color(e.value['color'] as int),
                      onTap: () =>
                          setState(() => _selectedBrokerage = e.key),
                    )),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // 카테고리 필터
          Row(
            children: [
              const Icon(Icons.category_outlined, size: 11, color: Colors.white38),
              const SizedBox(width: 4),
              const Text('카테고리',
                  style: TextStyle(color: Colors.white38, fontSize: 10)),
            ],
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip(
                  label: '전체',
                  selected: _selectedCategory == -1,
                  color: Colors.grey,
                  onTap: () => setState(() => _selectedCategory = -1),
                ),
                ..._categories.asMap().entries.map((e) => _filterChip(
                      label: e.value['name'] as String,
                      selected: _selectedCategory == e.key,
                      color: Color(e.value['color'] as int),
                      onTap: () =>
                          setState(() => _selectedCategory = e.key),
                    )),
              ],
            ),
          ),
          // 결과 카운트 힌트
          if (_selectedBrokerage >= 0 || _selectedCategory >= 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: _kPrimary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: _kPrimary.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.filter_list,
                      color: Colors.white70, size: 12),
                  const SizedBox(width: 4),
                  Text(
                    '필터 적용됨 · 결과 ${_selectedBrokerage >= 0 ? 12 : 24}개',
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 5),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.8) : Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : Colors.white24,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : Colors.white60,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 일러스트: 참여한 이벤트 등록 모형 (step 4)
// ═══════════════════════════════════════════════════════════════════════════════

class _ParticipatedRegisterIllustration extends StatefulWidget {
  const _ParticipatedRegisterIllustration();

  @override
  State<_ParticipatedRegisterIllustration> createState() =>
      _ParticipatedRegisterIllustrationState();
}

class _ParticipatedRegisterIllustrationState
    extends State<_ParticipatedRegisterIllustration> {
  bool _registered = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _registered = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          // 이벤트 카드 미니 버전
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E88E5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Center(
                    child: Text('삼',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 11)),
                  ),
                ),
                const SizedBox(width: 7),
                const Expanded(
                  child: Text(
                    '온라인 주식 거래 수수료 무료',
                    style: TextStyle(color: Colors.white, fontSize: 10),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // 등록 폼 필드들
          _formField(Icons.calendar_today, '참여일', '2026.04.07'),
          const SizedBox(height: 5),
          _formField(Icons.flag_outlined, '경품 지급일', '2026.07.31'),
          const SizedBox(height: 5),
          _formField(Icons.redeem, '경품', '수수료 면제'),
          const SizedBox(height: 8),
          // 등록 버튼 with 애니메이션
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: _registered
                  ? Colors.green.withValues(alpha: 0.7)
                  : _kPrimary.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Icon(
                    _registered
                        ? Icons.check_circle_outline
                        : Icons.assignment_turned_in_outlined,
                    key: ValueKey(_registered),
                    color: Colors.white,
                    size: 14,
                  ),
                ),
                const SizedBox(width: 6),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    _registered ? '등록 완료!' : '참여 완료 등록',
                    key: ValueKey(_registered),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          if (_registered) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: Colors.green.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.event_repeat,
                      color: Colors.green[300], size: 11),
                  const SizedBox(width: 5),
                  Text(
                    '다음 참여 가능: 2026.10.07',
                    style: TextStyle(
                        color: Colors.green[300], fontSize: 9),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _formField(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white38, size: 12),
          const SizedBox(width: 5),
          Text(label,
              style: const TextStyle(color: Colors.white38, fontSize: 9)),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 일러스트: 내 계좌 추가 모형 (step 5)
// ═══════════════════════════════════════════════════════════════════════════════

class _AccountAddIllustration extends StatefulWidget {
  const _AccountAddIllustration();

  @override
  State<_AccountAddIllustration> createState() =>
      _AccountAddIllustrationState();
}

class _AccountAddIllustrationState extends State<_AccountAddIllustration> {
  final List<Map<String, dynamic>> _accounts = [];
  bool _showPicker = false;

  static const _available = [
    {'name': '삼성', 'color': 0xFF1E88E5},
    {'name': '미래에셋', 'color': 0xFFE53935},
    {'name': '신한', 'color': 0xFF43A047},
  ];

  @override
  void initState() {
    super.initState();
    _animate();
  }

  Future<void> _animate() async {
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _showPicker = true);

    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() {
      _showPicker = false;
      _accounts.add(_available[0]);
    });

    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _showPicker = true);

    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() {
      _showPicker = false;
      _accounts.add(_available[1]);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          // 계좌 타입 섹션 헤더
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('일반계좌',
                    style: TextStyle(
                        color: Colors.lightBlue,
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: _kPrimary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: _kPrimary.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add,
                        size: 11,
                        color: Colors.blue[200]),
                    const SizedBox(width: 2),
                    Text('추가',
                        style: TextStyle(
                            color: Colors.blue[200],
                            fontSize: 10,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 등록된 계좌 목록
          if (_accounts.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: const Text('등록된 계좌가 없습니다',
                  style:
                      TextStyle(color: Colors.white38, fontSize: 10)),
            )
          else
            Column(
              children: _accounts.map((acc) {
                final color = Color(acc['color'] as int);
                return AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 5),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: color.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Center(
                            child: Text(
                              (acc['name'] as String)[0],
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11),
                            ),
                          ),
                        ),
                        const SizedBox(width: 7),
                        Text(acc['name'] as String,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w500)),
                        const Spacer(),
                        Icon(Icons.check_circle,
                            color: color, size: 14),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          // 증권사 선택 바텀시트 미니 버전
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            child: _showPicker
                ? Container(
                    margin: const EdgeInsets.only(top: 6),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E2A6E),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.15)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('증권사 선택',
                            style: TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        Row(
                          children: _available
                              .where((a) => !_accounts
                                  .any((acc) => acc['name'] == a['name']))
                              .map((a) {
                            final c = Color(a['color'] as int);
                            return Container(
                              margin: const EdgeInsets.only(right: 5),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 5),
                              decoration: BoxDecoration(
                                color: c.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: c.withValues(alpha: 0.5)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      color: c,
                                      borderRadius:
                                          BorderRadius.circular(4),
                                    ),
                                    child: Center(
                                      child: Text(
                                        (a['name'] as String)[0],
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(a['name'] as String,
                                      style: TextStyle(
                                          color: c,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600)),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
