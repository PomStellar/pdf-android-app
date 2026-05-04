import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

void main() {
  runApp(const BakPdfApp());
}

class BakPdfApp extends StatelessWidget {
  const BakPdfApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BAK PDF',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const BakPdfPage(),
    );
  }
}

class Bak {
  Bak({
    required this.id,
    required this.name,
    required this.images,
  });

  final String id;
  String name;
  final List<File> images;
}

class BakPdfPage extends StatefulWidget {
  const BakPdfPage({super.key});

  @override
  State<BakPdfPage> createState() => _BakPdfPageState();
}

class _BakPdfPageState extends State<BakPdfPage> {
  final List<Bak> _baks = <Bak>[];
  final List<File> _generatedFiles = <File>[];
  bool _isProcessing = false;

  void _addBak() {
    setState(() {
      final nextNumber = _baks.length + 1;
      _baks.add(
        Bak(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          name: 'BAK $nextNumber',
          images: <File>[],
        ),
      );
    });
  }

  void _deleteBak(Bak bak) {
    setState(() {
      _baks.removeWhere((item) => item.id == bak.id);
    });
  }

  Future<void> _pickImages(Bak bak) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.image,
    );

    if (result == null) {
      return;
    }

    final selectedImages = result.paths
        .whereType<String>()
        .map(File.new)
        .where((file) => file.existsSync())
        .toList();

    if (selectedImages.isEmpty) {
      return;
    }

    setState(() {
      bak.images.addAll(selectedImages);
    });
  }

  void _removeImage(Bak bak, File image) {
    setState(() {
      bak.images.remove(image);
    });
  }

  Future<void> _processAll() async {
    if (_isProcessing) {
      return;
    }

    setState(() {
      _isProcessing = true;
      _generatedFiles.clear();
    });

    try {
      final outputDirectory = await _ensureOutputDirectory();
      final generatedFiles = <File>[];

      for (final bak in _baks) {
        if (bak.images.isEmpty) {
          continue;
        }

        final pdfFile = await _createPdfForBak(bak, outputDirectory);
        generatedFiles.add(pdfFile);
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _generatedFiles.addAll(generatedFiles);
      });

      final message = generatedFiles.isEmpty
          ? 'Tidak ada BAK dengan gambar untuk diproses.'
          : '${generatedFiles.length} PDF berhasil dibuat.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal membuat PDF: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<Directory> _ensureOutputDirectory() async {
    final documentsDirectory = Directory('/storage/emulated/0/Documents');

    if (Platform.isAndroid) {
      await _ensureAndroidStoragePermission();
      final outputDirectory = Directory('${documentsDirectory.path}/BAK_PDF');
      if (!await outputDirectory.exists()) {
        await outputDirectory.create(recursive: true);
      }
      return outputDirectory;
    }

    final fallbackDocumentsDirectory = await getApplicationDocumentsDirectory();
    final outputDirectory = Directory('${fallbackDocumentsDirectory.path}/BAK_PDF');
    if (!await outputDirectory.exists()) {
      await outputDirectory.create(recursive: true);
    }
    return outputDirectory;
  }

  Future<void> _ensureAndroidStoragePermission() async {
    final storageStatus = await Permission.storage.request();
    if (storageStatus.isGranted) {
      return;
    }

    final manageStatus = await Permission.manageExternalStorage.request();
    if (!manageStatus.isGranted) {
      throw const FileSystemException(
        'Izin penyimpanan diperlukan untuk menyimpan PDF ke Documents/BAK_PDF.',
      );
    }
  }

  Future<File> _createPdfForBak(Bak bak, Directory outputDirectory) async {
    final document = pw.Document();

    for (final imageFile in bak.images) {
      final imageBytes = await imageFile.readAsBytes();
      final decodedImage = await _decodeImage(imageBytes);
      final imageWidth = decodedImage.width.toDouble();
      final imageHeight = decodedImage.height.toDouble();
      decodedImage.dispose();

      final image = pw.MemoryImage(imageBytes);

      document.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(imageWidth, imageHeight),
          margin: pw.EdgeInsets.zero,
          build: (context) {
            return pw.Image(
              image,
              width: imageWidth,
              height: imageHeight,
            );
          },
        ),
      );
    }

    final sanitizedName = _sanitizeFileName(bak.name);
    final file = File('${outputDirectory.path}/$sanitizedName.pdf');
    await file.writeAsBytes(await document.save());
    return file;
  }

  Future<ui.Image> _decodeImage(Uint8List imageBytes) {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromList(imageBytes, completer.complete);
    return completer.future;
  }

  String _sanitizeFileName(String name) {
    final trimmedName = name.trim();
    final safeName = trimmedName.isEmpty ? 'BAK' : trimmedName;
    return safeName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
  }

  Future<void> _shareFile(File file) async {
    await Share.shareXFiles(<XFile>[XFile(file.path)]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('BAK PDF')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _addBak,
                  icon: const Icon(Icons.add),
                  label: const Text('Tambah BAK'),
                ),
              ),
            ),
            Expanded(
              child: _baks.isEmpty
                  ? const Center(child: Text('Belum ada BAK.'))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: _baks.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) => _BakItem(
                        key: ValueKey(_baks[index].id),
                        bak: _baks[index],
                        onNameChanged: (value) {
                          setState(() {
                            _baks[index].name = value;
                          });
                        },
                        onAddImages: () => _pickImages(_baks[index]),
                        onDelete: () => _deleteBak(_baks[index]),
                        onRemoveImage: (image) => _removeImage(_baks[index], image),
                      ),
                    ),
            ),
            _BottomSection(
              isProcessing: _isProcessing,
              generatedFiles: _generatedFiles,
              onProcessAll: _processAll,
              onShare: _shareFile,
            ),
          ],
        ),
      ),
    );
  }
}

