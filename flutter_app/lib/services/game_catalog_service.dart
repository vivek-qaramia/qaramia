import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/game.dart';

/// Streams the game catalog from Firestore (`games/{id}`). Mirrors
/// GiftCatalogService: the provider falls back to the in-code [Game.catalog]
/// when the collection is empty, so games work before any are authored (3d).
class GameCatalogService {
  final _db = FirebaseFirestore.instance;

  Stream<List<Game>> watchCatalog() {
    return _db.collection('games').snapshots().map(
          (s) => s.docs.map((d) => Game.fromJson(d.id, d.data())).toList(),
        );
  }
}
