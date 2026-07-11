import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'event_dashboard_screen.dart';
import 'event_types.dart';
import '../../utils/event_status.dart';
import '../../theme/app_theme.dart';

// Spotlight banner for the community's one "featured" event (admin toggles this
// per-event via the event dashboard's tools menu). Shown above the event tabs
// on both the admin and resident event list screens; renders nothing if no
// event is currently featured.
class FeaturedEventBanner extends StatelessWidget {
  final bool isAdmin;
  const FeaturedEventBanner({super.key, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('events')
          .where('featured', isEqualTo: true)
          .limit(1)
          .snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return const SizedBox.shrink();

        final doc = docs.first;
        final data = doc.data() as Map<String, dynamic>;
        final name = data['name'] as String? ?? '';
        final status = data['status'] as String? ?? 'active';
        final double target = ((data['targetAmount'] ?? 0) as num).toDouble();
        final double collected = ((data['totalCollected'] ?? 0) as num).toDouble();
        final double progress = target > 0 ? (collected / target).clamp(0.0, 1.0) : 0.0;
        final eventType = eventTypeById(data['eventTypeId'] as String?) ??
            eventTypeByName(name);
        final gradientColors = eventType?.gradient ??
            [AppTheme.accent, AppTheme.accent.shade300];
        final imageUrl = (data['bannerUrl'] as String?)?.isNotEmpty == true
            ? data['bannerUrl'] as String
            : (eventType?.imageUrl ?? '');
        final tagline = eventType?.tagline ?? '';

        return Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
          child: GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => EventDashboardScreen(
                  eventId: doc.id,
                  eventName: name,
                  isAdmin: isAdmin,
                ),
              ),
            ),
            child: Container(
              height: 110,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: gradientColors.first.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4)),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (imageUrl.isNotEmpty)
                      CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          decoration: BoxDecoration(
                              gradient: LinearGradient(
                                  colors: gradientColors,
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight)),
                        ),
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                            gradient: LinearGradient(
                                colors: gradientColors,
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight)),
                      ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.black.withValues(alpha: 0.15),
                            Colors.black.withValues(alpha: 0.75),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade600,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.star, size: 12, color: Colors.white),
                                    SizedBox(width: 3),
                                    Text('FEATURED',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: eventStatusColor(status).withValues(alpha: 0.85),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(eventStatusLabel(status),
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Text(name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17)),
                          if (tagline.isNotEmpty)
                            Text(tagline,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.75),
                                    fontSize: 11)),
                          if (target > 0) ...[
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 4,
                                backgroundColor: Colors.white24,
                                valueColor: const AlwaysStoppedAnimation(Colors.amberAccent),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
