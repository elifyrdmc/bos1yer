/// Pure routing decision used by the startup gate and unit tests.
enum AuthEntryDestination { startupError, checkingSession, welcome, map, retry }

AuthEntryDestination resolveAuthEntry({
  required bool configured,
  required bool bootstrapFailed,
  required bool streamFailed,
  required bool checkingSession,
  required bool hasSession,
}) {
  if (bootstrapFailed) return AuthEntryDestination.startupError;
  if (!configured) return AuthEntryDestination.welcome;
  if (streamFailed) return AuthEntryDestination.retry;
  if (checkingSession && !hasSession) {
    return AuthEntryDestination.checkingSession;
  }
  return hasSession ? AuthEntryDestination.map : AuthEntryDestination.welcome;
}
