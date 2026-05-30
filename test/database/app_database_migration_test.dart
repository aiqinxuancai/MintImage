import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_image/core/database/app_database.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('migration skips duplicate columns and backfills output format', () async {
    final sqlite = sqlite3.openInMemory();
    sqlite.execute('''
      CREATE TABLE image_records_table (
        id TEXT NOT NULL PRIMARY KEY,
        prompt TEXT NOT NULL,
        api_profile_id TEXT NOT NULL DEFAULT '',
        source_image_path TEXT NULL,
        source_image_paths TEXT NULL,
        result_image_path TEXT NULL,
        result_image_url TEXT NULL,
        result_b64 TEXT NULL,
        width INTEGER NOT NULL,
        height INTEGER NOT NULL,
        quality TEXT NOT NULL,
        model TEXT NOT NULL,
        status TEXT NOT NULL,
        error_message TEXT NULL,
        raw_api_response_value TEXT NULL,
        created_at INTEGER NOT NULL,
        duration_ms INTEGER NULL,
        used_single_image_fallback INTEGER NOT NULL DEFAULT 0
          CHECK (used_single_image_fallback IN (0, 1)),
        is_favorite INTEGER NOT NULL DEFAULT 0
          CHECK (is_favorite IN (0, 1))
      );
    ''');
    sqlite.execute('''
      INSERT INTO image_records_table (
        id, prompt, api_profile_id, width, height, quality, model, status,
        created_at, result_image_path
      ) VALUES (
        'record-webp', 'city', 'api', 1024, 1024, 'medium', 'gpt-image-2',
        'done', 0, 'C:/tmp/record-webp.webp'
      );
    ''');
    sqlite.execute('PRAGMA user_version = 4;');

    final database = AppDatabase.forTesting(
      NativeDatabase.opened(sqlite, closeUnderlyingOnClose: true),
    );
    addTearDown(database.close);

    await database.customSelect('SELECT 1').get();

    final columns = await database
        .customSelect("PRAGMA table_info('image_records_table')")
        .get();
    expect(
      columns.where((row) => row.data['name'] == 'is_favorite'),
      hasLength(1),
    );
    expect(
      columns.where((row) => row.data['name'] == 'output_format'),
      hasLength(1),
    );
    final rows = await database
        .customSelect(
          "SELECT output_format FROM image_records_table WHERE id = 'record-webp'",
        )
        .get();
    expect(rows.single.data['output_format'], 'webp');

    final favoriteTables = await database
        .customSelect(
          "SELECT name FROM sqlite_master "
          "WHERE type = 'table' AND name = 'favorite_folders_table'",
        )
        .get();
    expect(favoriteTables, isNotEmpty);
  });
}
