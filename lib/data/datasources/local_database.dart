import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class LocalDatabase {
  static const String _dbName = 'mymail_vault.db';
  static const int _dbVersion = 1;

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

        // Prepopulate default categories: Work, Personal, and Business (unlocked by default)
        final now = DateTime.now().toUtc().toIso8601String();
        await db.insert('categories', {
          'id': 'cat_work',
          'name': 'Work',
          'is_locked': 0,
          'is_default': 1,
          'sort_order': 0,
          'created_at': now,
          'updated_at': now,
          'is_deleted': 0,
        });

        await db.insert('categories', {
          'id': 'cat_personal',
          'name': 'Personal',
          'is_locked': 0,
          'is_default': 1,
          'sort_order': 1,
          'created_at': now,
          'updated_at': now,
          'is_deleted': 0,
        });

        await db.insert('categories', {
          'id': 'cat_business',
          'name': 'Business',
          'is_locked': 0,
          'is_default': 1,
          'sort_order': 2,
          'created_at': now,
          'updated_at': now,
          'is_deleted': 0,
        });
      },
      onOpen: (db) async {
        final existing = await db.query('categories', where: 'id = ?', whereArgs: ['cat_business']);
        if (existing.isEmpty) {
          final now = DateTime.now().toUtc().toIso8601String();
          await db.insert('categories', {
            'id': 'cat_business',
            'name': 'Business',
            'is_locked': 0,
            'is_default': 1,
            'sort_order': 2,
            'created_at': now,
            'updated_at': now,
            'is_deleted': 0,
          });
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
