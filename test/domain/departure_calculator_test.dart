import 'package:flutter_test/flutter_test.dart';
import 'package:jita/domain/departure_calculator.dart';

void main() {
  late DepartureCalculator calculator;

  setUp(() {
    calculator = DepartureCalculator();
  });

  group('DepartureCalculator', () {
    final targetArrival = DateTime(2026, 3, 7, 9, 0); // 09:00
    final now = DateTime(2026, 3, 7, 7, 0); // 07:00

    test('returns correct required departure time', () {
      final result = calculator.calculate(
        targetArrival: targetArrival,
        trafficDuration: const Duration(minutes: 45),
        staticDuration: const Duration(minutes: 30),
        now: now,
      );

      // 09:00 - 45min = 08:15
      expect(result.requiredDeparture, DateTime(2026, 3, 7, 8, 15));
    });

    test('returns correct baseline departure time', () {
      final result = calculator.calculate(
        targetArrival: targetArrival,
        trafficDuration: const Duration(minutes: 45),
        staticDuration: const Duration(minutes: 30),
        now: now,
      );

      // 09:00 - 30min = 08:30
      expect(result.baselineDeparture, DateTime(2026, 3, 7, 8, 30));
    });

    test('calculates positive delta when traffic is worse', () {
      final result = calculator.calculate(
        targetArrival: targetArrival,
        trafficDuration: const Duration(minutes: 45),
        staticDuration: const Duration(minutes: 30),
        now: now,
      );

      // baseline 08:30, required 08:15 => 15 min delta
      expect(result.deltaMinutes, 15);
    });

    test('calculates zero delta when traffic matches baseline', () {
      final result = calculator.calculate(
        targetArrival: targetArrival,
        trafficDuration: const Duration(minutes: 30),
        staticDuration: const Duration(minutes: 30),
        now: now,
      );

      expect(result.deltaMinutes, 0);
    });

    test('returns negative delta when traffic is lighter than baseline', () {
      final result = calculator.calculate(
        targetArrival: targetArrival,
        trafficDuration: const Duration(minutes: 20),
        staticDuration: const Duration(minutes: 30),
        now: now,
      );

      // baseline 08:30, required 08:40 => -10 min delta
      expect(result.deltaMinutes, -10);
    });

    test('detects when user is already late', () {
      final lateNow = DateTime(2026, 3, 7, 8, 20); // 08:20

      final result = calculator.calculate(
        targetArrival: targetArrival,
        trafficDuration: const Duration(minutes: 45),
        staticDuration: const Duration(minutes: 30),
        now: lateNow, // required departure is 08:15, already past
      );

      expect(result.isLate, true);
    });

    test('user is not late when there is still time', () {
      final result = calculator.calculate(
        targetArrival: targetArrival,
        trafficDuration: const Duration(minutes: 45),
        staticDuration: const Duration(minutes: 30),
        now: now, // 07:00, required departure 08:15
      );

      expect(result.isLate, false);
    });

    group('notification logic', () {
      test('notifies on first check when traffic is worse', () {
        final result = calculator.calculate(
          targetArrival: targetArrival,
          trafficDuration: const Duration(minutes: 45),
          staticDuration: const Duration(minutes: 30),
          now: now,
        );

        expect(result.shouldNotify, true);
      });

      test('does not notify when traffic matches baseline', () {
        final result = calculator.calculate(
          targetArrival: targetArrival,
          trafficDuration: const Duration(minutes: 30),
          staticDuration: const Duration(minutes: 30),
          now: now,
        );

        expect(result.shouldNotify, false);
      });

      test('does not notify when traffic is better than baseline', () {
        final result = calculator.calculate(
          targetArrival: targetArrival,
          trafficDuration: const Duration(minutes: 20),
          staticDuration: const Duration(minutes: 30),
          now: now,
        );

        expect(result.shouldNotify, false);
      });

      test('does not re-notify when departure time unchanged', () {
        // First call — triggers notification.
        calculator.calculate(
          targetArrival: targetArrival,
          trafficDuration: const Duration(minutes: 45),
          staticDuration: const Duration(minutes: 30),
          now: now,
        );

        // Second call — same duration, no shift.
        final result = calculator.calculate(
          targetArrival: targetArrival,
          trafficDuration: const Duration(minutes: 45),
          staticDuration: const Duration(minutes: 30),
          now: now,
        );

        expect(result.shouldNotify, false);
      });

      test('re-notifies when departure shifts by >= 1 minute', () {
        // First call.
        calculator.calculate(
          targetArrival: targetArrival,
          trafficDuration: const Duration(minutes: 45),
          staticDuration: const Duration(minutes: 30),
          now: now,
        );

        // Traffic gets worse by 2 minutes — departure shifts.
        final result = calculator.calculate(
          targetArrival: targetArrival,
          trafficDuration: const Duration(minutes: 47),
          staticDuration: const Duration(minutes: 30),
          now: now,
        );

        expect(result.shouldNotify, true);
      });

      test('does not re-notify for sub-minute departure shift', () {
        // First call with 45 min traffic.
        calculator.calculate(
          targetArrival: targetArrival,
          trafficDuration: const Duration(minutes: 45),
          staticDuration: const Duration(minutes: 30),
          now: now,
        );

        // Traffic increases by only 30 seconds — less than 1 minute shift.
        final result = calculator.calculate(
          targetArrival: targetArrival,
          trafficDuration: const Duration(minutes: 45, seconds: 30),
          staticDuration: const Duration(minutes: 30),
          now: now,
        );

        expect(result.shouldNotify, false);
      });

      test('always notifies when user is late (first time)', () {
        final lateNow = DateTime(2026, 3, 7, 8, 20);

        final result = calculator.calculate(
          targetArrival: targetArrival,
          trafficDuration: const Duration(minutes: 45),
          staticDuration: const Duration(minutes: 30),
          now: lateNow,
        );

        expect(result.isLate, true);
        expect(result.shouldNotify, true);
      });

      test('reset clears notification state', () {
        // Trigger a notification.
        calculator.calculate(
          targetArrival: targetArrival,
          trafficDuration: const Duration(minutes: 45),
          staticDuration: const Duration(minutes: 30),
          now: now,
        );

        calculator.reset();

        // Same values should trigger notification again after reset.
        final result = calculator.calculate(
          targetArrival: targetArrival,
          trafficDuration: const Duration(minutes: 45),
          staticDuration: const Duration(minutes: 30),
          now: now,
        );

        expect(result.shouldNotify, true);
      });
    });

    test('handles edge case: trip already passed', () {
      final pastArrival = DateTime(2026, 3, 7, 6, 0); // 06:00 — already past

      final result = calculator.calculate(
        targetArrival: pastArrival,
        trafficDuration: const Duration(minutes: 30),
        staticDuration: const Duration(minutes: 30),
        now: now, // 07:00
      );

      // Required departure: 06:00 - 30min = 05:30, which is before 07:00.
      expect(result.isLate, true);
    });

    test('handles zero traffic duration', () {
      final result = calculator.calculate(
        targetArrival: targetArrival,
        trafficDuration: Duration.zero,
        staticDuration: Duration.zero,
        now: now,
      );

      expect(result.requiredDeparture, targetArrival);
      expect(result.deltaMinutes, 0);
      expect(result.isLate, false);
    });
  });
}
