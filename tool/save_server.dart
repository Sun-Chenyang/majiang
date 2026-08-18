// 临时图片接收服务：POST /save?name=x.png 将请求体写入
// build/icon_preview/x.png（图标预览评审用，评审后删除）。
library;

import 'dart:io';

Future<void> main() async {
  final dir = Directory('build/icon_preview');
  await dir.create(recursive: true);
  final server = await HttpServer.bind('127.0.0.1', 8477);
  // ignore: avoid_print
  print('save server on http://127.0.0.1:8477 -> ${dir.absolute.path}');
  await for (final req in server) {
    final origin = req.headers.value('Origin') ?? '*';
    req.response.headers.set('Access-Control-Allow-Origin', origin);
    req.response.headers.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
    req.response.headers.set('Access-Control-Allow-Headers', 'Content-Type');
    if (req.method == 'OPTIONS') {
      req.response.statusCode = 204;
      await req.response.close();
      continue;
    }
    if (req.method == 'POST' && req.uri.queryParameters.containsKey('name')) {
      final name = req.uri.queryParameters['name']!.replaceAll(RegExp(r'[^\w.\-]'), '');
      final bytes = await req.fold<BytesBuilder>(
          BytesBuilder(), (b, chunk) => b..add(chunk));
      final f = File('build/icon_preview/$name');
      await f.writeAsBytes(bytes.takeBytes());
      // ignore: avoid_print
      print('saved ${f.path} (${f.lengthSync()} bytes)');
      req.response.statusCode = 200;
      await req.response.close();
      continue;
    }
    req.response.statusCode = 404;
    await req.response.close();
  }
}
