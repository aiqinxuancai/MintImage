import 'dart:convert';

import 'package:drift/drift.dart';

import '../models/image_record.dart';
import 'app_database.dart';

class ImageRecordDao {
  const ImageRecordDao(this.database);

  final AppDatabase database;

  Future<List<ImageRecord>> loadAll() async {
    final query = database.select(database.imageRecordsTable)
      ..orderBy([(table) => OrderingTerm.desc(table.createdAt)]);

    final rows = await query.get();
    return rows.map(_toModel).toList();
  }

  Future<void> upsert(ImageRecord record) async {
    await database
        .into(database.imageRecordsTable)
        .insertOnConflictUpdate(_toCompanion(record));
  }

  Future<void> upsertAll(List<ImageRecord> records) async {
    if (records.isEmpty) {
      return;
    }

    await database.batch((batch) {
      batch.insertAllOnConflictUpdate(
        database.imageRecordsTable,
        records.map(_toCompanion).toList(),
      );
    });
  }

  Future<void> deleteById(String id) async {
    await (database.delete(
      database.imageRecordsTable,
    )..where((table) => table.id.equals(id))).go();
  }

  Future<void> clearAll() async {
    await database.delete(database.imageRecordsTable).go();
  }

  ImageRecord _toModel(ImageRecordsTableData row) {
    return ImageRecord(
      id: row.id,
      prompt: row.prompt,
      apiProfileId: row.apiProfileId,
      sourceImagePath: row.sourceImagePath,
      sourceImagePaths: _decodeSourceImagePaths(row.sourceImagePaths),
      resultImagePath: row.resultImagePath,
      resultImageUrl: row.resultImageUrl,
      resultB64: row.resultB64,
      width: row.width,
      height: row.height,
      quality: row.quality,
      model: row.model,
      status: ImageRecordStatus.fromStorageValue(row.status),
      errorMessage: row.errorMessage,
      rawApiResponseValue: row.rawApiResponseValue,
      createdAt: row.createdAt,
      durationMs: row.durationMs,
      usedSingleImageFallback: row.usedSingleImageFallback,
      isFavorite: row.isFavorite,
    );
  }

  ImageRecordsTableCompanion _toCompanion(ImageRecord record) {
    return ImageRecordsTableCompanion(
      id: Value(record.id),
      prompt: Value(record.prompt),
      apiProfileId: Value(record.apiProfileId),
      sourceImagePath: Value(record.sourceImagePath),
      sourceImagePaths: Value(_encodeSourceImagePaths(record.sourceImagePaths)),
      resultImagePath: Value(record.resultImagePath),
      resultImageUrl: Value(record.resultImageUrl),
      resultB64: Value(record.resultB64),
      width: Value(record.width),
      height: Value(record.height),
      quality: Value(record.quality),
      model: Value(record.model),
      status: Value(record.status.storageValue),
      errorMessage: Value(record.errorMessage),
      rawApiResponseValue: Value(record.rawApiResponseValue),
      createdAt: Value(record.createdAt),
      durationMs: Value(record.durationMs),
      usedSingleImageFallback: Value(record.usedSingleImageFallback),
      isFavorite: Value(record.isFavorite),
    );
  }

  List<String> _decodeSourceImagePaths(String? value) {
    if (value == null || value.isEmpty) {
      return const [];
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(value);
    } on FormatException {
      return const [];
    }
    if (decoded is! List) {
      return const [];
    }

    return decoded.whereType<String>().toList(growable: false);
  }

  String? _encodeSourceImagePaths(List<String> paths) {
    if (paths.isEmpty) {
      return null;
    }

    return jsonEncode(paths);
  }
}
