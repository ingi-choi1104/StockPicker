import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/brokerage_event.dart';
import '../providers/events_provider.dart';
import '../providers/participated_events_provider.dart';
import '../providers/user_accounts_provider.dart';
import '../widgets/event_card.dart';
import '../widgets/banner_ad_widget.dart';
import 'account_registration_screen.dart';
import 'event_detail_screen.dart';
import 'participated_events_screen.dart';
import 'my_events_screen.dart';
import 'recommended_events_screen.dart';

String _fmtDate(DateTime dt) => '${dt.year}년 ${dt.month}월 ${dt.day}일';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  bool _filtersExpanded = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EventsProvider>().loadEvents();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildSearchBar(),
            _buildFilterToggleRow(),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: _filtersExpanded
                  ? Column(
                      children: [
                        _buildBrokerageFilter(),
                        _buildCategoryFilter(),
                      ],
                    )
                  : const SizedBox(width: double.infinity, height: 0),
            ),
            _buildSortBar(),
            _buildRecommendationBanner(),
            _buildParticipationWarning(),
            _buildEventList(),
            const BannerAdWidget(),
          ],
        ),
      ),
    );
  }

  // ─── 헤더 ──────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Consumer<EventsProvider>(
      builder: (context, provider, _) {
        return Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(20, 16, 8, 12),
          child: Row(
            children: [
              // 타이틀 + 서브타이틀 (Flexible로 오버플로 방지)
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '증권사 이벤트',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    if (provider.loadingState == LoadingState.loaded)
                      _buildSubtitle(provider),
                  ],
                ),
              ),
              // 액션 버튼들
              _buildHeaderActions(provider),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSubtitle(EventsProvider provider) {
    final parts = <String>[
      '진행중 ${provider.activeEventCount}개',
      if (provider.lastFetchedAt != null)
        _formatLastFetched(provider.lastFetchedAt!),
      if (provider.lastFetchedAt != null) provider.dataSourceLabel,
    ];
    return Text(
      parts.join(' · '),
      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildHeaderActions(EventsProvider provider) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (provider.bookmarkCount > 0)
          Badge(
            label: Text('${provider.bookmarkCount}'),
            child: IconButton(
              icon: Icon(
                provider.showBookmarkedOnly
                    ? Icons.bookmark
                    : Icons.bookmark_outline,
              ),
              iconSize: 22,
              color: provider.showBookmarkedOnly
                  ? Colors.amber[700]
                  : Colors.grey[600],
              onPressed: provider.toggleBookmarkedOnly,
            ),
          ),
        Consumer<ParticipatedEventsProvider>(
          builder: (context, prov, _) {
            final count = prov.count;
            final btn = IconButton(
              icon: const Icon(Icons.assignment_turned_in_outlined),
              iconSize: 22,
              color: count > 0 ? Colors.grey[600] : Colors.grey[400],
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const ParticipatedEventsScreen()),
              ),
            );
            return count > 0
                ? Badge(label: Text('$count'), child: btn)
                : btn;
          },
        ),
        InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const AccountRegistrationScreen()),
          ),
          child: SizedBox(
            width: 40,
            height: 40,
            child: Center(
              child: Text(
                'my',
                style: TextStyle(
                  fontSize: 15,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w800,
                  color: Colors.grey[600],
                  height: 1.0,
                ),
              ),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.timeline),
          iconSize: 22,
          color: Colors.grey[600],
          tooltip: '나의 이벤트',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MyEventsScreen()),
          ),
        ),
      ],
    );
  }

  String _formatLastFetched(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inHours < 1) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  // ─── 검색바 ────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => context.read<EventsProvider>().setSearchQuery(v),
        decoration: InputDecoration(
          hintText: '이벤트 검색...',
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    context.read<EventsProvider>().setSearchQuery('');
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.grey[100],
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  // ─── 필터 토글 헤더 ────────────────────────────────────────────
  Widget _buildFilterToggleRow() {
    return Consumer<EventsProvider>(
      builder: (context, provider, _) {
        final hasActive = provider.selectedBrokerages.isNotEmpty ||
            provider.selectedCategories.isNotEmpty;
        return GestureDetector(
          onTap: () => setState(() => _filtersExpanded = !_filtersExpanded),
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
            margin: const EdgeInsets.only(bottom: 2),
            child: Row(
              children: [
                Icon(Icons.tune, size: 15, color: Colors.grey[600]),
                const SizedBox(width: 6),
                Text(
                  '필터',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (hasActive) ...[
                  const SizedBox(width: 5),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Colors.indigo,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
                const Spacer(),
                AnimatedRotation(
                  turns: _filtersExpanded ? 0.0 : 0.5,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(Icons.expand_less,
                      size: 20, color: Colors.grey[400]),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── 증권사 필터 (복수 선택) ────────────────────────────────────
  Widget _buildBrokerageFilter() {
    return Consumer<EventsProvider>(
      builder: (context, provider, _) {
        final selected = provider.selectedBrokerages;
        return Container(
          color: Colors.white,
          height: 44,
          margin: const EdgeInsets.only(bottom: 2),
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            children: [
              _chip(
                label: '전체',
                selected: selected.isEmpty,
                onTap: provider.clearBrokerages,
                color: Colors.grey,
              ),
              ...BrokerageType.values.map((b) => _chip(
                    label: b.name,
                    selected: selected.contains(b),
                    onTap: () => provider.toggleBrokerage(b),
                    color: Color(b.color),
                  )),
            ],
          ),
        );
      },
    );
  }

  // ─── 카테고리 필터 (복수 선택) ──────────────────────────────────
  Widget _buildCategoryFilter() {
    return Consumer<EventsProvider>(
      builder: (context, provider, _) {
        final selected = provider.selectedCategories;
        return Container(
          color: Colors.white,
          height: 44,
          margin: const EdgeInsets.only(bottom: 8),
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            children: [
              _chip(
                label: '전체',
                selected: selected.isEmpty,
                onTap: provider.clearCategories,
                color: Colors.grey,
              ),
              ...EventCategory.values.map((c) => _chip(
                    label: c.label,
                    selected: selected.contains(c),
                    onTap: () => provider.toggleCategory(c),
                    color: Color(c.color),
                  )),
            ],
          ),
        );
      },
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: selected ? color : Colors.grey[100],
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : Colors.grey[700],
            ),
          ),
        ),
      ),
    );
  }

  // ─── 정렬 바 ───────────────────────────────────────────────────
  Widget _buildSortBar() {
    return Consumer<EventsProvider>(
      builder: (context, provider, _) {
        return Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          margin: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Text('정렬',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              const SizedBox(width: 8),
              ...SortOrder.values.map((order) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () => provider.setSortOrder(order),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: provider.sortOrder == order
                              ? Colors.indigo
                              : Colors.grey[100],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          order.label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: provider.sortOrder == order
                                ? Colors.white
                                : Colors.grey[700],
                          ),
                        ),
                      ),
                    ),
                  )),
            ],
          ),
        );
      },
    );
  }

  // ─── 추천 배너 ─────────────────────────────────────────────────
  Widget _buildRecommendationBanner() {
    return Consumer2<UserAccountsProvider, EventsProvider>(
      builder: (context, accountsProvider, eventsProvider, _) {
        if (!accountsProvider.hasAccounts) return const SizedBox.shrink();

        final count =
            accountsProvider.getRecommendations(eventsProvider.allEvents).length;

        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const RecommendedEventsScreen()),
          ),
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.indigo.shade600, Colors.indigo.shade400],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.recommend, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    count > 0
                        ? '내 계좌 기반 추천 이벤트 $count개'
                        : '현재 추천 이벤트가 없습니다',
                    style: TextStyle(
                      color: count > 0 ? Colors.white : Colors.white70,
                      fontSize: 13,
                      fontWeight: count > 0
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right,
                    color: Colors.white70, size: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── 참여 제한 경고 ────────────────────────────────────────────
  Widget _buildParticipationWarning() {
    return Consumer2<EventsProvider, ParticipatedEventsProvider>(
      builder: (context, eventsProvider, participatedProvider, _) {
        final restrictions = participatedProvider.getRestrictions(
          brokerages: eventsProvider.selectedBrokerages,
          categories: eventsProvider.selectedCategories,
        );
        if (restrictions.isEmpty) return const SizedBox.shrink();

        return Column(
          children: restrictions.map((r) {
            return Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                border: Border.all(color: Colors.orange.shade300),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Colors.orange[700], size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_fmtDate(r.nextEligibleDate!)} 이후 참여 가능합니다.',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange[800],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '이전 참여 이벤트: ${r.eventTitle}\n이벤트 참여 가능한지 확인해 주세요.',
                          style: TextStyle(
                              fontSize: 12, color: Colors.orange[700]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // ─── 이벤트 목록 ───────────────────────────────────────────────
  Widget _buildEventList() {
    return Expanded(
      child: Consumer<EventsProvider>(
        builder: (context, provider, _) {
          if (provider.loadingState == LoadingState.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.loadingState == LoadingState.error) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                  const SizedBox(height: 12),
                  Text(provider.errorMessage ?? '오류가 발생했습니다'),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: provider.loadEvents,
                    child: const Text('다시 시도'),
                  ),
                ],
              ),
            );
          }

          final events = provider.events;
          if (events.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.search_off, size: 48, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  Text(
                    '해당하는 이벤트가 없습니다',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                  if (provider.hasActiveFilters) ...[
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: provider.clearFilters,
                      child: const Text('필터 초기화'),
                    ),
                  ],
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: provider.refreshEvents,
            child: ListView.builder(
              padding: const EdgeInsets.only(top: 4, bottom: 20),
              itemCount: events.length,
              itemBuilder: (context, index) {
                final event = events[index];
                return EventCard(
                  event: event,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EventDetailScreen(event: event),
                    ),
                  ),
                  onBookmark: () => provider.toggleBookmark(event.id),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
