import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/painting.dart';
import 'package:flutter_driver/driver_extension.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

void main() {
  final Completer<String> completer = Completer<String>();
  Directory testDir;
  enableFlutterDriverExtension(handler: (_) => completer.future);

  setUpAll(() async {
    final Directory extDir = await getTemporaryDirectory();
    testDir = await Directory('${extDir.path}/test').create(recursive: true);
  });

  tearDownAll(() async {
    await testDir.delete(recursive: true);
    completer.complete(null);
  });

  final Map<ResolutionPreset, Size> presetExpectedSizes =
      <ResolutionPreset, Size>{
    ResolutionPreset.low:
        Platform.isAndroid ? const Size(240, 320) : const Size(288, 352),
    ResolutionPreset.medium:
        Platform.isAndroid ? const Size(480, 720) : const Size(480, 640),
    ResolutionPreset.high: const Size(720, 1280),
    ResolutionPreset.veryHigh: const Size(1080, 1920),
    ResolutionPreset.ultraHigh: const Size(2160, 3840),
    // Don't bother checking for max here since it could be anything.
  };

  /// Verify that [actual] has dimensions that are at least as large as
  /// [expectedSize]. Allows for a mismatch in portrait vs landscape. Returns
  /// whether the dimensions exactly match.
  bool assertExpectedDimensions(Size expectedSize, Size actual) {
    expect(actual.shortestSide, lessThanOrEqualTo(expectedSize.shortestSide));
    expect(actual.longestSide, lessThanOrEqualTo(expectedSize.longestSide));
    return actual.shortestSide == expectedSize.shortestSide &&
        actual.longestSide == expectedSize.longestSide;
  }

  // This tests that the capture is no bigger than the preset, since we have
  // automatic code to fall back to smaller sizes when we need to. Returns
  // whether the image is exactly the desired resolution.
  Future<bool> testCaptureImageResolution(
      CameraController controller, ResolutionPreset preset) async {
    final Size expectedSize = presetExpectedSizes[preset];
    print(
        'Capturing photo at $preset (${expectedSize.width}x${expectedSize.height}) using camera ${controller.description.name}');

    // Take Picture
    final String filePath =
        '${testDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
    await controller.takePicture(filePath);

    // Load picture
    final File fileImage = File(filePath);
    final Image image = await decodeImageFromList(fileImage.readAsBytesSync());

    // Verify image dimensions are as expected
    expect(image, isNotNull);
    return assertExpectedDimensions(
        expectedSize, Size(image.height.toDouble(), image.width.toDouble()));
  }

  test('Capture specific image resolutions', () async {
    final List<CameraDescription> cameras = await availableCameras();
    if (cameras.isEmpty) {
      return;
    }
    for (CameraDescription cameraDescription in cameras) {
      bool previousPresetExactlySupported = true;
      for (MapEntry<ResolutionPreset, Size> preset
          in presetExpectedSizes.entries) {
        final CameraController controller =
            CameraController(cameraDescription, preset.key);
        await controller.initialize();
        final bool presetExactlySupported =
            await testCaptureImageResolution(controller, preset.key);
        assert(!(!previousPresetExactlySupported && presetExactlySupported),
            'The camera took higher resolution pictures at a lower resolution.');
        previousPresetExactlySupported = presetExactlySupported;
        await controller.dispose();
      }
    }
  });

  // This tests that the capture is no bigger than the preset, since we have
  // automatic code to fall back to smaller sizes when we need to. Returns
  // whether the image is exactly the desired resolution.
  Future<bool> testCaptureVideoResolution(
      CameraController controller, ResolutionPreset preset) async {
    final Size expectedSize = presetExpectedSizes[preset];
    print(
        'Capturing video at $preset (${expectedSize.width}x${expectedSize.height}) using camera ${controller.description.name}');

    // Take Video
    final String filePath =
        '${testDir.path}/${DateTime.now().millisecondsSinceEpoch}.mp4';
    await controller.startVideoRecording(filePath);
    sleep(const Duration(milliseconds: 300));
    await controller.stopVideoRecording();

    // Load video metadata
    final File videoFile = File(filePath);
    final VideoPlayerController videoController =
        VideoPlayerController.file(videoFile);
    await videoController.initialize();
    final Size video = videoController.value.size;

    // Verify image dimensions are as expected
    expect(video, isNotNull);
    return assertExpectedDimensions(
        expectedSize, Size(video.height, video.width));
  }

  test('Capture specific video resolutions', () async {
    final List<CameraDescription> cameras = await availableCameras();
    if (cameras.isEmpty) {
      return;
    }
    for (CameraDescription cameraDescription in cameras) {
      bool previousPresetExactlySupported = true;
      for (MapEntry<ResolutionPreset, Size> preset
          in presetExpectedSizes.entries) {
        final CameraController controller =
            CameraController(cameraDescription, preset.key);
        await controller.initialize();
        await controller.prepareForVideoRecording();
        final bool presetExactlySupported =
            await testCaptureVideoResolution(controller, preset.key);
        assert(!(!previousPresetExactlySupported && presetExactlySupported),
            'The camera took higher resolution pictures at a lower resolution.');
        previousPresetExactlySupported = presetExactlySupported;
        await controller.dispose();
      }
    }
  });
}
