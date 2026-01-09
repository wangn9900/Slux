import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/api/api_service.dart';

final apiServiceProvider = Provider((ref) => ApiService());
