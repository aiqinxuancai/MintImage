import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
import 'package:flutter_riverpod/legacy.dart';
import 'package:uuid/uuid.dart';

import '../api/openai_client.dart';
import '../models/generation_request.dart';
import '../models/generation_result.dart';
import '../models/image_record.dart';
import '../models/settings_model.dart';
import 'app_providers.dart';
import 'image_list_provider.dart';
import 'settings_provider.dart';

const _uuid = Uuid();

final generationProvider =
    StateNotifierProvider<GenerationController, GenerationState>((ref) {
      return GenerationController(ref);
    });

class GenerationState {
  const GenerationState({
    this.activeRequestIds = const <String>{},
    this.requestStartedAts = const <String, DateTime>{},
  });

  final Set<String> activeRequestIds;
  final Map<String, DateTime> requestStartedAts;

  bool get isGenerating => activeRequestIds.isNotEmpty;

  GenerationState copyWith({
    Set<String>? activeRequestIds,
    Map<String, DateTime>? requestStartedAts,
  }) {
    return GenerationState(
      activeRequestIds: activeRequestIds ?? this.activeRequestIds,
      requestStartedAts: requestStartedAts ?? this.requestStartedAts,
    );
  }
}

class GenerationController extends StateNotifier<GenerationState> {
  GenerationController(this._ref) : super(const GenerationState());

  final Ref _ref;
  final Map<String, CancelToken> _cancelTokens = {};
  final Set<String> _deletedRequestIds = <String>{};

  Future<void> submit(GenerationRequest request) async {
    final settings = _ref.read(settingsProvider);
    final profile = settings.profileById(request.apiProfileId);
    if (profile == null) {
      throw const ApiException('当前 API 配置不存在，请重新选择。');
    }

    final records = List.generate(
      request.count,
      (index) => ImageRecord.pending(
        id: _uuid.v4(),
        request: request,
        model: profile.model,
        createdAt: DateTime.now().add(Duration(milliseconds: index)),
      ),
    );

    await _ref.read(imageListProvider.notifier).addPending(records);
    await _ref.read(backgroundGenerationServiceProvider).startIfNeeded();
    state = state.copyWith(
      activeRequestIds: {
        ...state.activeRequestIds,
        ...records.map((record) => record.id),
      },
    );

    for (final record in records) {
      unawaited(
        _executeSingle(
          record: record,
          request: request,
          profile: profile,
          responseFormat: settings.responseFormat,
          timeoutSeconds: settings.requestTimeoutSeconds,
        ),
      );
    }
  }

  Future<void> retryRecord(ImageRecord record) async {
    final apiProfileId = record.apiProfileId.isNotEmpty
        ? record.apiProfileId
        : _ref.read(settingsProvider).activeProfileId;

    await submit(
      GenerationRequest(
        prompt: record.prompt,
        imagePaths: record.sourceAttachmentPaths,
        sizePreset: SizePreset.custom,
        customWidth: record.width,
        customHeight: record.height,
        quality: ImageQuality.fromApiValue(record.quality),
        count: 1,
        apiProfileId: apiProfileId,
      ),
    );
  }

  void cancel(String recordId) {
    final currentRecord = _recordById(recordId);
    if (currentRecord != null && currentRecord.isInProgress) {
      unawaited(
        _ref
            .read(imageListProvider.notifier)
            .upsert(currentRecord.markCancelled()),
      );
    }

    _cancelTokens[recordId]?.cancel();
  }

  void cancelAll() {
    for (final recordId in state.activeRequestIds) {
      cancel(recordId);
    }
  }

  Future<void> deleteRecord(String recordId) async {
    _deletedRequestIds.add(recordId);
    _cancelTokens[recordId]?.cancel();
    await _ref.read(imageListProvider.notifier).removeRecord(recordId);

    if (!_cancelTokens.containsKey(recordId)) {
      _deletedRequestIds.remove(recordId);
      await _removeActiveRequestId(recordId);
    }
  }

