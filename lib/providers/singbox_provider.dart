import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/singbox_service.dart';

final singboxServiceProvider = Provider<ISingboxService>((ref) {
  if (Platform.isAndroid || Platform.isIOS) {
    return MobileSingboxService();
  } else {
    return DesktopSingboxService();
  }
});
