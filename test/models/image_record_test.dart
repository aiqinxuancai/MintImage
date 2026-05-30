import 'package:flutter_test/flutter_test.dart';
import 'package:mint_image/core/models/generation_request.dart';
import 'package:mint_image/core/models/image_record.dart';

void main() {
  test('pending records start unstarred and copyWith can toggle favorite', () {
    final record = ImageRecord.pending(
      id: 'record-0',
      request: const GenerationRequest(
        prompt: 'city',
        imagePaths: [],
        sizePreset: SizePreset.square1k,
        customWidth: 1024,
        customHeight: 1024,
        quality: ImageQuality.medium,
        count: 1,
        apiProfileId: 'default',
      ),
      model: 'gpt-image-2',
      createdAt: DateTime(2026, 5, 10),
    );

    final favorited = record.copyWith(isFavorite: true);
    final autoFavorited = ImageRecord.pending(
      id: 'record-0b',
      request: const GenerationRequest(
        prompt: 'city',
        imagePaths: [],
        sizePreset: SizePreset.square1k,
        customWidth: 1024,
        customHeight: 1024,
        quality: ImageQuality.medium,
        count: 1,
        apiProfileId: 'default',
      ),
      model: 'gpt-image-2',
      createdAt: DateTime(2026, 5, 10),
      isFavorite: true,
    );

    expect(record.isFavorite, isFalse);
    expect(record.outputFormat, 'png');
    expect(favorited.isFavorite, isTrue);
    expect(autoFavorited.isFavorite, isTrue);
  });

  test('markCancelled clears transient generation state', () {
    final record = ImageRecord(
      id: 'record-1',
      prompt: 'calm sky',
      apiProfileId: 'default',
      sourceImagePath: 'source.png',
      sourceImagePaths: const ['source.png'],
      resultImagePath: 'result.png',
      resultImageUrl: 'https://example.com/result.png',
      resultB64: 'abc123',
      width: 1024,
      height: 1024,
      quality: 'medium',
      outputFormat: 'webp',
      model: 'gpt-image-2',
      status: ImageRecordStatus.loading,
      errorMessage: 'temporary',
      rawApiResponseValue: 'raw-value',
      createdAt: DateTime(2026, 5, 10),
      durationMs: 1234,
      usedSingleImageFallback: true,
      isFavorite: true,
    );

    final cancelled = record.markCancelled();

    expect(cancelled.status, ImageRecordStatus.cancelled);
    expect(cancelled.errorMessage, isNull);
    expect(cancelled.resultImagePath, isNull);
    expect(cancelled.resultImageUrl, isNull);
    expect(cancelled.resultB64, isNull);
    expect(cancelled.outputFormat, 'webp');
    expect(cancelled.rawApiResponseValue, isNull);
    expect(cancelled.usedSingleImageFallback, isFalse);
    expect(cancelled.sourceImagePath, 'source.png');
    expect(cancelled.sourceImagePaths, const ['source.png']);
    expect(cancelled.durationMs, 1234);
    expect(cancelled.isFavorite, isTrue);
  });

  test('recoverInterruptedGeneration only changes active records', () {
    final loadingRecord = ImageRecord(
      id: 'record-2',
      prompt: 'ocean',
      apiProfileId: 'default',
      sourceImagePath: null,
      sourceImagePaths: const [],
      resultImagePath: null,
      resultImageUrl: null,
      resultB64: null,
      width: 1024,
      height: 1024,
      quality: 'low',
      outputFormat: 'png',
      model: 'gpt-image-2',
      status: ImageRecordStatus.loading,
      errorMessage: null,
      rawApiResponseValue: null,
      createdAt: DateTime(2026, 5, 10),
      durationMs: null,
      usedSingleImageFallback: false,
      isFavorite: false,
    );
    final doneRecord = ImageRecord(
      id: 'record-3',
      prompt: 'forest',
      apiProfileId: 'default',
      sourceImagePath: null,
      sourceImagePaths: const [],
      resultImagePath: 'result.png',
      resultImageUrl: null,
      resultB64: null,
      width: 1024,
      height: 1024,
      quality: 'low',
      outputFormat: 'jpeg',
      model: 'gpt-image-2',
      status: ImageRecordStatus.done,
      errorMessage: null,
      rawApiResponseValue: null,
      createdAt: DateTime(2026, 5, 10),
      durationMs: 2000,
      usedSingleImageFallback: false,
      isFavorite: false,
    );

    final recoveredLoading = loadingRecord.recoverInterruptedGeneration();
    final recoveredDone = doneRecord.recoverInterruptedGeneration();

    expect(recoveredLoading.status, ImageRecordStatus.cancelled);
    expect(recoveredDone, same(doneRecord));
  });
}
