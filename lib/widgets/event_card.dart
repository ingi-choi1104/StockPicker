import 'package:flutter/material.dart';
import '../models/brokerage_event.dart';

class EventCard extends StatelessWidget {
  final BrokerageEvent event;
  final VoidCallback onTap;
  final VoidCallback onBookmark;

  const EventCard({
    super.key,
    required this.event,
    required this.onTap,
    required this.onBookmark,
  });

  @override
  Widget build(BuildContext context) {
    final brokerageColor = Color(event.brokerage.color);
    final categoryColor = Color(event.category.color);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 상단 색상 바 + 증권사 정보
            Container(
              decoration: BoxDecoration(
                color: brokerageColor.withValues(alpha: 0.08),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: brokerageColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        event.brokerage.name[0],
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    event.brokerage.name,
                    style: TextStyle(
                      color: brokerageColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: categoryColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      event.category.label,
                      style: TextStyle(
                        color: categoryColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  _buildStatusBadge(),
                ],
              ),
            ),
            // 이벤트 내용
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(
                event.title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: Text(
                event.description,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // 혜택 미리보기
            if (event.benefits.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: event.benefits.take(2).map((benefit) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '• $benefit',
                      style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                    ),
                  )).toList(),
                ),
              ),
            // 하단 날짜 + 북마크
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Row(
                children: [
                  Icon(Icons.calendar_today_outlined, size: 13, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    _formatDateRange(),
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                  if (event.isActive && event.daysLeft >= 0 && event.daysLeft <= 7) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'D-${event.daysLeft}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.red[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      event.isBookmarked ? Icons.bookmark : Icons.bookmark_outline,
                      color: event.isBookmarked ? Colors.amber[700] : Colors.grey[400],
                    ),
                    onPressed: onBookmark,
                    iconSize: 22,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    if (!event.isActive) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          '종료',
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '진행중',
        style: TextStyle(
          fontSize: 11,
          color: Colors.green[700],
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _formatDateRange() {
    String format(DateTime dt) =>
        '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';

    if (event.endDate == null) {
      return '${format(event.startDate)} ~';
    }
    return '${format(event.startDate)} ~ ${format(event.endDate!)}';
  }
}
