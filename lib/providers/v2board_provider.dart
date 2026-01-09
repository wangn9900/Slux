import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/v2board_service.dart';

final v2boardServiceProvider = Provider<V2BoardService>((ref) {
  return V2BoardService(ref);
});
