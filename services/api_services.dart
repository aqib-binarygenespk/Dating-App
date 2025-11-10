import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart';

// Must exist and provide: static Future<String?> getToken()
import '../hive_utils/hive_service.dart';

class ApiService {
  static const String baseUrl = "https://pairup.binarygenes.pk/api";

  // ---------- URL helpers ----------
  static Uri _u(String endpoint) =>
      Uri.parse('$baseUrl/${endpoint.replaceFirst(RegExp(r"^/"), "")}');

  static Uri _uWithQuery(String endpoint, Map<String, String> qp) {
    final base = _u(endpoint);
    final merged = Map<String, String>.from(base.queryParameters)..addAll(qp);
    return base.replace(queryParameters: merged);
  }

  // ---------- token helpers ----------
  static Future<String?> _autoToken(String? explicit) async {
    final t = explicit?.trim();
    if (t != null && t.isNotEmpty) return t;
    try {
      final hx = await HiveService.getToken();
      final v = hx?.trim();
      return (v != null && v.isNotEmpty) ? v : null;
    } catch (_) {
      return null;
    }
  }

  static bool _isHtml(http.Response r) =>
      (r.headers['content-type'] ?? '').contains('text/html');

  static Map<String, dynamic> _decode(http.Response r) {
    if (r.body.isEmpty) return {};
    try {
      final d = jsonDecode(r.body);
      return d is Map<String, dynamic> ? d : {'data': d};
    } catch (_) {
      return {'raw': r.body};
    }
  }

  static bool _tokenMissing401(http.Response r, Map<String, dynamic> d) {
    if (r.statusCode != 401) return false;
    final m = (d['message'] ?? '').toString();
    return m.contains('Token not provided');
  }

  // ---------- Response handling ----------
  static Map<String, dynamic> _handleResponse(
      http.Response r, Map<String, dynamic> d) {
    if (r.statusCode == 200 || r.statusCode == 201 || r.statusCode == 204) {
      return d.isNotEmpty ? d : {"success": true};
    }
    return {
      "success": false,
      "status": d['status'] ?? false,
      "message": d['message'] ?? "Something went wrong",
      "errors": d['errors'] ?? {},
      "code": r.statusCode,
    };
  }

  static Map<String, dynamic> _errorResponse(String m, int c) {
    return {"success": false, "message": m, "errors": {}, "code": c};
  }

  // ---------- POST ----------
  static Future<Map<String, dynamic>> post(
      String endpoint,
      dynamic data, {
        String? token,
        bool isJson = false,
      }) async {
    try {
      final resolvedToken = await _autoToken(token);

      final headers = <String, String>{
        "Accept": "application/json",
        if (isJson)
          "Content-Type": "application/json"
        else
          "Content-Type": "application/x-www-form-urlencoded",
        if (resolvedToken != null && resolvedToken.isNotEmpty)
          "Authorization": "Bearer $resolvedToken",
      };

      // DEBUG
      // ignore: avoid_print
      print("🧾 POST ${_u(endpoint)} HEADERS: $headers");

      final body = isJson
          ? jsonEncode(data)
          : Map<String, String>.from(
        (data as Map).map((k, v) => MapEntry(k.toString(), v.toString())),
      );

      var resp = await http.post(_u(endpoint), headers: headers, body: body);
      // ignore: avoid_print
      print("🌐 POST STATUS: ${resp.statusCode}");
      // ignore: avoid_print
      print("📩 RESPONSE BODY: ${resp.body}");

      if (_isHtml(resp)) {
        return _errorResponse(
            "Server returned HTML (possible redirect) for $endpoint",
            resp.statusCode);
      }

      var decoded = _decode(resp);

      // Fallback once if proxy stripped Authorization
      if (_tokenMissing401(resp, decoded) &&
          resolvedToken != null &&
          resolvedToken.isNotEmpty) {
        final fbUri = _uWithQuery(endpoint, {'token': resolvedToken});
        dynamic fbBody;
        if (isJson) {
          final map = Map<String, dynamic>.from(data as Map)
            ..['token'] = resolvedToken;
          fbBody = jsonEncode(map);
        } else {
          final map = Map<String, String>.from((data as Map)
              .map((k, v) => MapEntry(k.toString(), v.toString())))
            ..['token'] = resolvedToken;
          fbBody = map;
        }
        final fbHeaders = Map<String, String>.from(headers)
          ..remove('Authorization');

        // ignore: avoid_print
        print("🧾 POST (fallback) $fbUri HEADERS: $fbHeaders");

        resp = await http.post(fbUri, headers: fbHeaders, body: fbBody);
        // ignore: avoid_print
        print("🌐 POST (fallback) STATUS: ${resp.statusCode}");
        // ignore: avoid_print
        print("📩 POST (fallback) BODY: ${resp.body}");

        decoded = _decode(resp);
      }

      return _handleResponse(resp, decoded);
    } catch (e) {
      return _errorResponse("POST Error: $e", 500);
    }
  }

