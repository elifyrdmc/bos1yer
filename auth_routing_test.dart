import 'package:flutter_test/flutter_test.dart';
import 'package:parkist/auth_routing.dart';

void main() {
  test('a signed-in user skips welcome and goes to the map', () {
    expect(
      resolveAuthEntry(
        configured: true,
        bootstrapFailed: false,
        streamFailed: false,
        checkingSession: false,
        hasSession: true,
      ),
      AuthEntryDestination.map,
    );
  });

  test('a signed-out user sees a short session-check state before welcome', () {
    expect(
      resolveAuthEntry(
        configured: true,
        bootstrapFailed: false,
        streamFailed: false,
        checkingSession: true,
        hasSession: false,
      ),
      AuthEntryDestination.checkingSession,
    );
    expect(
      resolveAuthEntry(
        configured: true,
        bootstrapFailed: false,
        streamFailed: false,
        checkingSession: false,
        hasSession: false,
      ),
      AuthEntryDestination.welcome,
    );
  });

  test('session check failures offer a retry state', () {
    expect(
      resolveAuthEntry(
        configured: true,
        bootstrapFailed: false,
        streamFailed: true,
        checkingSession: false,
        hasSession: false,
      ),
      AuthEntryDestination.retry,
    );
  });
}
