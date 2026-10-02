import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:file_picker/src/platform/file_picker_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:senalgo/ui/services/algo_file_service.dart';

class _Picker extends FilePickerPlatform {
  FilePickerResult? selected;
  String? savedPath;
  Uint8List? savedBytes;
  String? savedName;
  bool requestedBytes = false;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle, String? initialDirectory,
    FileType type = FileType.any, List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading, int compressionQuality = 0,
    bool allowMultiple = false, bool withData = false, bool withReadStream = false,
    bool lockParentWindow = false, bool readSequential = false,
    bool cancelUploadOnWindowBlur = true,
  }) async {
    requestedBytes = withData;
    return selected;
  }

  @override
  Future<String?> saveFile({
    String? dialogTitle, String? fileName, String? initialDirectory,
    FileType type = FileType.any, List<String>? allowedExtensions,
    Uint8List? bytes, bool lockParentWindow = false,
  }) async {
    savedBytes = bytes;
    savedName = fileName;
    return savedPath;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FilePickerPlatform original;
  late _Picker picker;

  setUp(() {
    original = FilePickerPlatform.instance;
    picker = _Picker();
    FilePickerPlatform.instance = picker;
  });
  tearDown(() => FilePickerPlatform.instance = original);

  test('importe un programme accentué sans chemin disque', () async {
    const source = 'ALGORITHME Été\nDEBUT\n  ecrire("réussi")\nFIN';
    final bytes = Uint8List.fromList(utf8.encode(source));
    picker.selected = FilePickerResult([PlatformFile(name: 'été.algo', size: bytes.length, bytes: bytes)]);
    expect(await AlgoFileService.pickAndRead(), source);
    expect(picker.requestedBytes, isTrue);
  });

  test('une sélection annulée ne charge rien', () async {
    expect(await AlgoFileService.pickAndRead(), isNull);
  });

  test('exporte le contenu UTF-8 avec le nom du programme', () async {
    const source = 'ALGORITHME Été\nDEBUT\nFIN';
    picker.savedPath = '/tmp/été.algo';
    expect(await AlgoFileService.pickAndWrite(source), isTrue);
    expect(picker.savedName, 'Été.algo');
    expect(utf8.decode(picker.savedBytes!), source);
  });

  test('une sauvegarde annulée sur ordinateur reste annulée', () async {
    expect(await AlgoFileService.pickAndWrite('DEBUT\nFIN'), isFalse);
  });
}
