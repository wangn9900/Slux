import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/remote_resource_service.dart';

final remoteResourceProvider = Provider((ref) => RemoteResourceService());
