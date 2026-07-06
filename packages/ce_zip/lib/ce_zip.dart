/// ZIP container em Dart puro para os DOCX do editor
/// (roteiro_editor_profissional, Fase 1.1).
library;

export 'src/codecs/zlib/deflate.dart' show Deflate, DeflateLevel;
export 'src/codecs/zlib/inflate.dart' show Inflate;
export 'src/util/crc32.dart' show getCrc32;
export 'src/zip_archive.dart' show ZipArchive, ZipEntry;
