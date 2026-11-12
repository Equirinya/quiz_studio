import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// One HTTP client for Auth and Storage. It honours the usual proxy
/// variables (`https_proxy`, `no_proxy`), as the native SDKs do on other
/// platforms through the system settings.
final http.Client httpClient = IOClient(
  HttpClient()
    ..findProxy = HttpClient.findProxyFromEnvironment
    ..connectionTimeout = const Duration(seconds: 20),
);

/// Whether [error] means the server could not be reached at all.
bool isNetworkError(Object error) =>
    error is SocketException || error is HttpException || error is HandshakeException || error is http.ClientException;
