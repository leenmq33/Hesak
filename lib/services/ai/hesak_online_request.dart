import 'dart:async';
import 'dart:io';

import '../../core/data/hesak_connection.dart';

// =====================================================================
//  ONLINE REQUEST — shared wrapper for every server / API / model call.
//
//    final result = await hesakRunOnline(() => someApiCall());
//
//  - No internet before starting -> throws HesakNetworkException(wasOffline: true)
//    and the request is NOT sent.
//  - Connection lost / no reply in time -> throws
//    HesakNetworkException(wasOffline: false).
//  - Any other error is rethrown as it is.
//
//  The screen catches HesakNetworkException, stops loading, keeps the
//  user's text and shows the right Arabic message.
// =====================================================================

/// A request failed because of the internet.
class HesakNetworkException implements Exception {
  /// true = no internet before the request started (nothing was sent).
  /// false = the connection dropped (or timed out) during the request.
  final bool wasOffline;

  const HesakNetworkException({required this.wasOffline});

  @override
  String toString() => 'HesakNetworkException(wasOffline: $wasOffline)';
}

/// Default time limit for one request (prevents endless loading).
const Duration hesakRequestTimeout = Duration(seconds: 25);

/// Runs [request] only when online, with a time limit.
Future<T> hesakRunOnline<T>(
  Future<T> Function() request, {
  Duration timeout = hesakRequestTimeout,
}) async {
  if (!await HesakConnection.instance.checkNow()) {
    throw const HesakNetworkException(wasOffline: true);
  }
  try {
    return await request().timeout(timeout);
  } on SocketException {
    throw const HesakNetworkException(wasOffline: false);
  } on TimeoutException {
    throw const HesakNetworkException(wasOffline: false);
  } on HttpException {
    throw const HesakNetworkException(wasOffline: false);
  }
}