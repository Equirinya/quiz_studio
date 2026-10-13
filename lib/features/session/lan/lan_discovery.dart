import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Port the presenter answers discovery questions on.
const int kDiscoveryPort = 47801;

/// Lets devices on the same network find the presenter of a session without
/// being told its address: they shout the session's id into the network, and
/// the presenter of that session answers with the port its server is on.
///
/// Best effort. Some networks (guest Wi-Fi, hotspots with client isolation)
/// drop broadcasts, and some phones need a permission for them; the address
/// in the join code and the one published online keep working regardless.
class LanBeacon {
  LanBeacon({required this.sessionId, required this.serverPort});

  final String sessionId;
  final int serverPort;
  RawDatagramSocket? _socket;

  /// The port actually listened on; differs from the requested one when
  /// that was 0.
  int get boundPort => _socket?.port ?? 0;

  Future<void> start({int port = kDiscoveryPort, InternetAddress? address}) async {
    final socket = await RawDatagramSocket.bind(address ?? InternetAddress.anyIPv4, port, reuseAddress: true);
    _socket = socket;
    socket.listen((event) {
      if (event != RawSocketEvent.read) return;
      final datagram = socket.receive();
      if (datagram == null) return;
      // Only whoever already knows the session id gets an answer.
      if (utf8.decode(datagram.data, allowMalformed: true) != 'QS?$sessionId') return;
      socket.send(utf8.encode('QS!$sessionId:$serverPort'), datagram.address, datagram.port);
    });
  }

  void stop() {
    _socket?.close();
    _socket = null;
  }
}

/// Asks the network for the presenter of [sessionId]. Returns its server as
/// `ip:port`, or null when nobody answers in time.
Future<String?> discoverPresenter(
  String sessionId, {
  Duration timeout = const Duration(milliseconds: 900),
  int port = kDiscoveryPort,
  InternetAddress? target,
}) async {
  RawDatagramSocket? socket;
  try {
    socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    socket.broadcastEnabled = true;
    final found = Completer<String?>();
    final sub = socket.listen((event) {
      if (event != RawSocketEvent.read) return;
      final datagram = socket!.receive();
      if (datagram == null || found.isCompleted) return;
      final reply = utf8.decode(datagram.data, allowMalformed: true);
      final prefix = 'QS!$sessionId:';
      if (!reply.startsWith(prefix)) return;
      final serverPort = int.tryParse(reply.substring(prefix.length));
      if (serverPort != null && serverPort > 0 && serverPort < 65536) {
        found.complete('${datagram.address.address}:$serverPort');
      }
    });
    socket.send(utf8.encode('QS?$sessionId'), target ?? InternetAddress('255.255.255.255'), port);
    final result = await found.future.timeout(timeout, onTimeout: () => null);
    await sub.cancel();
    return result;
  } catch (_) {
    return null;
  } finally {
    socket?.close();
  }
}
