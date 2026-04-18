import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:blips_mobile/core/error/app_logger.dart';
import 'package:blips_mobile/features/chat/domain/chat_models.dart';

abstract interface class ChatLocalStore {
  Future<void> insertMessage(int articleId, ChatMessage message);
  Future<List<ChatMessage>> getMessages(int articleId);
  Future<void> deleteChat(int articleId);
  Future<void> deleteAllChats();
  Future<void> deleteMessage(String id);
  Future<List<int>> getChatArticleIds();
  Future<String?> getLastResponseId(int articleId);
  Future<void> setLastResponseId(int articleId, String? responseId);
}

class DatabaseHelper implements ChatLocalStore {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('blips_chat.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE messages (
        id TEXT PRIMARY KEY,
        articleId INTEGER NOT NULL,
        role TEXT NOT NULL,
        content TEXT NOT NULL,
        timestamp TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE chat_metadata (
        articleId INTEGER PRIMARY KEY,
        lastResponseId TEXT
      )
    ''');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS chat_metadata (
          articleId INTEGER PRIMARY KEY,
          lastResponseId TEXT
        )
      ''');
    }
  }

  @override
  Future<void> insertMessage(int articleId, ChatMessage message) async {
    try {
      final db = await instance.database;
      await db.insert(
        'messages',
        {
          'id': message.id,
          'articleId': articleId,
          'role': message.role,
          'content': message.content,
          'timestamp': message.timestamp.toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      logger.debug('Inserted message ${message.id} for article $articleId');
    } catch (e, stack) {
      logger.error(
        'Failed to insert chat message',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  @override
  Future<List<ChatMessage>> getMessages(int articleId) async {
    final db = await instance.database;
    final result = await db.query(
      'messages',
      where: 'articleId = ?',
      whereArgs: [articleId],
      orderBy: 'timestamp ASC',
    );

    return result
        .map((json) => ChatMessage(
              id: json['id'] as String,
              role: json['role'] as String,
              content: json['content'] as String,
              timestamp: DateTime.parse(json['timestamp'] as String),
            ))
        .toList();
  }

  @override
  Future<void> deleteChat(int articleId) async {
    final db = await instance.database;
    await db.delete(
      'messages',
      where: 'articleId = ?',
      whereArgs: [articleId],
    );
    await db.delete(
      'chat_metadata',
      where: 'articleId = ?',
      whereArgs: [articleId],
    );
  }

  @override
  Future<void> deleteAllChats() async {
    final db = await instance.database;
    await db.delete('messages');
    await db.delete('chat_metadata');
  }

  @override
  Future<void> deleteMessage(String id) async {
    final db = await instance.database;
    await db.delete(
      'messages',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<List<int>> getChatArticleIds() async {
    final db = await instance.database;
    final result = await db.query(
      'messages',
      columns: ['articleId'],
      distinct: true,
    );
    return result.map((e) => e['articleId'] as int).toList();
  }

  @override
  Future<String?> getLastResponseId(int articleId) async {
    final db = await instance.database;
    final result = await db.query(
      'chat_metadata',
      columns: ['lastResponseId'],
      where: 'articleId = ?',
      whereArgs: [articleId],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return result.first['lastResponseId'] as String?;
  }

  @override
  Future<void> setLastResponseId(int articleId, String? responseId) async {
    final db = await instance.database;
    await db.insert(
      'chat_metadata',
      {
        'articleId': articleId,
        'lastResponseId': responseId,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
