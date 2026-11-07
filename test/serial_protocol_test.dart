import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_show/features/buzzers/serial_protocol.dart';

void main() {
  test('lines are reassembled across chunks', () {
    final buffer = SerialLineBuffer();
    expect(buffer.add('0:12,1:'), isEmpty);
    expect(buffer.add('900\r\n0:15,'), ['0:12,1:900']);
    expect(buffer.add('1:20\n\n0:1,1:2\n'), ['0:15,1:20', '0:1,1:2']);
  });

  test('a stream without newlines does not pile up', () {
    final buffer = SerialLineBuffer();
    buffer.add('x' * 5000);
    expect(buffer.add('\n0:1\n'), ['0:1']);
  });

  test('readings are parsed; junk is skipped', () {
    expect(parseBuzzerLine('0:812,1:14'), {0: 812, 1: 14});
    expect(parseBuzzerLine(' 2 : 7 ,garbage,3:x,4:9'), {2: 7, 4: 9});
    expect(parseBuzzerLine('hello'), isNull);
    expect(parseBuzzerLine(''), isNull);
  });

  test('a press counts once, until the buzzer is released', () {
    final detector = BuzzerEdgeDetector();
    expect(detector.update({0: 100, 1: 100}), isEmpty);
    expect(detector.update({0: 900, 1: 100}), [0]);
    expect(detector.update({0: 950, 1: 600}), [1]);
    expect(detector.down, {0, 1});
    expect(detector.update({0: 100, 1: 700}), isEmpty);
    expect(detector.update({0: 900, 1: 700}), [0]);
  });

  test('each buzzer has its own threshold', () {
    final detector = BuzzerEdgeDetector()..thresholds[1] = 50;
    expect(detector.thresholdOf(0), kDefaultBuzzerThreshold);
    expect(detector.update({0: 60, 1: 60}), [1]);
  });

  test('a buzzer missing from a reading keeps its state', () {
    final detector = BuzzerEdgeDetector();
    expect(detector.update({0: 900}), [0]);
    expect(detector.update({1: 900}), [1]);
    expect(detector.update({0: 900}), isEmpty);
  });
}
