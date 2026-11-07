import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/features/buzzers/buzzer_link.dart';
import 'package:quiz_show/features/buzzers/serial_buzzers.dart';
import 'package:quiz_show/features/buzzers/serial_protocol.dart';
import 'package:quiz_show/game/game.dart';

import 'fake_buzzer_port.dart';

void main() {
  late FakePort port;
  late BuzzerLink link;
  late List<int> presses;
  var now = 0;

  /// Lets [millis] of show time pass, polling every 10 ms as the link does.
  void run(int millis, {void Function(int tick)? each}) {
    for (var t = 0; t < millis; t += 10) {
      now += 10;
      each?.call(t ~/ 10);
      link.poll();
    }
  }

  setUp(() {
    now = 1000;
    port = FakePort();
    link = BuzzerLink(port, clock: () => now);
    presses = [];
    link.pressed.listen(presses.add);
    link.use('COM3');
  });

  tearDown(() => link.dispose());

  test('readings come in, presses fire once per press', () {
    expect(link.status.value, BuzzerStatus.silent);
    port.send('0:10,1:20\n');
    run(10);
    expect(link.status.value, BuzzerStatus.connected);
    port.send('0:900,1:20\n0:910,1:20\n');
    run(10);
    expect(presses, [0]);
    port.send('0:10,1:800\n');
    run(10);
    expect(presses, [0, 1]);
    run(100);
    expect(link.values.value, {0: 10, 1: 800});
  });

  test('a reading hovering around the threshold is one press, not many', () {
    for (final value in [500, 520, 505, 515, 500, 530, 450, 520]) {
      port.send('0:$value\n');
      run(10);
    }
    expect(presses, [0]);
    // Only a clear release arms it again.
    port.send('0:300\n');
    run(10);
    port.send('0:600\n');
    run(10);
    expect(presses, [0, 0]);
  });

  test('everything that arrived is handled at once: no backlog, no delay', () {
    // Forty lines land in a single poll; the press is in the last one.
    port.send([for (var i = 0; i < 39; i++) '0:5\n'].join());
    port.send('0:999\n');
    run(10);
    expect(presses, [0]);
    expect(link.pendingChars, 0);
    expect(link.linesTotal, 40);
  });

  test('two hours of a box sending faster than the app polls: still instant, still small', () {
    // 300 lines a second, cut at awkward places, as a serial port does. v1
    // handled one line per poll, so this is the load that made it fall
    // behind further and further.
    const twoHours = 2 * 60 * 60 * 1000;
    var pressesSeen = 0;
    var worstPending = 0;
    var carry = '';
    run(twoHours, each: (tick) {
      // Every ten minutes somebody buzzes.
      final buzz = tick > 0 && tick % 60000 == 0;
      final text = carry + (buzz ? '0:7\n0:950\n0:7' : '0:7\n0:7\n0:7');
      // Hold the last few characters back until the next poll.
      port.send(text.substring(0, text.length - 2));
      carry = '${text.substring(text.length - 2)}\n';
      if (buzz) pressesSeen++;
      if (link.pendingChars > worstPending) worstPending = link.pendingChars;
    });
    expect(pressesSeen, 11);
    // Each one was reported within the next poll: 10 ms, not minutes.
    expect(presses, hasLength(pressesSeen));
    expect(worstPending, lessThan(16));
    expect(link.status.value, BuzzerStatus.connected);
    expect(link.reconnects, 0);
    expect(link.linesTotal, greaterThan(2000000));
  });

  test('unplugging and replugging the box heals by itself', () {
    port.send('0:10\n');
    run(10);
    expect(link.status.value, BuzzerStatus.connected);

    port
      ..plugged = false
      ..failReads = true;
    run(10);
    expect(link.status.value, BuzzerStatus.disconnected);
    final attempts = port.opens;
    run(10000);
    expect(link.status.value, BuzzerStatus.disconnected);
    // It keeps trying, at a steady pace rather than in a tight loop.
    expect(port.opens - attempts, inInclusiveRange(4, 6));

    port
      ..plugged = true
      ..failReads = false;
    run(2500);
    port.send('0:999\n');
    run(10);
    expect(link.status.value, BuzzerStatus.connected);
    expect(presses, [0]);
  });

  test('a buzzer held down when the box dropped out is not stuck "held"', () {
    port.send('0:999\n');
    run(10);
    expect(link.detector.down, {0});
    port.failReads = true;
    run(10);
    expect(link.detector.down, isEmpty);
    port.failReads = false;
    run(2500);
    port.send('0:999\n');
    run(10);
    expect(presses, [0, 0]);
  });

  test('a port that stays open but goes mute is reopened', () {
    port.send('0:10\n');
    run(10);
    final opens = port.opens;
    run(2900);
    expect(link.status.value, BuzzerStatus.connected);
    run(200);
    expect(link.status.value, BuzzerStatus.silent);
    run(4000);
    expect(port.opens, greaterThan(opens));
    port.send('0:10\n');
    run(10);
    expect(link.status.value, BuzzerStatus.connected);
  });

  test('garbage on the line is skipped without losing what follows', () {
    port.send('\x00\xff garbage\n::::\n0:999\n');
    run(10);
    expect(presses, [0]);
  });

  test('the screen is refreshed at its own pace, presses are not held back for it', () {
    var repaints = 0;
    link.values.addListener(() => repaints++);
    run(2100, each: (_) => port.send('0:5\n'));
    expect(repaints, inInclusiveRange(25, 40));
    expect(link.rate.value, closeTo(100, 5));
  });

  test('without a port chosen nothing is opened', () {
    link.use(null);
    final opens = port.opens;
    run(5000);
    expect(link.status.value, BuzzerStatus.notConfigured);
    expect(port.opens, opens);
  });

  test('a device without serial ports says so', () {
    final none = BuzzerLink(null);
    none.use('COM1');
    expect(none.status.value, BuzzerStatus.unsupported);
    none.dispose();
  });

  group('calibration', () {
    test('puts the threshold halfway between rest and press', () {
      final calibration = BuzzerCalibration()
        ..add({0: 20, 1: 100})
        ..add({0: 35, 1: 90})
        ..startPressing()
        ..add({0: 30, 1: 110})
        ..add({0: 835, 1: 105})
        ..add({0: 600, 1: 100});
      expect(calibration.calibrated, {0});
      expect(calibration.thresholds, {0: 435});
    });

    test('a buzzer that was not pressed clearly is left alone', () {
      final calibration = BuzzerCalibration()
        ..add({0: 500})
        ..startPressing()
        ..add({0: 530});
      expect(calibration.thresholds, isEmpty);
    });
  });

  group('which team a buzzer belongs to', () {
    const teams = [Team(id: 'red', name: 'Red'), Team(id: 'blue', name: 'Blue'), Team(id: 'green', name: 'Green')];

    test('by position when nothing is assigned', () {
      expect(teamForBuzzer(0, teams, const {}), 'red');
      expect(teamForBuzzer(2, teams, const {}), 'green');
      expect(teamForBuzzer(3, teams, const {}), isNull);
    });

    test('an assigned buzzer follows its team, wherever the team stands', () {
      expect(teamForBuzzer(5, teams, const {5: 'blue'}), 'blue');
      final reordered = [teams[1], teams[0], teams[2]];
      expect(teamForBuzzer(5, reordered, const {5: 'blue'}), 'blue');
    });

    test('a team with its own buzzer does not also answer to one by position', () {
      // Buzzer 5 is Red's. Buzzer 0 would be Red's by position: it is nobody's now.
      expect(teamForBuzzer(0, teams, const {5: 'red'}), isNull);
      expect(teamForBuzzer(1, teams, const {5: 'red'}), 'blue');
    });

    test('an assignment to a team that no longer exists falls back to position', () {
      expect(teamForBuzzer(1, teams, const {1: 'gone'}), 'blue');
    });
  });
}