  // ---------- PUT ----------
  static Future<Map<String, dynamic>> put(
      String endpoint,
      dynamic data, {
        String? token,
        bool isJson = false,
      }) async {
    try {
      final resolvedToken = await _autoToken(token);

      final headers = <String, String>{
        "Accept": "application/json",
        if (isJson)
          "Content-Type": "application/json"
        else
          "Content-Type": "application/x-www-form-urlencoded",
        if (resolvedToken != null && resolvedToken.isNotEmpty)
          "Authorization": "Bearer $resolvedToken",
      };

      // ignore: avoid_print
      print("🧾 PUT ${_u(endpoint)} HEADERS: $headers");

      final body = isJson
          ? jsonEncode(data)
          : Map<String, String>.from(
        (data as Map).map((k, v) => MapEntry(k.toString(), v.toString())),
      );

      var resp = await http.put(_u(endpoint), headers: headers, body: body);
      // ignore: avoid_print
      print("🌐 PUT STATUS: ${resp.statusCode}");
      // ignore: avoid_print
      print("📩 PUT RESPONSE BODY: ${resp.body}");

      if (_isHtml(resp)) {
        return _errorResponse(
            "Server returned HTML for $endpoint", resp.statusCode);
      }

      var decoded = _decode(resp);

      if (_tokenMissing401(resp, decoded) &&
          resolvedToken != null &&
          resolvedToken.isNotEmpty) {
        final fbUri = _uWithQuery(endpoint, {'token': resolvedToken});
        dynamic fbBody;
        if (isJson) {
          final map = Map<String, dynamic>.from(data as Map)
            ..['token'] = resolvedToken;
          fbBody = jsonEncode(map);
        } else {
          final map = Map<String, String>.from((data as Map)
              .map((k, v) => MapEntry(k.toString(), v.toString())))
            ..['token'] = resolvedToken;
          fbBody = map;
        }
        final fbHeaders = Map<String, String>.from(headers)
          ..remove('Authorization');

        // ignore: avoid_print
        print("🧾 PUT (fallback) $fbUri HEADERS: $fbHeaders");

        resp = await http.put(fbUri, headers: fbHeaders, body: fbBody);
        // ignore: avoid_print
        print("🌐 PUT (fallback) STATUS: ${resp.statusCode}");
        // ignore: avoid_print
        print("📩 PUT (fallback) BODY: ${resp.body}");

        decoded = _decode(resp);
      }

      return _handleResponse(resp, decoded);
    } catch (e) {
      return _errorResponse("PUT Error: $e", 500);
    }
  }

  // ---------- JSON POST ----------
  static Future<Map<String, dynamic>> postJson(
      String endpoint,
      dynamic data, {
        String? token,
      }) async {
    try {
      final resolvedToken = await _autoToken(token);

      final headers = {
        "Accept": "application/json",
        "Content-Type": "application/json",
        if (resolvedToken?.isNotEmpty == true)
          "Authorization": "Bearer $resolvedToken",
      };

      // ignore: avoid_print
      print("🧾 JSON POST ${_u(endpoint)} HEADERS: $headers");

      var resp = await http.post(_u(endpoint),
          headers: headers, body: jsonEncode(data));

      // ignore: avoid_print
      print("🌐 JSON POST STATUS: ${resp.statusCode}");
      // ignore: avoid_print
      print("📩 JSON RESPONSE BODY: ${resp.body}");

      var decoded = _decode(resp);

      if (_tokenMissing401(resp, decoded) && resolvedToken?.isNotEmpty == true) {
        final fbUri = _uWithQuery(endpoint, {'token': resolvedToken!});
        final map = Map<String, dynamic>.from(data as Map)
          ..['token'] = resolvedToken;
        final fbHeaders = Map<String, String>.from(headers)
          ..remove('Authorization');

        // ignore: avoid_print
        print("🧾 JSON POST (fallback) $fbUri HEADERS: $fbHeaders");

        resp = await http.post(fbUri, headers: fbHeaders, body: jsonEncode(map));

        // ignore: avoid_print
        print("🌐 JSON POST (fallback) STATUS: ${resp.statusCode}");
        // ignore: avoid_print
        print("📩 JSON POST (fallback) BODY: ${resp.body}");

        decoded = _decode(resp);
      }

      return _handleResponse(resp, decoded);
    } catch (e) {
      return _errorResponse("JSON POST Error: ${e.toString()}", 500);
    }
  }

