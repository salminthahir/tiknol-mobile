// test/helpers/mock_services.dart
// Mock classes untuk unit & widget tests

import 'package:mocktail/mocktail.dart';
import 'package:tiknol_reserve_mobile/services/order_service.dart';
import 'package:tiknol_reserve_mobile/core/api_client.dart';
import 'package:dio/dio.dart';

class MockOrderService extends Mock implements OrderService {}

class MockApiClient extends Mock implements ApiClient {}

class MockDio extends Mock implements Dio {}

class FakeCartItem extends Fake {
  // Placeholder untuk matcher CartItem jika diperlukan
}
