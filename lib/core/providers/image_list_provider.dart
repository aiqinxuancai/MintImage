import 'package:flutter_riverpod/legacy.dart';

import '../database/image_record_dao.dart';
import '../models/image_record.dart';
import 'app_providers.dart';

final imageListProvider =
    StateNotifierProvider<ImageListController, List<ImageRecord>>((ref) {
      return ImageListController(
        ref.watch(imageRecordDaoProvider),
        ref.watch(initialImageRecordsProvider),
      );
    });

class ImageListController extends StateNotifier<List<ImageRecord>> {
  ImageListController(this._imageRecordDao, List<ImageRecord> initialState)
    : super(initialState);

  final ImageRecordDao _imageRecordDao;

  Future<void> reload() async {
    state = await _imageRecordDao.loadAll();
  }

  Future<void> addPending(List<ImageRecord> records) async {
    if (records.isEmpty) {
      return;
    }
    state = [...records, ...state];
    await _imageRecordDao.upsertAll(records);
  }

  Future<void> upsert(ImageRecord record) async {
    final existingIndex = state.indexWhere((item) => item.id == record.id);
    if (existingIndex == -1) {
      state = [record, ...state];
    } else {
      final updated = [...state];
      updated[existingIndex] = record;
      updated.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      state = updated;
    }

    await _imageRecordDao.upsert(record);
  }

  Future<void> removeRecord(String id) async {
    state = state.where((item) => item.id != id).toList();
    await _imageRecordDao.deleteById(id);
  }

  Future<void> toggleFavorite(String id) async {
    final existingIndex = state.indexWhere((item) => item.id == id);
    if (existingIndex == -1) {
      return;
    }

    final record = state[existingIndex];
    await upsert(record.copyWith(isFavorite: !record.isFavorite));
  }

  Future<void> clearHistory() async {
    state = const [];
    await _imageRecordDao.clearAll();
  }
}
