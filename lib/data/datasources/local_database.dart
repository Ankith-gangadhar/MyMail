import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class LocalDatabase {
  static const String _dbName = 'mymail_vault.db';
  static const int _dbVersion = 2;

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _dbName);

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE categories (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL DEFAULT '',
            name TEXT NOT NULL,
            is_locked INTEGER NOT NULL DEFAULT 1,
            is_default INTEGER NOT NULL DEFAULT 0,
            sort_order INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            is_deleted INTEGER NOT NULL DEFAULT 0
          )
        ''');

        await db.execute('''
          CREATE TABLE credentials (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL DEFAULT '',
            category_id TEXT NOT NULL,
            email_cipher TEXT NOT NULL,
            email_nonce TEXT NOT NULL,
            email_mac TEXT NOT NULL,
            password_cipher TEXT NOT NULL,
            password_nonce TEXT NOT NULL,
            password_mac TEXT NOT NULL,
            label_cipher TEXT,
            label_nonce TEXT,
            label_mac TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            is_deleted INTEGER NOT NULL DEFAULT 0,
            FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE CASCADE
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          try {
            await db.execute('ALTER TABLE categories ADD COLUMN user_id TEXT NOT NULL DEFAULT ""');
          } catch (_) {}
          try {
            await db.execute('ALTER TABLE credentials ADD COLUMN user_id TEXT NOT NULL DEFAULT ""');
          } catch (_) {}
        }
      },
    );
  }

  Future<void> close() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
  }
}
