import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/sponsorship.dart';
import '../services/sponsorship_service.dart';

final sponsorshipServiceProvider = Provider((ref) => SponsorshipService());

/// Stream of all currently-active sponsorships across the platform.
/// Filtered per-stream at the picker level via Sponsorship.appliesTo().
final activeSponsorshipsProvider = StreamProvider<List<Sponsorship>>((ref) {
  return ref.watch(sponsorshipServiceProvider).watchActive();
});
