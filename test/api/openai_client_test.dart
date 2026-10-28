import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_image/core/api/openai_client.dart';

void main() {
  test('extractErrorMessage includes HTTP status code when available', () {
    final error = DioException(
      requestOptions: RequestOptions(path: '/v1/images/generations'),
      type: DioExceptionType.badResponse,
      response: Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: '/v1/images/generations'),
        statusCode: 504,
        data: {
          'error': {'message': 'Gateway timeout'},
        },
      ),
    );

    expect(OpenAiClient.extractErrorMessage(error), 'HTTP 504：Gateway timeout');
  });

  test('extractErrorMessage preserves RightAPI string errors', () {
    final requestOptions = RequestOptions(path: '/v1/images/generations');
    final error = DioException(
      requestOptions: requestOptions,
      type: DioExceptionType.badResponse,
      response: Response<Map<String, dynamic>>(
        requestOptions: requestOptions,
        statusCode: 400,
        data: {'error': '模型已停用，请选择其他模型'},
      ),
    );

    expect(OpenAiClient.extractErrorMessage(error), 'HTTP 400：模型已停用，请选择其他模型');
  });
}
