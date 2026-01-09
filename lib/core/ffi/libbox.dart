import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

// 定义 C 函数签名
// 根据 Sing-box libbox 的导出函数 (参考: generic c-shared build)
// 注意：具体的函数签名取决于如何编译 libbox。这里假设了一套标准接口。

/*
  // golang main.go export:
  //export start
  func start(configC *C.char) *C.char { ... }

  //export stop
  func stop() { ... }
*/

typedef StartFunc = Pointer<Utf8> Function(
    Pointer<Utf8> configContent, Int32 tunFd);
typedef Start = Pointer<Utf8> Function(Pointer<Utf8> configContent, int tunFd);

typedef StopFunc = Void Function();
typedef Stop = void Function();

class LibBox {
  static DynamicLibrary? _lib;

  static void ensureInitialized() {
    if (_lib != null) return;

    try {
      if (Platform.isAndroid) {
        _lib = DynamicLibrary.open('libbox.so');
      } else if (Platform.isIOS) {
        _lib = DynamicLibrary.process();
      }
    } catch (e) {
      print("Failed to load libbox: $e");
    }
  }

  static String? start(String configContent, int tunFd) {
    ensureInitialized();
    if (_lib == null) return "Library not loaded";

    try {
      final startFunc = _lib!.lookupFunction<StartFunc, Start>('start');

      final configC = configContent.toNativeUtf8();
      // 在非 Android 平台，tunFd 传入 -1
      final resultC = startFunc(configC, tunFd);

      String? error;
      if (resultC != nullptr) {
        error = resultC.toDartString();
      }

      malloc.free(configC);
      return error;
    } catch (e) {
      return "FFI Error: $e";
    }
  }

  static void stop() {
    ensureInitialized();
    if (_lib == null) return;

    try {
      final stopFunc = _lib!.lookupFunction<StopFunc, Stop>('stop');
      stopFunc();
    } catch (e) {
      print("FFI Stop Error: $e");
    }
  }
}
