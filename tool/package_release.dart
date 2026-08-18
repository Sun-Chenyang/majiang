// 发布打包：构建 release APK 并把产物按版本号重命名归档到 build/release/。
//
// 用法：dart run tool/package_release.dart
// 产物：build/release/kawuxing-<version>-<abi>-release.apk
//       （如 kawuxing-1.2.1-arm64-v8a-release.apk）
//
// 说明：gradle 侧已通过 build.gradle.kts 的 outputs.all 重命名
// （build/app/outputs/apk/release/ 下即带版本号），但 Flutter 工具
// 复制到 flutter-apk/ 时使用固定的默认名——本脚本做最后一层归档。
// ignore_for_file: avoid_print
import 'dart:io';

void main(List<String> args) async {
  // 1. 从 pubspec.yaml 读版本号（去掉 build number）
  final pubspec = File('pubspec.yaml');
  if (!pubspec.existsSync()) {
    stderr.writeln('未找到 pubspec.yaml（请在仓库根目录运行）');
    exit(1);
  }
  final m = RegExp(r'^version:\s*(\S+)', multiLine: true)
      .firstMatch(pubspec.readAsStringSync());
  if (m == null) {
    stderr.writeln('pubspec.yaml 未解析到 version 字段');
    exit(1);
  }
  final version = m.group(1)!.split('+').first;
  print('打包版本：$version\n');

  // 2. 构建（签名读取 android/key.properties，缺失回退 debug 签名）
  final build = await Process.run(
    'flutter',
    ['build', 'apk', '--release', '--split-per-abi'],
    runInShell: true,
  );
  stdout.write(build.stdout);
  stderr.write(build.stderr);
  if (build.exitCode != 0) {
    stderr.writeln('构建失败（exit ${build.exitCode}）');
    exit(build.exitCode);
  }

  // 3. 归档重命名
  final srcDir = Directory('build/app/outputs/flutter-apk');
  final dstDir = Directory('build/release')..createSync(recursive: true);
  var count = 0;
  for (final f in srcDir.listSync()) {
    final name = f.uri.pathSegments.last;
    if (!name.endsWith('-release.apk') || f is! File) continue;
    final abi = name.replaceFirst('app-', '').replaceFirst('-release.apk', '');
    final dst = File('${dstDir.path}/kawuxing-$version-$abi-release.apk');
    f.copySync(dst.path);
    final kb = (dst.lengthSync() / 1024 / 1024).toStringAsFixed(1);
    print('→ ${dst.path}  (${kb}MB)');
    count++;
  }
  print('\n完成：$count 个产物已归档到 build/release/');
}
