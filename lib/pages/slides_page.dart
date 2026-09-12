import 'package:flutter/material.dart';
import '../widgets/custom_gradient_app_bar.dart';
import 'package:jimpitan/utils/api_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:async';
import 'package:jimpitan/utils/app_theme.dart';
import 'package:jimpitan/widgets/app_modal_dialog.dart';
import 'package:image_picker/image_picker.dart';
import 'package:jimpitan/utils/image_compressor.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'dart:convert';
import 'package:jimpitan/utils/custom_toast.dart';

class SlidesPage extends StatefulWidget {
  final Map<String, bool> permissions;
  final String villageId;
  const SlidesPage({
    super.key,
    required this.permissions,
    required this.villageId,
  });

  @override
  State<SlidesPage> createState() => _SlidesPageState();
}

class _SlidesPageState extends State<SlidesPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _subtitleController = TextEditingController();
  final _valueController = TextEditingController();
  final _statusController = TextEditingController();
  String _slideType = 'INFO';
  String? _imageBase64;
  String _textColor = '#FFFFFF';

  bool get _canCreate => widget.permissions['create'] ?? false;
  bool get _canEdit => widget.permissions['edit'] ?? false;
  bool get _canDelete => widget.permissions['delete'] ?? false;

  Future<List<dynamic>>? _slidesFuture;
  StreamSubscription? _fcmSubscription;

  @override
  void initState() {
    super.initState();
    _loadData();
    _setupFCM();
  }

  void _loadData() {
    setState(() {
      _slidesFuture = ApiService.getSlides(widget.villageId).then((slides) async {
        await _ensureDefaultBillSlide(slides);
        return slides;
      });
    });
  }

  Future<void> _ensureDefaultBillSlide(List<dynamic> slides) async {
    final String docId = '${widget.villageId}_bill';
    final hasBillSlide = slides.any((s) => s['type'] == 'BILL' || s['id'] == docId);

    if (!hasBillSlide) {
      await ApiService.createSlide({
        'id': docId,
        'title': 'Total Tagihan',
        'subtitle': 'Informasi Tagihan Anda',
        'type': 'BILL',
        'value': '',
        'status': 'Belum Lunas',
        'textColor': '#FFFFFF',
        'villageId': widget.villageId,
      });
      if (mounted) {
        setState(() {
          _slidesFuture = ApiService.getSlides(widget.villageId);
        });
      }
    }
  }

  void _setupFCM() {
    _fcmSubscription = FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.data['action'] == 'REFRESH_SLIDES' || message.data['action'] == 'REFRESH_ALL') {
        _loadData();
      }
    });
  }

  @override
  void dispose() {
    _fcmSubscription?.cancel();
    _titleController.dispose();
    _subtitleController.dispose();
    _valueController.dispose();
    _statusController.dispose();
    super.dispose();
  }

  void _showSlideForm([Map<String, dynamic>? doc]) {
    if (doc != null) {
      final data = doc;
      _titleController.text = data['title'] ?? '';
      _subtitleController.text = data['subtitle'] ?? '';
      _slideType = data['type'] ?? 'INFO';
      _valueController.text = data['value'] ?? '';
      _statusController.text = data['status'] ?? '';
      _imageBase64 = data['imageBase64'];
      _textColor = data['textColor'] ?? '#FFFFFF';
    } else {
      _titleController.clear();
      _subtitleController.clear();
      _slideType = 'INFO';
      _valueController.clear();
      _statusController.clear();
      _imageBase64 = null;
      _textColor = '#FFFFFF';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return ValueListenableBuilder<Color>(
              valueListenable: AppTheme.primaryColorNotifier,
              builder: (context, themeColor, child) {
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom,
                  ),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                          decoration: BoxDecoration(
                            color: themeColor,
                            borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.slideshow, color: Colors.white, size: 24),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  doc == null ? 'Tambah Slide Baru' : 'Edit Slide',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ),
                              IconButton(
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(Icons.close, color: Colors.white),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              )
                            ],
                          ),
                        ),
                        Flexible(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(24),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _titleController,
                                    decoration: const InputDecoration(labelText: 'Judul'),
                                    validator: (val) => val == null || val.isEmpty ? 'Wajib diisi' : null,
                                  ),
                                  const SizedBox(height: 16),
                                  InputDecorator(
                                    decoration: const InputDecoration(labelText: 'Tipe Slide'),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: _slideType,
                                        isDense: true,
                                        items: const [
                                          DropdownMenuItem(value: 'INFO', child: Text('Informasi Umum')),
                                          DropdownMenuItem(value: 'BILL', child: Text('Tagihan Warga (Otomatis)')),
                                        ],
                                        onChanged: (doc != null && doc['id'] == '${widget.villageId}_bill') 
                                            ? null 
                                            : (val) {
                                                setModalState(() {
                                                  _slideType = val ?? 'INFO';
                                                });
                                              },
                                      ),
                                    ),
                                  ),
                                  if (_slideType == 'BILL') ...[
                                    const SizedBox(height: 16),
                                    FutureBuilder<List<dynamic>>(
                                      future: ApiService.getTariffs(widget.villageId),
                                      builder: (context, snapshot) {
                                        if (!snapshot.hasData) return const CircularProgressIndicator();
                                        final tariffs = snapshot.data!.where((t) => t['isActive'] == true).toList();
                                        return InputDecorator(
                                          decoration: const InputDecoration(labelText: 'Pilih Jenis Iuran (Opsional)'),
                                          child: DropdownButtonHideUnderline(
                                            child: DropdownButton<String>(
                                              value: _valueController.text.isEmpty ? null : (tariffs.any((t) => t['id'].toString() == _valueController.text) ? _valueController.text : null),
                                              isDense: true,
                                              items: [
                                                const DropdownMenuItem(value: null, child: Text('Semua Iuran')),
                                                ...tariffs.map((t) => DropdownMenuItem(value: t['id'].toString(), child: Text(t['name'].toString()))),
                                              ],
                                              onChanged: (doc != null && doc['id'] == '${widget.villageId}_bill')
                                                  ? null
                                                  : (val) {
                                                      setModalState(() {
                                                        _valueController.text = val ?? '';
                                                        _statusController.text = 'Belum Lunas';
                                                      });
                                                    },
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _subtitleController,
                                    decoration: const InputDecoration(labelText: 'Subjudul / Deskripsi'),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Gambar Slide (Opsional)',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                    const SizedBox(height: 8),
                                    GestureDetector(
                                      onTap: () async {
                                        final picker = ImagePicker();
                                        final pickedFile = await picker.pickImage(
                                          source: ImageSource.gallery,
                                          maxWidth: 800,
                                          maxHeight: 800,
                                        );

                                        if (pickedFile != null) {
                                          EasyLoading.show(status: 'Memproses gambar...');
                                          await Future.delayed(const Duration(milliseconds: 50));
                                          try {
                                            final bytes = await pickedFile.readAsBytes();
                                            final base64String = await ImageCompressor.compressImage(bytes, width: 400, quality: 50);
                                            
                                            if (base64String != null) {
                                              setModalState(() {
                                                _imageBase64 = base64String;
                                              });
                                            }
                                          } catch (e) {
                                            debugPrint('Error reading image: $e');
                                            if (!context.mounted) return;
                                            CustomToast.show(context, 'Gagal memproses gambar', isError: true);
                                          } finally {
                                            EasyLoading.dismiss();
                                          }
                                        }
                                      },
                                      child: Container(
                                        height: 150,
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: Colors.grey.shade300),
                                        ),
                                        child: _imageBase64 != null && _imageBase64!.isNotEmpty
                                            ? ClipRRect(
                                                borderRadius: BorderRadius.circular(12),
                                                child: Image.memory(
                                                  base64Decode(_imageBase64!),
                                                  fit: BoxFit.cover,
                                                  width: double.infinity,
                                                ),
                                              )
                                            : const Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(Icons.add_photo_alternate, size: 40, color: Colors.grey),
                                                  SizedBox(height: 8),
                                                  Text('Ketuk untuk upload gambar', style: TextStyle(color: Colors.grey)),
                                                ],
                                              ),
                                      ),
                                    ),
                                    if (_imageBase64 != null)
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: TextButton(
                                          onPressed: () {
                                            setModalState(() {
                                              _imageBase64 = null;
                                            });
                                          },
                                          child: const Text('Hapus Gambar', style: TextStyle(color: Colors.red)),
                                        ),
                                      ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Warna Teks',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 12,
                                    children: [
                                      '#FFFFFF', // White
                                      '#000000', // Black
                                      '#EF4444', // Red
                                      '#3B82F6', // Blue
                                      '#10B981', // Green
                                      '#F59E0B', // Yellow
                                    ].map((colorHex) {
                                      bool isSelected = _textColor == colorHex;
                                      return GestureDetector(
                                        onTap: () => setModalState(() => _textColor = colorHex),
                                        child: Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color: Color(int.parse(colorHex.replaceFirst('#', '0xFF'))),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: isSelected ? themeColor : Colors.grey.shade300,
                                              width: isSelected ? 3 : 1,
                                            ),
                                          ),
                                          child: isSelected
                                              ? Icon(
                                                  Icons.check,
                                                  size: 16,
                                                  color: colorHex == '#FFFFFF' ? Colors.black : Colors.white,
                                                )
                                              : null,
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                  const SizedBox(height: 24),
                                  Row(
                                    children: [

                                      Expanded(
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: themeColor,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(vertical: 16),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          ),
                                          onPressed: () async {
                                            if (_formKey.currentState!.validate()) {
                                              final data = {
                                                'title': _titleController.text,
                                                'subtitle': _subtitleController.text,
                                                'type': _slideType,
                                                'imageBase64': _imageBase64,
                                                'textColor': _textColor,
                                                'value': _slideType == 'BILL' ? _valueController.text : null,
                                                'status': _slideType == 'BILL' ? _statusController.text : null,
                                                'villageId': widget.villageId,
                                              };

                                              if (doc == null) {
                                                await ApiService.createSlide(data);
                                                _loadData();
                                                
                                                if (!context.mounted) return;
                                                CustomToast.show(context, 'Slide berhasil ditambahkan!');
                                                
                                                _titleController.clear();
                                                _subtitleController.clear();
                                                _valueController.clear();
                                                _statusController.clear();
                                                setModalState(() {
                                                  _imageBase64 = null;
                                                });
                                              } else {
                                                await ApiService.updateSlide(doc['id'], data);
                                                _loadData();
                                                if (!context.mounted) return;
                              if (mounted) CustomToast.show(context, 'Data berhasil disimpan');
                                                Navigator.pop(context);
                                              }
                                            }
                                          },
                                          child: Text(
                                            doc == null ? 'Simpan & Tambah Lagi' : 'Perbarui',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 24),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          }
        );
      },
    );
  }

  void _deleteSlide(String docId) {
    showDialog(
      context: context,
      builder: (context) => AppModalDialog(
        title: 'Hapus Slide',
        headerIcon: Icons.delete,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Yakin ingin menghapus slide ini?'),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Batal'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    onPressed: () async {
                      await ApiService.deleteSlide(docId);
                      _loadData();
                      if (!context.mounted) return;
        if (mounted) CustomToast.show(context, 'Data berhasil dihapus');
                      Navigator.pop(context);
                    },
                    child: const Text('Hapus', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Color>(
      valueListenable: AppTheme.primaryColorNotifier,
      builder: (context, themeColor, child) {
        return Scaffold(
          appBar: CustomGradientAppBar(
            titleText: 'Manajemen Slideshow',
            actions: [
              if (_canCreate)
                IconButton(
                  icon: const Icon(Icons.add_circle, color: Colors.white, size: 28),
                  onPressed: () => _showSlideForm(),
                  tooltip: 'Tambah Slide',
                ),
            ],
          ),
          body: FutureBuilder<List<dynamic>>(
            future: _slidesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return const Center(child: Text('Terjadi kesalahan.'));
              }
              
              final allDocs = snapshot.data ?? [];
              final docs = allDocs.where((data) {
                final vid = data['villageId'];
                return vid == null || vid == '' || vid == widget.villageId;
              }).toList();
              
              if (docs.isNotEmpty) {
                final defaultBillId = '${widget.villageId}_bill';
                final defaultBillIndex = docs.indexWhere((s) => s['id'] == defaultBillId);
                if (defaultBillIndex > 0) {
                  final defaultBill = docs.removeAt(defaultBillIndex);
                  docs.insert(0, defaultBill);
                }
              }
              
              if (docs.isEmpty) {
                return const Center(child: Text('Belum ada slide.'));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index] as Map<String, dynamic>;
                  final isBill = data['type'] == 'BILL';
                  final imageBase64 = data['imageBase64'] as String?;

                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    color: Colors.white,
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: isBill
                          ? Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.receipt_long, color: Colors.red),
                            )
                          : (imageBase64 != null && imageBase64.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.memory(
                                    base64Decode(imageBase64),
                                    width: 50,
                                    height: 50,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(Icons.info_outline, color: themeColor),
                                )),
                      title: Text(
                        data['title'] ?? 'Tanpa Judul',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${data['type'] ?? 'INFO'} | ${data['subtitle'] ?? ''}'),
                          const SizedBox(height: 4),
                          Text(
                            'Kode Desa: ${data['villageId'] == null || data['villageId'].toString().isEmpty ? "Global (Semua Desa)" : data['villageId']}',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isBill)
                            Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Sistem',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          if (_canEdit)
                            IconButton(
                              icon: Icon(Icons.edit, color: themeColor),
                              onPressed: () => _showSlideForm(data),
                            ),
                          if (_canDelete && data['id'] != '${widget.villageId}_bill')
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteSlide(data['id']),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        );
      }
    );
  }
}