  // ---------- x-www-form-urlencoded POST ----------
  static Future<Map<String, dynamic>> postForm(
      String endpoint,
      Map<String, String> data, {
        String? token,
      }) async {
    try {
      final resolvedToken = await _autoToken(token);

      final headers = {
        "Accept": "application/json",
        "Content-Type": "application/x-www-form-urlencoded",
        if (resolvedToken?.isNotEmpty == true)
          "Authorization": "Bearer $resolvedToken",
      };

      // ignore: avoid_print
      print("🧾 FORM POST ${_u(endpoint)} HEADERS: $headers");

      var resp = await http.post(_u(endpoint), headers: headers, body: data);

      // ignore: avoid_print
      print("🌐 FORM POST STATUS: ${resp.statusCode}");
      // ignore: avoid_print
      print("📩 FORM POST RESPONSE BODY: ${resp.body}");

      var decoded = _decode(resp);

      if (_tokenMissing401(resp, decoded) && resolvedToken?.isNotEmpty == true) {
        final fbUri = _uWithQuery(endpoint, {'token': resolvedToken!});
        final fbHeaders = Map<String, String>.from(headers)
          ..remove('Authorization');
        final fbData = Map<String, String>.from(data)..['token'] = resolvedToken;

        // ignore: avoid_print
        print("🧾 FORM POST (fallback) $fbUri HEADERS: $fbHeaders");

        resp = await http.post(fbUri, headers: fbHeaders, body: fbData);

        // ignore: avoid_print
        print("🌐 FORM POST (fallback) STATUS: ${resp.statusCode}");
        // ignore: avoid_print
        print("📩 FORM POST (fallback) BODY: ${resp.body}");

        decoded = _decode(resp);
      }

      return _handleResponse(resp, decoded);
    } catch (e) {
      return _errorResponse("FORM POST Error: ${e.toString()}", 500);
    }
  }

  // ---------- GET ----------
  static Future<Map<String, dynamic>> get(
      String endpoint, {
        String? token,
      }) async {
    try {
      final resolvedToken = await _autoToken(token);

      var headers = {
        "Accept": "application/json",
        if (resolvedToken?.isNotEmpty == true)
          "Authorization": "Bearer $resolvedToken",
      };

      // ignore: avoid_print
      print("🧾 GET ${_u(endpoint)} HEADERS: $headers");

      var resp = await http.get(_u(endpoint), headers: headers);

      // ignore: avoid_print
      print("🌐 GET STATUS: ${resp.statusCode}");
      // ignore: avoid_print
      print("📩 GET RESPONSE BODY: ${resp.body}");

      var decoded = _decode(resp);

      if (_tokenMissing401(resp, decoded) && resolvedToken?.isNotEmpty == true) {
        final fbUri = _uWithQuery(endpoint, {'token': resolvedToken!});
        headers = {"Accept": "application/json"}; // no auth header

        // ignore: avoid_print
        print("🧾 GET (fallback) $fbUri HEADERS: $headers");

        resp = await http.get(fbUri, headers: headers);

        // ignore: avoid_print
        print("🌐 GET (fallback) STATUS: ${resp.statusCode}");
        // ignore: avoid_print
        print("📩 GET (fallback) BODY: ${resp.body}");

        decoded = _decode(resp);
      }

      return _handleResponse(resp, decoded);
    } catch (e) {
      return _errorResponse("GET Error: ${e.toString()}", 500);
    }
  }

