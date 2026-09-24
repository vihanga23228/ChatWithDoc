import 'api_client.dart';
import 'auth_service.dart';
import 'backend.dart';
import 'realtime_service.dart';

/// App-wide singletons, created once in main().
class Services {
  static final TokenStore tokens = TokenStore();
  static final ApiClient api = ApiClient(tokens);
  static final AuthService auth = AuthService(api);
  static final Backend backend = Backend(api);
  static final RealtimeService realtime = RealtimeService(api);
}
