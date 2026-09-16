import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Test saveLayer blur vs drawImageRect', () async {
    // 1. Create a 10x10 sharp checkerboard image
    final srcRecorder = ui.PictureRecorder();
    final srcCanvas = Canvas(srcRecorder);
    srcCanvas.drawRect(const Rect.fromLTWH(0, 0, 5, 10), Paint()..color = Colors.white);
    srcCanvas.drawRect(const Rect.fromLTWH(5, 0, 5, 10), Paint()..color = Colors.black);
    final sharpImg = await srcRecorder.endRecording().toImage(10, 10);

    // 2. Draw with saveLayer blur
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final dstRect = const Rect.fromLTWH(0, 0, 100, 100);

    canvas.saveLayer(dstRect, Paint()..imageFilter = ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10, tileMode: TileMode.clamp));
    canvas.drawImageRect(sharpImg, const Rect.fromLTWH(0, 0, 10, 10), dstRect, Paint());
    canvas.restore();

    final pic = recorder.endRecording();
    final img = await pic.toImage(100, 100);
    expect(img.width, 100);
    
    // Read pixels to ensure blur occurred (boundary should be blended gray, not sharp white/black)
    final byteData = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    expect(byteData, isNotNull);
    // Pixel near center (50, 50) should be gray, around 128
    final pixelIndex = (50 * 100 + 50) * 4;
    final r = byteData!.getUint8(pixelIndex);
    print('Pixel at center: R=$r (expect blended around 128)');
    expect(r > 50 && r < 200, true);
    print('saveLayer blur with drawImageRect verified successfully!');
  });
}
