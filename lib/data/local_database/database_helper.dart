import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:scanpro/core/constants/app_constants.dart';
import 'package:scanpro/core/errors/app_exception.dart';
import 'package:scanpro/data/models/document_folder.dart';
import 'package:scanpro/data/models/scanned_document.dart';
import 'package:scanpro/data/models/scanned_page.dart';
import 'package:sqflite/sqflite.dart' hide DatabaseException;

/// Manages the local SQLite database for persisting folders, documents, and pages.
class DatabaseHelper {
  DatabaseHelper();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    try {
      final dbDir = await getDatabasesPath();
      final dbPath = p.join(dbDir, AppConstants.databaseName);

      return await openDatabase(
        dbPath,
        version: AppConstants.databaseVersion,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE folders (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              icon_key TEXT NOT NULL,
              color_value INTEGER NOT NULL,
              created_at TEXT NOT NULL,
              is_default INTEGER NOT NULL DEFAULT 0
            )
          ''');

          await db.execute('''
            CREATE TABLE documents (
              id TEXT PRIMARY KEY,
              title TEXT NOT NULL,
              folder_id TEXT,
              pdf_path TEXT,
              thumbnail_path TEXT,
              file_size_bytes INTEGER NOT NULL DEFAULT 0,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL,
              is_favorite INTEGER NOT NULL DEFAULT 0
            )
          ''');

          await db.execute('''
            CREATE TABLE pages (
              id TEXT PRIMARY KEY,
              document_id TEXT NOT NULL,
              page_number INTEGER NOT NULL,
              original_image_path TEXT NOT NULL,
              processed_image_path TEXT NOT NULL,
              created_at TEXT NOT NULL,
              ocr_text TEXT NOT NULL DEFAULT '',
              file_size_bytes INTEGER NOT NULL DEFAULT 0,
              edit_settings_json TEXT NOT NULL,
              FOREIGN KEY (document_id) REFERENCES documents (id) ON DELETE CASCADE
            )
          ''');

          // Seed default folders
          final batch = db.batch();
          for (final folder in DocumentFolder.defaultFolders()) {
            batch.insert(
              'folders',
              folder.toMap(),
              conflictAlgorithm: ConflictAlgorithm.ignore,
            );
          }
          await batch.commit(noResult: true);
        },
      );
    } catch (e) {
      throw DatabaseException(
        userMessage: 'Failed to initialize local document database.',
        cause: e,
      );
    }
  }

  // -------------------- FOLDERS --------------------

  Future<List<DocumentFolder>> getAllFolders() async {
    final db = await database;
    final rows = await db.query(
      'folders',
      orderBy: 'is_default DESC, name ASC',
    );
    return rows.map(DocumentFolder.fromMap).toList();
  }

  Future<void> insertOrUpdateFolder(DocumentFolder folder) async {
    final db = await database;
    await db.insert(
      'folders',
      folder.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteFolder(String folderId) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update(
        'documents',
        {'folder_id': null},
        where: 'folder_id = ?',
        whereArgs: [folderId],
      );
      await txn.delete(
        'folders',
        where: 'id = ? AND is_default = 0',
        whereArgs: [folderId],
      );
    });
  }

  // -------------------- DOCUMENTS & PAGES --------------------

  Future<List<ScannedDocument>> getAllDocuments() async {
    final db = await database;
    final docRows = await db.query(
      'documents',
      orderBy: 'updated_at DESC',
    );
    final pageRows = await db.query(
      'pages',
      orderBy: 'page_number ASC',
    );

    final pagesByDocId = <String, List<ScannedPage>>{};
    for (final row in pageRows) {
      final page = ScannedPage.fromMap(row);
      pagesByDocId.putIfAbsent(page.documentId, () => []).add(page);
    }

    return docRows.map((row) {
      final docId = row['id'] as String;
      return ScannedDocument.fromMap(
        row,
        pages: pagesByDocId[docId] ?? const [],
      );
    }).toList();
  }

  Future<ScannedDocument?> getDocumentById(String documentId) async {
    final db = await database;
    final docRows = await db.query(
      'documents',
      where: 'id = ?',
      whereArgs: [documentId],
      limit: 1,
    );
    if (docRows.isEmpty) return null;

    final pageRows = await db.query(
      'pages',
      where: 'document_id = ?',
      whereArgs: [documentId],
      orderBy: 'page_number ASC',
    );
    final pages = pageRows.map(ScannedPage.fromMap).toList();
    return ScannedDocument.fromMap(docRows.first, pages: pages);
  }

  Future<void> saveDocumentWithPages(ScannedDocument document) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert(
        'documents',
        document.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.delete(
        'pages',
        where: 'document_id = ?',
        whereArgs: [document.id],
      );
      for (var i = 0; i < document.pages.length; i++) {
        final page = document.pages[i].copyWith(pageNumber: i + 1);
        await txn.insert(
          'pages',
          page.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<void> updatePage(ScannedPage page) async {
    final db = await database;
    await db.insert(
      'pages',
      page.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteDocumentById(String documentId) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(
        'pages',
        where: 'document_id = ?',
        whereArgs: [documentId],
      );
      await txn.delete(
        'documents',
        where: 'id = ?',
        whereArgs: [documentId],
      );
    });
  }
}

/// Riverpod provider for [DatabaseHelper].
final databaseHelperProvider = Provider<DatabaseHelper>((ref) {
  return DatabaseHelper();
});

