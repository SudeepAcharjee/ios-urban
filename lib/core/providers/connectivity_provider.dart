import 'dart:async';
import 'dart:io' show Socket;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final connectivityProvider = StreamProvider<bool>((ref) {
  final controller = StreamController<bool>();
  Timer? timer;

  Future<void> emit() async {
    if (kIsWeb) {
      try {
        final connectivity = Connectivity();
        final result = await connectivity.checkConnectivity();
        controller.add(result != ConnectivityResult.none);
      } catch (_) {
        controller.add(true);
      }
      return;
    }

    try {
      final socket = await Socket.connect(
        '8.8.8.8',
        53,
        timeout: const Duration(seconds: 2),
      );
      socket.destroy();
      controller.add(true);
    } catch (_) {
      controller.add(false);
    }
  }

  emit();
  timer = Timer.periodic(const Duration(seconds: 3), (_) => emit());

  ref.onDispose(() async {
    timer?.cancel();
    await controller.close();
  });

  return controller.stream;
});
