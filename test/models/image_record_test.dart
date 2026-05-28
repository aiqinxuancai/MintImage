import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_image_flutter/core/models/image_record.dart';

void main() {
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
      model: 'gpt-image-2',
      status: ImageRecordStatus.loading,
      errorMessage: 'temporary',
      rawApiResponseValue: 'raw-value',
      createdAt: DateTime(2026, 5, 10),
      durationMs: 1234,
      usedSingleImageFallback: true,
    );

    final cancelled = record.markCancelled();

    expect(cancelled.status, ImageRecordStatus.cancelled);
    expect(cancelled.errorMessage, isNull);
    expect(cancelled.resultImagePath, isNull);
    expect(cancelled.resultImageUrl, isNull);
    expect(cancelled.resultB64, isNull);
    expect(cancelled.rawApiResponseValue, isNull);
    expect(cancelled.usedSingleImageFallback, isFalse);
    expect(cancelled.sourceImagePath, 'source.png');
    expect(cancelled.sourceImagePaths, const ['source.png']);
    expect(cancelled.durationMs, 1234);
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
      model: 'gpt-image-2',
      status: ImageRecordStatus.loading,
      errorMessage: null,
      rawApiResponseValue: null,
      createdAt: DateTime(2026, 5, 10),
      durationMs: null,
      usedSingleImageFallback: false,
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
      model: 'gpt-image-2',
      status: ImageRecordStatus.done,
      errorMessage: null,
      rawApiResponseValue: null,
      createdAt: DateTime(2026, 5, 10),
      durationMs: 2000,
      usedSingleImageFallback: false,
    );

    final recoveredLoading = loadingRecord.recoverInterruptedGeneration();
    final recoveredDone = doneRecord.recoverInterruptedGeneration();

    expect(recoveredLoading.status, ImageRecordStatus.cancelled);
    expect(recoveredDone, same(doneRecord));
  });
}
