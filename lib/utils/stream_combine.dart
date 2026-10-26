import 'dart:async';

/// The latest value of every stream in [streams], as one list in the same
/// order, emitted again whenever any of them changes. Nothing is emitted until
/// each stream has produced a first value.
///
/// Used for the caregiver dashboard, which follows one stream per patient.
Stream<List<T>> combineLatestList<T>(List<Stream<T>> streams) {
  if (streams.isEmpty) return Stream.value(<T>[]);

  final subscriptions = <StreamSubscription<T>>[];
  final values = List<T?>.filled(streams.length, null);
  final received = List<bool>.filled(streams.length, false);
  late final StreamController<List<T>> controller;

  controller = StreamController<List<T>>(
    onListen: () {
      for (var i = 0; i < streams.length; i++) {
        subscriptions.add(streams[i].listen(
          (value) {
            values[i] = value;
            received[i] = true;
            if (received.every((r) => r)) {
              controller.add(List<T>.from(values));
            }
          },
          onError: controller.addError,
        ));
      }
    },
    onCancel: () async {
      for (final s in subscriptions) {
        await s.cancel();
      }
    },
  );
  return controller.stream;
}
