import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/wallet.dart';

/// Real-time stream of the current viewer's coin wallet.
final walletProvider =
    StreamProvider.family<Wallet, String>((ref, uid) {
  final ref0 = FirebaseFirestore.instance
      .collection('users').doc(uid)
      .collection('wallet').doc('default');
  return ref0.snapshots().map((snap) =>
      snap.exists ? Wallet.fromJson(snap.data()!) : const Wallet());
});

/// Real-time stream of a creator's diamond balance.
final creatorBalanceProvider =
    StreamProvider.family<CreatorBalance, String>((ref, uid) {
  final ref0 = FirebaseFirestore.instance
      .collection('users').doc(uid)
      .collection('creatorBalance').doc('default');
  return ref0.snapshots().map((snap) =>
      snap.exists ? CreatorBalance.fromJson(snap.data()!) : const CreatorBalance());
});
