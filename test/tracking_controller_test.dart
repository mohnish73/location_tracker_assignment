import 'dart:async';

import 'package:assignmentproject/app/controllers/permission_controller.dart';
import 'package:assignmentproject/app/controllers/tracking_controller.dart';
import 'package:assignmentproject/app/data/channel_result.dart';
import 'package:assignmentproject/app/data/tracker_channel.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

const _methodChannel = MethodChannel(TrackerChannel.methodChannelName);
const _eventChannel = EventChannel(TrackerChannel.eventChannelName);

final _storedFix = <String, Object?>{
  'id': 7,
  'latitude': 12.9716,
  'longitude': 77.5946,
  'accuracy': 4.5,
  'timestamp': 1760000000000,
};

final _permissions = <String, Object?>{
  'location': 'granted',
  'backgroundLocation': 'granted',
  'notification': 'granted',
  'locationServicesEnabled': true,
  'ignoringBatteryOptimizations': true,
  'sdkInt': 34,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late List<String> calls;
  late StreamController<Object?> nativeEvents;

  setUp(() {
    Get.testMode = true;
    calls = [];
    nativeEvents = StreamController<Object?>();

    messenger.setMockMethodCallHandler(_methodChannel, (call) async {
      calls.add(call.method);
      return switch (call.method) {
        TrackerMethods.getLastLocation => _storedFix,
        TrackerMethods.getTrackingStatus => {'isRunning': true, 'trackingEnabled': true, 'intervalMs': 30000},
        TrackerMethods.getPermissionStatus => _permissions,
        TrackerMethods.startTracking =>
          throw PlatformException(code: 'LOCATION_DISABLED', message: 'Location services are turned off.'),
        _ => null,
      };
    });

    messenger.setMockStreamHandler(
      _eventChannel,
      MockStreamHandler.inline(onListen: (_, sink) => nativeEvents.stream.listen(sink.success)),
    );

    final channel = Get.put(TrackerChannel());
    final permissions = Get.put(PermissionController(channel));
    Get.put(TrackingController(channel, permissions));
  });

  tearDown(() async {
    Get.reset();
    await nativeEvents.close();
    messenger.setMockMethodCallHandler(_methodChannel, null);
    messenger.setMockStreamHandler(_eventChannel, null);
  });

  test('first launch shows the last location stored in SQLite and the service status', () async {
    final controller = Get.find<TrackingController>();
    await controller.loadInitialState();

    expect(controller.lastLocation.value?.id, 7);
    expect(controller.lastLocation.value?.latitude, 12.9716);
    expect(controller.isRunning.value, isTrue);
    expect(controller.interval.value, const Duration(seconds: 30));
    expect(controller.isLoading.value, isFalse);
  });

  test('a live fix on the EventChannel updates the UI state reactively', () async {
    final controller = Get.find<TrackingController>();
    await controller.loadInitialState();

    nativeEvents.add({..._storedFix, 'type': 'location', 'id': 8, 'latitude': 13.0});
    await pumpEventQueue();

    expect(controller.lastLocation.value?.id, 8);
    expect(controller.lastLocation.value?.latitude, 13.0);
    expect(controller.liveFixCount.value, 1);
  });

  test('service status events (e.g. Stop from the notification) update isRunning', () async {
    final controller = Get.find<TrackingController>();
    await controller.loadInitialState();

    nativeEvents.add({'type': 'status', 'isRunning': false});
    await pumpEventQueue();

    expect(controller.isRunning.value, isFalse);
  });

  test('native errors come back as a structured ChannelFailure, not an exception', () async {
    final result = await Get.find<TrackerChannel>().startTracking();

    expect(result, isA<ChannelFailure<Object?>>());
    final error = (result as ChannelFailure).error;
    expect(error.code, NativeErrorCode.locationDisabled);
    expect(error.message, 'Location services are turned off.');
  });

  test('unknown methods map to NOT_IMPLEMENTED instead of throwing', () async {
    messenger.setMockMethodCallHandler(_methodChannel, null);
    final result = await Get.find<TrackerChannel>().getRecordCount();

    expect((result as ChannelFailure).error.code, NativeErrorCode.notImplemented);
  });
}