  Future<void> _executeSingle({
    required ImageRecord record,
    required GenerationRequest request,
    required ApiProfile profile,
    required String? responseFormat,
    required int timeoutSeconds,
  }) async {
    final imageListController = _ref.read(imageListProvider.notifier);
    final storage = _ref.read(imageStorageServiceProvider);
    final cancelToken = CancelToken();
    _cancelTokens[record.id] = cancelToken;

    if (_isRecordDeleted(record.id)) {
      cancelToken.cancel();
      return;
    }

    await imageListController.upsert(
      record.copyWith(
        status: ImageRecordStatus.loading,
        clearErrorMessage: true,
      ),
    );
    _markRequestStarted(record.id, DateTime.now());

    final stopwatch = Stopwatch()..start();

    try {
      final result = request.hasAttachments
          ? await _generateEditResult(
              request,
              profile,
              responseFormat: responseFormat,
              timeoutSeconds: timeoutSeconds,
              cancelToken: cancelToken,
            )
          : await _generateTextResult(
              request,
              profile,
              responseFormat: responseFormat,
              timeoutSeconds: timeoutSeconds,
              cancelToken: cancelToken,
            );

      if (!result.hasImageData) {
        throw const ApiException('接口已返回成功，但没有可展示的图片数据。');
      }

      if (_isRecordCancelled(record.id) || _isRecordDeleted(record.id)) {
        return;
      }

      final storedImage = await storage.storeResult(
        record.id,
        result,
        fileExtension: request.outputFormat.fileExtension,
      );
      stopwatch.stop();

      if (_isRecordCancelled(record.id) || _isRecordDeleted(record.id)) {
        return;
      }

      final updatedRecord = record.copyWith(
        status: ImageRecordStatus.done,
        resultImagePath: storedImage.localPath,
        resultImageUrl: storedImage.imageUrl,
        resultB64: result.b64Json,
        rawApiResponseValue: result.rawResponseValue,
        durationMs: stopwatch.elapsedMilliseconds,
        clearErrorMessage: true,
        usedSingleImageFallback: result.retriedWithSingleImage,
      );
      await imageListController.upsert(updatedRecord);
      if (!_isRecordDeleted(record.id)) {
        await _ref.read(notificationServiceProvider).showResult(updatedRecord);
      }
    } on ApiException catch (error) {
      stopwatch.stop();
      if (_isRecordCancelled(record.id) || _isRecordDeleted(record.id)) {
        return;
      }

      final updatedRecord = record.copyWith(
        status: ImageRecordStatus.error,
        errorMessage: error.message,
        durationMs: stopwatch.elapsedMilliseconds,
        clearResultImagePath: true,
        clearResultImageUrl: true,
        clearResultB64: true,
        clearRawApiResponseValue: true,
        usedSingleImageFallback: false,
      );
      await imageListController.upsert(updatedRecord);
      if (!_isRecordDeleted(record.id)) {
        await _ref.read(notificationServiceProvider).showResult(updatedRecord);
      }
    } on DioException catch (error) {
      stopwatch.stop();
      final updatedRecord = error.type == DioExceptionType.cancel
          ? record.markCancelled().copyWith(
              durationMs: stopwatch.elapsedMilliseconds,
            )
          : record.copyWith(
              status: ImageRecordStatus.error,
              errorMessage: OpenAiClient.extractErrorMessage(error),
              durationMs: stopwatch.elapsedMilliseconds,
              clearResultImagePath: true,
              clearResultImageUrl: true,
              clearResultB64: true,
              clearRawApiResponseValue: true,
              usedSingleImageFallback: false,
            );

      if (updatedRecord.status != ImageRecordStatus.cancelled &&
          (_isRecordCancelled(record.id) || _isRecordDeleted(record.id))) {
        return;
      }

      if (_isRecordDeleted(record.id)) {
        return;
      }

      await imageListController.upsert(updatedRecord);
      await _ref.read(notificationServiceProvider).showResult(updatedRecord);
    } catch (error) {
      stopwatch.stop();
      if (_isRecordCancelled(record.id) || _isRecordDeleted(record.id)) {
        return;
      }

      final updatedRecord = record.copyWith(
        status: ImageRecordStatus.error,
        errorMessage: error.toString(),
        durationMs: stopwatch.elapsedMilliseconds,
        clearResultImagePath: true,
        clearResultImageUrl: true,
        clearResultB64: true,
        clearRawApiResponseValue: true,
        usedSingleImageFallback: false,
      );
      await imageListController.upsert(updatedRecord);
      if (!_isRecordDeleted(record.id)) {
        await _ref.read(notificationServiceProvider).showResult(updatedRecord);
      }
    } finally {
      _cancelTokens.remove(record.id);
      await _removeActiveRequestId(record.id);
      _deletedRequestIds.remove(record.id);
    }
  }

  Future<GenerationResult> _generateTextResult(
    GenerationRequest request,
    ApiProfile profile, {
    required String? responseFormat,
    required int timeoutSeconds,
    required CancelToken cancelToken,
  }) async {
    final results = await _ref
        .read(imageGenerationApiProvider)
        .generate(
          request,
          profile,
          responseFormat: responseFormat,
          timeoutSeconds: timeoutSeconds,
          cancelToken: cancelToken,
        );
    return results.first;
  }

  Future<GenerationResult> _generateEditResult(
    GenerationRequest request,
    ApiProfile profile, {
    required String? responseFormat,
    required int timeoutSeconds,
    required CancelToken cancelToken,
  }) async {
    final editApi = _ref.read(imageEditApiProvider);

    try {
      final results = await editApi.edit(
        request,
        profile,
        responseFormat: responseFormat,
        timeoutSeconds: timeoutSeconds,
        cancelToken: cancelToken,
      );
      return results.first;
    } on ApiException {
      if (request.imagePaths.length <= 1) {
        rethrow;
      }

      final fallbackResults = await editApi.edit(
        request.copyWith(imagePaths: [request.imagePaths.first]),
        profile,
        responseFormat: responseFormat,
        timeoutSeconds: timeoutSeconds,
        cancelToken: cancelToken,
      );
      return fallbackResults.first.copyWith(retriedWithSingleImage: true);
    }
  }

  ImageRecord? _recordById(String recordId) {
    for (final record in _ref.read(imageListProvider)) {
      if (record.id == recordId) {
        return record;
      }
    }

    return null;
  }

  bool _isRecordCancelled(String recordId) {
    return _recordById(recordId)?.status == ImageRecordStatus.cancelled;
  }

  bool _isRecordDeleted(String recordId) {
    return _deletedRequestIds.contains(recordId);
  }

  Future<void> _removeActiveRequestId(String recordId) async {
    _clearRequestStarted(recordId);
    state = state.copyWith(
      activeRequestIds: {
        for (final item in state.activeRequestIds)
          if (item != recordId) item,
      },
    );

    if (state.activeRequestIds.isEmpty) {
      await _ref.read(backgroundGenerationServiceProvider).stop();
    }
  }

  void _markRequestStarted(String recordId, DateTime startedAt) {
    state = state.copyWith(
      requestStartedAts: {...state.requestStartedAts, recordId: startedAt},
    );
  }

  void _clearRequestStarted(String recordId) {
    if (!state.requestStartedAts.containsKey(recordId)) {
      return;
    }

    state = state.copyWith(
      requestStartedAts: {
        for (final entry in state.requestStartedAts.entries)
          if (entry.key != recordId) entry.key: entry.value,
      },
    );
  }
}
