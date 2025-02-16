import 'package:cloud_run_backend/cloud_run_backend.dart';
import 'package:test/test.dart';

void main() {
  test('calculate', () {
    expect(calculate(), 42);
  });
}
