import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:blips_mobile/features/chat/domain/chat_models.dart';

class DatabaseHelper {
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
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE messages (
        id TEXT PRIMARY KEY,
        articleId INTEGER NOT NULL,
        role TEXT NOT NULL,
        content TEXT NOT NULL,
        timestamp TEXT NOT NULL
      )
    ''');
  }

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
      print('DB: Inserted message ${message.id} for article $articleId');
    } catch (e) {
      print('DB Error: Failed to insert message: $e');
      rethrow;
    }
  }

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

  Future<void> deleteChat(int articleId) async {
    final db = await instance.database;
    await db.delete(
      'messages',
      where: 'articleId = ?',
      whereArgs: [articleId],
    );
  }

  Future<void> deleteAllChats() async {
    final db = await instance.database;
    await db.delete('messages');
  }

  Future<void> deleteMessage(String id) async {
    final db = await instance.database;
    await db.delete(
      'messages',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<int>> getChatArticleIds() async {
    final db = await instance.database;
    final result = await db.query(
      'messages',
      columns: ['articleId'],
      distinct: true,
    );
    return result.map((e) => e['articleId'] as int).toList();
  }
}
