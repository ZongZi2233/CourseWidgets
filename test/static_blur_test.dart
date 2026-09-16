import 'package:flutter_test/flutter_test.dart';
import 'package:coursewidgets/services/static_blur_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('StaticBlurredWallpaperService bakeCurrentWallpaper test', () async {
    final service = StaticBlurredWallpaperService.instance;
    await service.bakeCurrentWallpaper();
    print('Baked image: ${service.blurredImage}');
  });
}