  // ---------- DELETE ----------
  static Future<Map<String, dynamic>> delete(
      String endpoint, {
        String? token,
      }) async {
    try {
      final resolvedToken = await _autoToken(token);

      var headers = {
        "Accept": "application/json",
        "Content-Type": "application/json",
        if (resolvedToken?.isNotEmpty == true)
          "Authorization": "Bearer $resolvedToken",
      };

      // ignore: avoid_print
      print("🧾 DELETE ${_u(endpoint)} HEADERS: $headers");

      var resp = await http.delete(_u(endpoint), headers: headers);

      // ignore: avoid_print
      print("🗑️ DELETE STATUS: ${resp.statusCode}");
      // ignore: avoid_print
      print("📩 DELETE RESPONSE BODY: ${resp.body}");

      var decoded = _decode(resp);

      if (_tokenMissing401(resp, decoded) && resolvedToken?.isNotEmpty == true) {
        final fbUri = _uWithQuery(endpoint, {'token': resolvedToken!});
        headers = {
          "Accept": "application/json",
          "Content-Type": "application/json",
        };

        // ignore: avoid_print
        print("🧾 DELETE (fallback) $fbUri HEADERS: $headers");

        resp = await http.delete(fbUri, headers: headers);

        // ignore: avoid_print
        print("🗑️ DELETE (fallback) STATUS: ${resp.statusCode}");
        // ignore: avoid_print
        print("📩 DELETE (fallback) BODY: ${resp.body}");

        decoded = _decode(resp);
      }

      return _handleResponse(resp, decoded);
    } catch (e) {
      return _errorResponse("DELETE Error: ${e.toString()}", 500);
    }
  }

  // ---------- Multipart POST (list field) ----------
  static Future<Map<String, dynamic>> postMultipart({
    required String endpoint,
    required List<File> files,
    required String fileField,
    Map<String, String>? fields,
    String? token,
  }) async {
    try {
      final resolvedToken = await _autoToken(token);

      Future<Map<String, dynamic>> _send(Uri uri,
          {bool includeAuth = true, bool includeTokenField = false}) async {
        final req = http.MultipartRequest('POST', uri);
        req.headers['Accept'] = 'application/json';
        if (includeAuth && resolvedToken?.isNotEmpty == true) {
          req.headers['Authorization'] = 'Bearer $resolvedToken';
        }
        if (fields != null) req.fields.addAll(fields!);
        if (includeTokenField && resolvedToken?.isNotEmpty == true) {
          req.fields['token'] = resolvedToken!;
        }
        for (final f in files) {
          final mime = lookupMimeType(f.path);
          final mt = mime != null ? MediaType.parse(mime) : MediaType('image', 'jpeg');
          req.files.add(await http.MultipartFile.fromPath(
              fileField, f.path, contentType: mt, filename: basename(f.path)));
        }

        // ignore: avoid_print
        print("🧾 MULTIPART POST $uri HEADERS: ${req.headers}");

        final streamed = await req.send();
        final resp = await http.Response.fromStream(streamed);

        // ignore: avoid_print
        print("📦 Multipart STATUS: ${resp.statusCode}");
        // ignore: avoid_print
        print("📩 Multipart RESPONSE BODY: ${resp.body}");

        final decoded = _decode(resp);
        return _handleResponse(resp, decoded);
      }

      var first =
      await _send(_u(endpoint), includeAuth: true, includeTokenField: false);

      if (first['code'] == 401 &&
          (first['message']?.toString().contains('Token not provided') ?? false) &&
          resolvedToken?.isNotEmpty == true) {
        first = await _send(
          _uWithQuery(endpoint, {'token': resolvedToken!}),
          includeAuth: false,
          includeTokenField: true,
        );
      }

      return first;
    } catch (e) {
      // ignore: avoid_print
      print("❌ Multipart Upload Error: $e");
      return _errorResponse("Upload failed: ${e.toString()}", 500);
    }
  }

