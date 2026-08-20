/// True when [now]'s clock time falls within [startMinutes]–[endMinutes]
/// (minutes since midnight). Handles windows that wrap across midnight.
bool isInQuietHours(DateTime now, int startMinutes, int endMinutes) {
  if (startMinutes == endMinutes) return false;
  final current = now.hour * 60 + now.minute;
  if (startMinutes < endMinutes) {
    return current >= startMinutes && current < endMinutes;
  }
  return current >= startMinutes || current < endMinutes;
}
