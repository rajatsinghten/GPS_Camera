import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gps_camera/main.dart';
import 'package:gps_camera/screens/camera_screen.dart';

void main() {
  // permission_handler talks to the platform over this channel.
  const permissionsChannel = MethodChannel(
    'flutter.baseflow.com/permissions/methods',
  );

  void mockPermissions(Object? Function(MethodCall call) respond) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          permissionsChannel,
          (call) async => respond(call),
        );
  }

  /// The camera screen is portrait-only on device, so test it on a portrait
  /// surface rather than the 800x600 landscape default.
  void usePortraitSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
  }

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissionsChannel, null);
  });

  testWidgets('opens on the permission splash', (tester) async {
    mockPermissions((_) => null);

    await tester.pumpWidget(const GPSCameraApp());

    expect(find.text('GPS Map Camera'), findsOneWidget);
    expect(find.text('Setting up permissions...'), findsOneWidget);
  });

  testWidgets('leaves the splash when the permission request fails', (
    tester,
  ) async {
    // A platform that cannot answer used to leave the gate's future
    // unresolved, stranding the app on the splash with no way forward. This is
    // the regression guard for that.
    mockPermissions((_) => throw PlatformException(code: 'unavailable'));

    await tester.pumpWidget(const GPSCameraApp());
    await tester.pump();
    await tester.pump();

    expect(find.text('Setting up permissions...'), findsNothing);
    expect(find.text('Permissions Required'), findsOneWidget);
    expect(
      find.textContaining("Couldn't reach the permission system"),
      findsOneWidget,
    );
  });

  testWidgets('opens the camera once permissions are granted', (tester) async {
    usePortraitSurface(tester);

    // Echo back whatever was requested, marked granted, so this does not
    // depend on permission_handler's internal permission ids.
    mockPermissions((call) {
      final arguments = call.arguments;
      if (arguments is List) return {for (final id in arguments) id: 1};
      return 1;
    });

    await tester.pumpWidget(const GPSCameraApp());
    await tester.pump();
    await tester.pump();

    expect(find.text('Permissions Required'), findsNothing);
    expect(find.byType(CameraScreen), findsOneWidget);
  });
}
