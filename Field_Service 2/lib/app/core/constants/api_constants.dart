class ApiConstants {
  ApiConstants._();

  // ── Odoo JSON-RPC endpoints ───────────────────
  static const String authenticate  = '/web/session/authenticate';
  static const String dbList        = '/web/database/list';
  static const String sessionInfo   = '/web/session/get_session_info';
  static const String logout        = '/web/session/destroy';
  /// JSON-RPC `call` with session cookie (same as Odoo web client).
  static const String callKw        = '/web/dataset/call_kw';

  /// Verifies the TOTP code when 2-factor auth is enabled on the Odoo account.
  /// Requires a pre-auth session cookie set by /web/session/authenticate.
  static const String totpCheck     = '/auth/totp/json';

  // ── Request config ────────────────────────────
  static const int connectTimeout   = 15000; // ms
  static const int receiveTimeout   = 15000; // ms

  // ── JSON-RPC base ─────────────────────────────
  static const String jsonrpc       = '2.0';
  static const String method        = 'call';
}