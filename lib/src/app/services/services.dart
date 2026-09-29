import 'package:chat_with_doc_core/chat_with_doc_core.dart';

/// App-wide singletons, created once in main().
class Services {
  static final TokenStore tokens = TokenStore();
  static final ApiClient api = ApiClient(tokens);
  static final AuthService auth = AuthService(api);
  static final Backend backend = Backend(api);
  static final RealtimeService realtime = RealtimeService(api);
}
