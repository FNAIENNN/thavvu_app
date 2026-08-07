import 'dart:async';
import 'package:postgres/postgres.dart';
import '../config/db_config.dart';

/// Shared Postgres connection to the Thavvu Supabase pooler.
class DbClient {
  DbClient._();
  static final DbClient instance = DbClient._();

  Connection? _conn;
  bool get isConnected => _conn != null;

  Future<Connection> connect() async {
    if (_conn != null) return _conn!;
    if (!DbConfig.isConfigured) {
      throw StateError('Database credentials are not configured');
    }
    _conn = await Connection.open(
      Endpoint(
        host: DbConfig.host,
        port: DbConfig.port,
        database: DbConfig.database,
        username: DbConfig.username,
        password: DbConfig.password,
      ),
      settings: ConnectionSettings(
        sslMode: DbConfig.useSsl ? SslMode.require : SslMode.disable,
        connectTimeout: const Duration(seconds: 20),
        queryTimeout: const Duration(seconds: 30),
      ),
    );
    return _conn!;
  }

  Future<void> close() async {
    await _conn?.close();
    _conn = null;
  }

  Future<Result> query(String sql, {Object? parameters}) async {
    final c = await connect();
    if (parameters == null) {
      return c.execute(sql);
    }
    if (parameters is List) {
      return c.execute(sql, parameters: parameters);
    }
    if (parameters is Map<String, Object?>) {
      return c.execute(Sql.named(sql), parameters: parameters);
    }
    return c.execute(sql, parameters: parameters);
  }

  Future<List<Map<String, dynamic>>> maps(String sql, {Object? parameters}) async {
    final result = await query(sql, parameters: parameters);
    return result.map((row) => row.toColumnMap()).toList();
  }

  Future<Map<String, dynamic>?> mapOne(String sql, {Object? parameters}) async {
    final rows = await maps(sql, parameters: parameters);
    if (rows.isEmpty) return null;
    return rows.first;
  }
}
