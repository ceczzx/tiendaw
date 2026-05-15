import 'dart:async';

Stream<T> createRealtimeRefreshStream<T>({
  required Future<T> Function() load,
  required List<Stream<dynamic>> triggers,
}) {
  late final StreamController<T> controller;
  final subscriptions = <StreamSubscription<dynamic>>[];
  var isLoading = false;
  var hasPendingReload = false;

  Future<void> emitSnapshot() async {
    if (controller.isClosed) {
      return;
    }

    if (isLoading) {
      hasPendingReload = true;
      return;
    }

    isLoading = true;
    try {
      do {
        hasPendingReload = false;
        final data = await load();
        if (!controller.isClosed) {
          controller.add(data);
        }
      } while (hasPendingReload && !controller.isClosed);
    } catch (error, stackTrace) {
      if (!controller.isClosed) {
        controller.addError(error, stackTrace);
      }
    } finally {
      isLoading = false;
    }
  }

  Future<void> start() async {
    if (subscriptions.isNotEmpty) {
      return;
    }

    for (final trigger in triggers) {
      subscriptions.add(
        trigger.listen(
          (_) {
            unawaited(emitSnapshot());
          },
          onError: (Object error, StackTrace stackTrace) {
            if (!controller.isClosed) {
              controller.addError(error, stackTrace);
            }
          },
        ),
      );
    }

    unawaited(emitSnapshot());
  }

  Future<void> stop() async {
    for (final subscription in subscriptions) {
      await subscription.cancel();
    }
    subscriptions.clear();
  }

  controller = StreamController<T>.broadcast(
    onListen: start,
    onCancel: () async {
      if (!controller.hasListener) {
        await stop();
      }
    },
  );

  return controller.stream;
}