  // ---------- Multipart PUT (list field) ----------
  static Future<Map<String, dynamic>> putMultipart({
    required String endpoint,
    required List<File> files,
    required String fileField,
    Map<String, String>? fields,
    String? token,
  }) async {
    try {
      final resolvedToken = await _autoToken(token);

      Future<Map<String, dynamic>> _send(Uri uri,
          {bool includeAuth = true, bool includeTokenField = false}) async {
        final req = http.MultipartRequest('PUT', uri);
        req.headers['Accept'] = 'application/json';
        if (includeAuth && resolvedToken?.isNotEmpty == true) {
          req.headers['Authorization'] = 'Bearer $resolvedToken';
        }
        if (fields != null) req.fields.addAll(fields!);
        if (includeTokenField && resolvedToken?.isNotEmpty == true) {
          req.fields['token'] = resolvedToken!;
        }
        for (final f in files) {
          final mime = lookupMimeType(f.path);
          final mt = mime != null ? MediaType.parse(mime) : MediaType('image', 'jpeg');
          req.files.add(await http.MultipartFile.fromPath(
              fileField, f.path, contentType: mt, filename: basename(f.path)));
        }

        // ignore: avoid_print
        print("🧾 MULTIPART PUT $uri HEADERS: ${req.headers}");

        final streamed = await req.send();
        final resp = await http.Response.fromStream(streamed);

        // ignore: avoid_print
        print("📦 PUT Multipart STATUS: ${resp.statusCode}");
        // ignore: avoid_print
        print("📩 PUT Multipart RESPONSE BODY: ${resp.body}");

        final decoded = _decode(resp);
        return _handleResponse(resp, decoded);
      }

      var first =
      await _send(_u(endpoint), includeAuth: true, includeTokenField: false);

      if (first['code'] == 401 &&
          (first['message']?.toString().contains('Token not provided') ?? false) &&
          resolvedToken?.isNotEmpty == true) {
        first = await _send(
          _uWithQuery(endpoint, {'token': resolvedToken!}),
          includeAuth: false,
          includeTokenField: true,
        );
      }

      return first;
    } catch (e) {
      // ignore: avoid_print
      print("❌ PUT Multipart Upload Error: $e");
      return _errorResponse("Upload failed: ${e.toString()}", 500);
    }
  }

  // ---------- Multipart POST (indexed fields) ----------
  static Future<Map<String, dynamic>> postMultipartIndexed({
    required String endpoint,
    required Map<String, File> filesByField, // e.g. {'photos[0]': file0}
    Map<String, String>? fields,
    String? token,
  }) async {
    try {
      final resolvedToken = await _autoToken(token);
      final uri = Uri.parse('$baseUrl/$endpoint');
      final request = http.MultipartRequest('POST', uri);

      request.headers['Accept'] = 'application/json';
      if (resolvedToken != null && resolvedToken.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $resolvedToken';
      }

      if (fields != null) {
        request.fields.addAll(fields);
      }

      for (final entry in filesByField.entries) {
        request.files.add(
          await http.MultipartFile.fromPath(entry.key, entry.value.path),
        );
      }

      final streamed = await request.send();
      final body = await streamed.stream.bytesToString();
      final status = streamed.statusCode;

      // ignore: avoid_print
      print("📦 Multipart Indexed STATUS: $status");
      // ignore: avoid_print
      print("📩 Multipart Indexed BODY: $body");

      if (status >= 200 && status < 300) {
        return jsonDecode(body) as Map<String, dynamic>;
      } else {
        try {
          final json = jsonDecode(body);
          return json is Map<String, dynamic>
              ? json
              : {'success': false, 'message': 'HTTP $status'};
        } catch (_) {
          return {'success': false, 'message': 'HTTP $status'};
        }
      }
    } catch (e) {
      return _errorResponse("Multipart indexed upload error: $e", 500);
    }
  }

  // ---------- PUT JSON (simple helper) ----------
  static Future<Map<String, dynamic>> putJson(
      String endpoint,
      dynamic body, {
        String? token,
      }) async {
    final uri = Uri.parse('$baseUrl/$endpoint');
    final resolvedToken = await _autoToken(token);
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (resolvedToken != null && resolvedToken.isNotEmpty)
        'Authorization': 'Bearer $resolvedToken',
    };

    final res = await http.put(uri, headers: headers, body: jsonEncode(body));

    if (res.body.isEmpty) return {};
    try {
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      return {'raw': res.body, 'status': res.statusCode};
    }
  }
}
