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

typedef StartFunc = Pointer<Utf8> Function(Pointer<Utf8> configContent);
typedef Start = Pointer<Utf8> Function(Pointer<Utf8> configContent);

typedef StopFunc = Void Function();
typedef Stop = void Function();

class LibBox {
  static DynamicLibrary? _lib;

  static void ensureInitialized() {
    if (_lib != null) return;

    if (Platform.isAndroid) {
      _lib = DynamicLibrary.open('libbox.so');
    } else if (Platform.isIOS) {
      _lib = DynamicLibrary.process(); // iOS usually links statically or framework
    } else if (Platform.isWindows) {
       // Windows FFI is possible but we use EXE for now
       // _lib = DynamicLibrary.open('libbox.dll'); 
    }
  }

  static String? start(String configContent) {
    ensureInitialized();
    if (_lib == null) return "Library not loaded";

    try {
      final startFunc = _lib!.lookupFunction<StartFunc, Start>('start');
      
      final configC = configContent.toNativeUtf8();
      final resultC = startFunc(configC);
      
      String? error;
      if (resultC != nullptr) {
        error = resultC.toDartString();
        // Go 侧分配的字符串通常不需要我们在 Dart 侧释放，或者 Go 侧应该提供 free 函数
        // 这里假设返回的是 null 表示成功，非 null 表示错误信息
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