class _BakItem extends StatelessWidget {
  const _BakItem({
    super.key,
    required this.bak,
    required this.onNameChanged,
    required this.onAddImages,
    required this.onDelete,
    required this.onRemoveImage,
  });

  final Bak bak;
  final ValueChanged<String> onNameChanged;
  final VoidCallback onAddImages;
  final VoidCallback onDelete;
  final ValueChanged<File> onRemoveImage;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              initialValue: bak.name,
              decoration: const InputDecoration(
                labelText: 'Nama BAK',
                border: OutlineInputBorder(),
              ),
              onChanged: onNameChanged,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: onAddImages,
                  icon: const Icon(Icons.image),
                  label: const Text('Tambah Gambar'),
                ),
                OutlinedButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Hapus BAK'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('${bak.images.length} gambar'),
            const SizedBox(height: 8),
            if (bak.images.isEmpty)
              const Text('Belum ada gambar.')
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemCount: bak.images.length,
                itemBuilder: (context, index) {
                  final image = bak.images[index];
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          image,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) {
                            return const ColoredBox(
                              color: Colors.black12,
                              child: Icon(Icons.broken_image_outlined),
                            );
                          },
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: IconButton.filledTonal(
                          onPressed: () => onRemoveImage(image),
                          icon: const Icon(Icons.close),
                          tooltip: 'Hapus gambar',
                        ),
                      ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _BottomSection extends StatelessWidget {
  const _BottomSection({
    required this.isProcessing,
    required this.generatedFiles,
    required this.onProcessAll,
    required this.onShare,
  });

  final bool isProcessing;
  final List<File> generatedFiles;
  final VoidCallback onProcessAll;
  final ValueChanged<File> onShare;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: isProcessing ? null : onProcessAll,
                icon: isProcessing
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.picture_as_pdf),
                label: const Text('Proses Semua'),
              ),
            ),
            if (generatedFiles.isNotEmpty) ...[
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 160),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: generatedFiles.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final file = generatedFiles[index];
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.picture_as_pdf_outlined),
                      title: Text(
                        file.path.split(Platform.pathSeparator).last,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: IconButton(
                        onPressed: () => onShare(file),
                        icon: const Icon(Icons.share),
                        tooltip: 'Bagikan PDF',
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
