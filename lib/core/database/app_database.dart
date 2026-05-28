import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

class ImageRecordsTable extends Table {
  TextColumn get id => text()();

  TextColumn get prompt => text()();

  TextColumn get apiProfileId => text().withDefault(const Constant(''))();

  TextColumn get sourceImagePath => text().nullable()();

  TextColumn get sourceImagePaths => text().nullable()();

  TextColumn get resultImagePath => text().nullable()();

  TextColumn get resultImageUrl => text().nullable()();

  TextColumn get resultB64 => text().nullable()();

  IntColumn get width => integer()();

  IntColumn get height => integer()();

  TextColumn get quality => text()();

  TextColumn get model => text()();

  TextColumn get status => text()();

  TextColumn get errorMessage => text().nullable()();

  TextColumn get rawApiResponseValue => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  IntColumn get durationMs => integer().nullable()();

  BoolColumn get usedSingleImageFallback =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final directory = await getApplicationSupportDirectory();
    await directory.create(recursive: true);
    final file = File(p.join(directory.path, 'gpt_image_flutter.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}

@DriftDatabase(tables: [ImageRecordsTable])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.addColumn(
          imageRecordsTable,
          imageRecordsTable.apiProfileId,
        );
        await migrator.addColumn(
          imageRecordsTable,
          imageRecordsTable.usedSingleImageFallback,
        );
      }
      if (from < 3) {
        await migrator.addColumn(
          imageRecordsTable,
          imageRecordsTable.rawApiResponseValue,
        );
      }
      if (from < 4) {
        await migrator.addColumn(
          imageRecordsTable,
          imageRecordsTable.sourceImagePaths,
        );
      }
    },
  );
}
