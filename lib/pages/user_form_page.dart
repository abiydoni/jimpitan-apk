import 'package:jimpitan/utils/app_theme.dart';
import 'package:jimpitan/utils/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'package:image_picker/image_picker.dart';
import 'package:jimpitan/utils/image_compressor.dart';
import 'package:intl/intl.dart';
import 'package:jimpitan/utils/custom_toast.dart';
import '../widgets/user_avatar.dart';

class UserFormPage extends StatefulWidget {
  final String?
  userId; // Jika null, berarti tambah baru manual. Jika ada, edit / setujui
  final Map<String, dynamic>? initialData;
  final String villageId;
  final List<String>? currentUserRoles;

  const UserFormPage({
    super.key,
    this.userId,
    this.initialData,
    required this.villageId,
    this.currentUserRoles,
  });

  @override
  State<UserFormPage> createState() => _UserFormPageState();
}

class _UserFormPageState extends State<UserFormPage> {
  final _formKey = GlobalKey<FormState>();

  final _noKKController = TextEditingController();
  final _alamatController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  List<Map<String, dynamic>> _familyMembers = [];
  final List<String> _deletedDocIds = [];
  List<String> _availableRoles = ['WARGA'];
  DateTime _effectiveDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _noKKController.text = widget.initialData!['noKK']?.toString() ?? '';
      _alamatController.text =
          widget.initialData!['address']?.toString() ?? widget.initialData!['alamat']?.toString() ?? '';
      _phoneController.text = widget.initialData!['phone']?.toString() ?? '';
      _emailController.text = widget.initialData!['email']?.toString() ?? '';

      if (widget.initialData!['createdAt'] != null) {
        final dynamic rawDate = widget.initialData!['createdAt'];
        if (rawDate is String) {
          _effectiveDate = DateTime.tryParse(rawDate)?.toLocal() ?? DateTime.now();
        } else if (rawDate is int) {
          _effectiveDate = DateTime.fromMillisecondsSinceEpoch(rawDate);
        }
      }

      if (widget.initialData!['familyMembers'] != null) {
        _familyMembers = List<Map<String, dynamic>>.from(
          (widget.initialData!['familyMembers'] as List).map((x) => Map<String, dynamic>.from(x as Map)),
        );
        // Migrate legacy statusHidup & roles, and normalize keys
        for (var m in _familyMembers) {
          final existingName = (m['namaLengkap'] ?? m['name'] ?? '').toString();
          m['namaLengkap'] = existingName;
          m['name'] = existingName;
          m['_docId'] = (m['_docId'] ?? m['docId'] ?? m['uid'] ?? m['id'] ?? '').toString();
          m['docId'] = m['_docId'];
          m['statusPerkawinan'] = m['statusPerkawinan'] ?? 'Belum Kawin';
          if (m['statusHidup'] == 'Hidup') m['statusHidup'] = 'Aktif';
          if (m['statusHidup'] == null) m['statusHidup'] = 'Aktif';
          m['roles'] = _sanitizeRoles(m['roles']);
        }
      } else {
        // Migrasi data lama atau user baru dari PENDING
        final String mainDocId = (widget.userId ?? widget.initialData!['uid'] ?? widget.initialData!['docId'] ?? widget.initialData!['id'] ?? '').toString();
        final String mainName = (widget.initialData!['name'] ?? widget.initialData!['namaLengkap'] ?? '').toString();
        _familyMembers.add({
          '_docId': mainDocId.isNotEmpty ? mainDocId : null,
          'docId': mainDocId.isNotEmpty ? mainDocId : null,
          'nik': widget.initialData!['nik']?.toString() ?? '',
          'namaLengkap': mainName,
          'name': mainName,
          'statusHubungan': widget.initialData!['statusHubungan']?.toString() ?? 'Kepala Keluarga',
          'statusPerkawinan': widget.initialData!['statusPerkawinan']?.toString() ?? 'Belum Kawin',
          'jenisKelamin': widget.initialData!['jenisKelamin']?.toString() ?? 'Laki-laki',
          'tempatLahir': widget.initialData!['tempatLahir']?.toString() ?? '',
          'tanggalLahir': widget.initialData!['tanggalLahir']?.toString() ?? '',
          'agama': widget.initialData!['agama']?.toString() ?? 'Islam',
          'pekerjaan': widget.initialData!['pekerjaan']?.toString() ?? 'Belum/Tidak Bekerja',
          'statusHidup': widget.initialData!['statusHidup'] == 'Hidup' ? 'Aktif' : (widget.initialData!['statusHidup']?.toString() ?? 'Aktif'),
          'email': widget.initialData!['email']?.toString() ?? '',
          'foto': widget.initialData!['foto'] ?? widget.initialData!['photoUrl'] ?? '',
          'roles': _sanitizeRoles(widget.initialData!['roles']),
        });
      }
    } else {
      // Form kosong
      _familyMembers.add(_createEmptyMember());
    }
    _loadRoles();
  }

  List<String> _sanitizeRoles(dynamic rawRoles) {
    if (rawRoles == null) return ['WARGA'];
    if (rawRoles is List) {
      return rawRoles.map((r) {
        if (r is String) return r;
        if (r is Map && r['name'] != null) return r['name'].toString();
        return 'WARGA';
      }).toList();
    }
    return ['WARGA'];
  }

  Future<void> _loadRoles() async {
    try {
      final customRoles = await ApiService.getRoles(widget.villageId);
      if (customRoles.isNotEmpty) {
        setState(() {
          Set<String> allRoles = {'SUPER_ADMIN', 'ADMIN_DESA', 'WARGA'};
          allRoles.addAll(customRoles);
          _availableRoles = allRoles.toList();
        });
        return;
      }
      final village = await ApiService.getVillage(widget.villageId);
      if (village != null && village['config'] != null && village['config']['roles'] != null) {
        final rawRoles = village['config']['roles'];
        if (rawRoles is List) {
          setState(() {
            _availableRoles = List<String>.from(rawRoles);
            if (!_availableRoles.contains('WARGA')) {
              _availableRoles.add('WARGA');
            }
          });
        }
      }
    } catch (e) {
      // ignore
    }
  }

  String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString() + Random().nextInt(1000).toString();
  }

  Map<String, dynamic> _createEmptyMember() {
    return {
      'nik': '',
      'namaLengkap': '',
      'name': '',
      'statusHubungan': 'Anggota Keluarga',
      'statusPerkawinan': 'Belum Kawin',
      'jenisKelamin': 'Laki-laki',
      'tempatLahir': '',
      'tanggalLahir': '',
      'agama': 'Islam',
      'pekerjaan': 'Belum/Tidak Bekerja',
      'statusHidup': 'Aktif',
      'foto': '',
      'roles': ['WARGA'],
    };
  }

  void _addMember() {
    setState(() {
      _familyMembers.add(_createEmptyMember());
    });
  }

  void _removeMember(int index) {
    if (_familyMembers.length > 1) {
      setState(() {
        final removed = _familyMembers.removeAt(index);
        final docId = (removed['_docId'] ?? removed['docId'] ?? removed['uid'] ?? removed['id'] ?? '').toString();
        if (docId.isNotEmpty) {
          _deletedDocIds.add(docId);
        }
      });
    } else {
      CustomToast.show(context, 'Minimal harus ada 1 anggota keluarga');
    }
  }

  Future<void> _saveData() async {
    if (!_formKey.currentState!.validate()) return;

    // Validasi member
    bool isMembersValid = true;
    for (var member in _familyMembers) {
      final nik = (member['nik'] ?? '').toString().trim();
      final nama = (member['namaLengkap'] ?? member['name'] ?? '').toString().trim();
      if (nik.isEmpty || nama.isEmpty) {
        isMembersValid = false;
        break;
      }
    }

    if (!isMembersValid) {
      CustomToast.show(context, 'Harap lengkapi NIK dan Nama untuk setiap anggota keluarga');
      return;
    }
    EasyLoading.show(status: 'Menyimpan...');

    try {
      final String familyId = (widget.userId != null && widget.userId!.isNotEmpty)
          ? widget.userId!
          : (widget.initialData?['familyId']?.toString().isNotEmpty == true
              ? widget.initialData!['familyId'].toString()
              : _generateId());
      final String uniqueCode =
          widget.initialData?['uniqueCode']?.toString() ??
          (Random().nextInt(90000000) + 10000000).toString();
      final String villageId =
          widget.initialData?['villageId']?.toString() ?? widget.villageId;

      final mainEmail = _emailController.text.trim();
      final List<String> familyAllowedEmails = [];
      if (mainEmail.isNotEmpty) familyAllowedEmails.add(mainEmail);
      for (var member in _familyMembers) {
        final memberEmail = member['email']?.toString().trim() ?? '';
        if (memberEmail.isNotEmpty &&
            !familyAllowedEmails.contains(memberEmail)) {
          familyAllowedEmails.add(memberEmail);
        }
      }

      final List<Map<String, dynamic>> finalMembers = [];

      for (var member in _familyMembers) {
        String docId = (member['_docId'] ?? member['docId'] ?? member['uid'] ?? member['id'] ?? '').toString();

        if (docId.isEmpty) {
          docId = _generateId();
          member['_docId'] = docId;
          member['docId'] = docId;
        }

        final bool isMainUser =
            (docId == widget.userId) ||
            (member['statusHubungan'] == 'Kepala Keluarga');

        String finalEmail = member['email']?.toString().trim() ?? '';

        if (finalEmail.isEmpty && isMainUser && mainEmail.isNotEmpty) {
          finalEmail = mainEmail;
        }

        final String nameVal = (member['namaLengkap'] ?? member['name'] ?? '').toString().trim();

        final Map<String, dynamic> memberPayload = {
          'docId': docId,
          'uid': docId,
          // Data Individu
          'name': nameVal,
          'namaLengkap': nameVal,
          'nik': (member['nik'] ?? '').toString().trim(),
          'statusHubungan': member['statusHubungan'] ?? 'Anggota Keluarga',
          'statusPerkawinan': member['statusPerkawinan'] ?? 'Belum Kawin',
          'jenisKelamin': member['jenisKelamin'] ?? 'Laki-laki',
          'tempatLahir': member['tempatLahir'] ?? '',
          'tanggalLahir': member['tanggalLahir'] ?? '',
          'agama': member['agama'] ?? 'Islam',
          'pekerjaan': member['pekerjaan'] ?? 'Belum/Tidak Bekerja',
          'statusHidup': member['statusHidup'] ?? 'Aktif',
          'foto': member['foto'] ?? member['photoUrl'] ?? '',
          'email': finalEmail,
          'noKK': _noKKController.text.trim(),
          'alamat': _alamatController.text.trim(),
          'phone': _phoneController.text.trim(),
          'roles': member['roles'] ?? ['WARGA'],
          'createdAt': _effectiveDate.toIso8601String(),
        };
        finalMembers.add(memberPayload);
      }

      final Map<String, dynamic> payload = {
        'familyId': familyId,
        'uniqueCode': uniqueCode,
        'villageId': villageId,
        'noKK': _noKKController.text.trim(),
        'alamat': _alamatController.text.trim(),
        'phone': _phoneController.text.trim(),
        'familyMembers': finalMembers,
        'deletedDocIds': _deletedDocIds,
      };

      final success = await ApiService.saveUserFamily(payload);

      if (!success) {
        throw Exception('Gagal menyimpan data keluarga');
      }

      if (mounted) {
        Navigator.pop(context, true);
        CustomToast.show(context, 'Data berhasil disimpan!');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      EasyLoading.dismiss();
    }
  }

  InputDecoration _customInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: AppTheme.primaryColor),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
      ),
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isApproveMode =
        widget.initialData != null &&
        widget.initialData!['status'] == 'PENDING';

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text(
          isApproveMode
              ? 'Setujui Warga Baru'
              : (widget.userId != null ? 'Edit Data Warga' : 'Tambah Warga'),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Kartu Data Keluarga
                  Card(
                    elevation: 2,
                    shadowColor: Colors.black12,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.family_restroom,
                                color: AppTheme.primaryColor,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Informasi Keluarga',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 32),
                          TextFormField(
                            controller: _noKKController,
                            decoration: _customInputDecoration(
                              'Nomor Kartu Keluarga',
                              Icons.credit_card,
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _phoneController,
                            decoration: _customInputDecoration(
                              'Nomor HP / WhatsApp',
                              Icons.phone,
                            ),
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _alamatController,
                            decoration: _customInputDecoration(
                              'Alamat Lengkap (RT/RW)',
                              Icons.home,
                            ),
                            maxLines: 2,
                          ),
                          const SizedBox(height: 16),
                          InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _effectiveDate,
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                                builder: (context, child) {
                                  return Theme(
                                    data: Theme.of(context).copyWith(
                                      colorScheme: ColorScheme.light(
                                        primary: AppTheme.primaryColor,
                                      ),
                                    ),
                                    child: child!,
                                  );
                                },
                              );
                              if (picked != null) {
                                setState(() {
                                  _effectiveDate = picked;
                                });
                              }
                            },
                            child: InputDecorator(
                              decoration: _customInputDecoration(
                                'Tanggal Efektif KK (Registrasi)',
                                Icons.calendar_today,
                              ),
                              child: Text(
                                DateFormat('dd MMMM yyyy', 'id_ID').format(_effectiveDate),
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Daftar Anggota Keluarga
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Anggota Keluarga',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  ..._familyMembers.asMap().entries.map((entry) {
                    final index = entry.key;
                    final member = entry.value;
                    return _buildMemberCard(index, member);
                  }),

                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: _addMember,
                      icon: const Icon(Icons.person_add, size: 20),
                      label: const Text('Tambah Anggota Keluarga', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryColor,
                        side: BorderSide(color: AppTheme.primaryColor, width: 2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  // Role settings per member removed from here (moved to member card)
                  const SizedBox(height: 24),
                ],
              ),
            ),
            // Bottom Action Bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SafeArea(
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _saveData,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: const Text(
                      'Simpan Data Warga',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberCard(int index, Map<String, dynamic> member) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () async {
                          final picker = ImagePicker();
                          final XFile? image = await picker.pickImage(
                            source: ImageSource.gallery,
                            maxWidth: 800,
                            maxHeight: 800,
                          );
                          if (image != null) {
                            setState(() {
                              member['isImageLoading'] = true;
                            });
                            
                            // Beri waktu sejenak agar UI sempat me-render loading bar
                            await Future.delayed(const Duration(milliseconds: 50));
                            
                            try {
                              final bytes = await image.readAsBytes();
                              final base64Result = await ImageCompressor.compressImage(bytes, width: 300, quality: 30);
                              
                              if (base64Result != null) {
                                setState(() {
                                  member['foto'] = base64Result;
                                  member['isImageLoading'] = false;
                                });
                              } else {
                                setState(() {
                                  member['isImageLoading'] = false;
                                });
                              }
                            } catch (e) {
                              debugPrint('Error compressing image: $e');
                              setState(() {
                                member['isImageLoading'] = false;
                              });
                              if (mounted) {
                                CustomToast.show(context, 'Gagal memproses gambar. Coba gambar lain.', isError: true);
                              }
                            }
                          }
                        },
                        child: Stack(
                          children: [
                            Builder(
                              builder: (context) {
                                return Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    UserAvatar(
                                      userData: {
                                        if (widget.initialData != null &&
                                            widget.initialData!['email'] != null &&
                                            widget.initialData!['email'].toString().isNotEmpty &&
                                            widget.initialData!['email'] == member['email'])
                                          ...widget.initialData!,
                                        ...member,
                                      },
                                      radius: 30,
                                    ),
                                    if (member['isImageLoading'] == true)
                                      Container(
                                        width: 60,
                                        height: 60,
                                        decoration: BoxDecoration(
                                          color: Colors.black38,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Center(
                                          child: SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                          ),
                                        ),
                                      ),
                                  ],
                                );
                              }
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Anggota ${index + 1}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                            fontSize: 16,
                          ),
                        ),
                        if (member['namaLengkap'].toString().isNotEmpty)
                          Text(
                            member['namaLengkap'],
                            style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                if (_familyMembers.length > 1)
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.redAccent,
                    ),
                    onPressed: () => _removeMember(index),
                    tooltip: 'Hapus Anggota',
                  ),
              ],
            ),
            const Divider(height: 32),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: member['nik']?.toString(),
                    decoration: _customInputDecoration(
                      'NIK',
                      Icons.badge,
                    ).copyWith(isDense: true),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (val) => member['nik'] = val,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    initialValue: member['namaLengkap']?.toString(),
                    decoration: _customInputDecoration(
                      'Nama Lengkap',
                      Icons.person_outline,
                    ).copyWith(isDense: true),
                    textCapitalization: TextCapitalization.words,
                    onChanged: (val) => member['namaLengkap'] = val,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: member['tempatLahir']?.toString(),
                    decoration: _customInputDecoration(
                      'Tempat Lahir',
                      Icons.location_city,
                    ).copyWith(isDense: true),
                    textCapitalization: TextCapitalization.words,
                    onChanged: (val) => member['tempatLahir'] = val,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    readOnly: true,
                    key: Key('tgl_${index}_${member['tanggalLahir']}'),
                    initialValue: member['tanggalLahir']?.toString(),
                    decoration: _customInputDecoration(
                      'Tanggal Lahir',
                      Icons.calendar_today,
                    ).copyWith(isDense: true),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(1900),
                        lastDate: DateTime.now(),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: ColorScheme.light(
                                primary: AppTheme.primaryColor,
                                onPrimary: Colors.white,
                                onSurface: Colors.black,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (date != null) {
                        setState(() {
                          member['tanggalLahir'] =
                              "${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}";
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: member['email']?.toString(),
              decoration: _customInputDecoration(
                'Email Akses (Opsional)',
                Icons.email_outlined,
              ).copyWith(isDense: true),
              keyboardType: TextInputType.emailAddress,
              onChanged: (val) => member['email'] = val,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue:
                        [
                          'Islam',
                          'Kristen',
                          'Katolik',
                          'Hindu',
                          'Buddha',
                          'Konghucu',
                          'Lainnya',
                        ].contains(member['agama'])
                        ? member['agama']
                        : 'Islam',
                    decoration: _customInputDecoration(
                      'Agama',
                      Icons.star_border,
                    ).copyWith(isDense: true),
                    items:
                        [
                              'Islam',
                              'Kristen',
                              'Katolik',
                              'Hindu',
                              'Buddha',
                              'Konghucu',
                              'Lainnya',
                            ]
                            .map(
                              (s) => DropdownMenuItem(
                                value: s,
                                child: Text(s, overflow: TextOverflow.ellipsis),
                              ),
                            )
                            .toList(),
                    isExpanded: true,
                    onChanged: (val) => setState(() => member['agama'] = val),
                    icon: Icon(
                      Icons.arrow_drop_down,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue:
                        [
                          'PNS',
                          'TNI/Polri',
                          'Karyawan Swasta',
                          'Wiraswasta',
                          'Pelajar/Mahasiswa',
                          'Mengurus Rumah Tangga',
                          'Petani/Pekebun',
                          'Buruh',
                          'Belum/Tidak Bekerja',
                          'Lainnya',
                        ].contains(member['pekerjaan'])
                        ? member['pekerjaan']
                        : 'Belum/Tidak Bekerja',
                    decoration: _customInputDecoration(
                      'Pekerjaan',
                      Icons.work_outline,
                    ).copyWith(isDense: true),
                    items:
                        [
                              'PNS',
                              'TNI/Polri',
                              'Karyawan Swasta',
                              'Wiraswasta',
                              'Pelajar/Mahasiswa',
                              'Mengurus Rumah Tangga',
                              'Petani/Pekebun',
                              'Buruh',
                              'Belum/Tidak Bekerja',
                              'Lainnya',
                            ]
                            .map(
                              (s) => DropdownMenuItem(
                                value: s,
                                child: Text(s, overflow: TextOverflow.ellipsis),
                              ),
                            )
                            .toList(),
                    isExpanded: true,
                    onChanged: (val) =>
                        setState(() => member['pekerjaan'] = val),
                    icon: Icon(
                      Icons.arrow_drop_down,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('sh_${index}_${member['statusHubungan']}'),
                    initialValue:
                        [
                          'Kepala Keluarga',
                          'Istri',
                          'Anak',
                          'Anggota Keluarga',
                        ].contains(member['statusHubungan'])
                        ? member['statusHubungan']
                        : 'Anggota Keluarga',
                    decoration: _customInputDecoration(
                      'Status Hubungan',
                      Icons.group_outlined,
                    ).copyWith(isDense: true),
                    items:
                        ['Kepala Keluarga', 'Istri', 'Anak', 'Anggota Keluarga']
                            .map(
                              (s) => DropdownMenuItem(
                                value: s,
                                child: Text(s, overflow: TextOverflow.ellipsis),
                              ),
                            )
                            .toList(),
                    isExpanded: true,
                    onChanged: (val) =>
                        setState(() => member['statusHubungan'] = val),
                    icon: Icon(
                      Icons.arrow_drop_down,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('sp_${index}_${member['statusPerkawinan']}'),
                    initialValue:
                        [
                          'Belum Kawin',
                          'Kawin',
                          'Cerai Hidup',
                          'Cerai Mati',
                        ].contains(member['statusPerkawinan'])
                        ? member['statusPerkawinan']
                        : 'Belum Kawin',
                    decoration: _customInputDecoration(
                      'Status Perkawinan',
                      Icons.favorite_border,
                    ).copyWith(isDense: true),
                    items: ['Belum Kawin', 'Kawin', 'Cerai Hidup', 'Cerai Mati']
                        .map(
                          (s) => DropdownMenuItem(
                            value: s,
                            child: Text(s, overflow: TextOverflow.ellipsis),
                          ),
                        )
                        .toList(),
                    isExpanded: true,
                    onChanged: (val) =>
                        setState(() => member['statusPerkawinan'] = val),
                    icon: Icon(
                      Icons.arrow_drop_down,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('jk_${index}_${member['jenisKelamin']}'),
                    initialValue:
                        [
                          'Laki-laki',
                          'Perempuan',
                        ].contains(member['jenisKelamin'])
                        ? member['jenisKelamin']
                        : 'Laki-laki',
                    decoration: _customInputDecoration(
                      'Jenis Kelamin',
                      Icons.wc,
                    ).copyWith(isDense: true),
                    items: ['Laki-laki', 'Perempuan']
                        .map(
                          (s) => DropdownMenuItem(
                            value: s,
                            child: Text(s, overflow: TextOverflow.ellipsis),
                          ),
                        )
                        .toList(),
                    isExpanded: true,
                    onChanged: (val) =>
                        setState(() => member['jenisKelamin'] = val),
                    icon: Icon(
                      Icons.arrow_drop_down,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('shd_${index}_${member['statusHidup']}'),
                    initialValue:
                        [
                          'Aktif',
                          'Tidak Aktif',
                          'Meninggal',
                          'Pindah',
                        ].contains(member['statusHidup'])
                        ? member['statusHidup']
                        : 'Aktif',
                    decoration: _customInputDecoration(
                      'Status Hidup',
                      Icons.info_outline,
                    ).copyWith(isDense: true),
                    items: ['Aktif', 'Tidak Aktif', 'Meninggal', 'Pindah']
                        .map(
                          (s) => DropdownMenuItem(
                            value: s,
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: s == 'Meninggal'
                                        ? Colors.red
                                        : (s == 'Aktif'
                                              ? Colors.green
                                              : Colors.orange),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  s,
                                  style: TextStyle(
                                    color: s == 'Meninggal'
                                        ? Colors.red
                                        : (s == 'Aktif'
                                              ? Colors.green
                                              : Colors.orange.shade700),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (val) => setState(() => member['statusHidup'] = val),
                    icon: Icon(Icons.arrow_drop_down, color: AppTheme.primaryColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (widget.currentUserRoles?.contains('SUPER_ADMIN') == true ||
                widget.currentUserRoles?.contains('ADMIN_DESA') == true)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 32),
                  Row(
                    children: [
                      Icon(
                        Icons.admin_panel_settings,
                        color: AppTheme.primaryColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Pengaturan Role Akses (Login)',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: ValueKey('role_${index}_${member['roles']}'),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    initialValue: (() {
                      List<String> memberRoles = List<String>.from(
                        member['roles'] ?? ['WARGA'],
                      );
                      String current = memberRoles.firstWhere(
                        (r) => r != 'SUPER_ADMIN',
                        orElse: () => 'WARGA',
                      );
                      if (!_availableRoles
                          .where((r) => r != 'SUPER_ADMIN')
                          .contains(current)) {
                        return 'WARGA';
                      }
                      return current;
                    })(),
                    items: _availableRoles.where((r) => r != 'SUPER_ADMIN').map(
                      (role) {
                        return DropdownMenuItem<String>(
                          value: role,
                          child: Text(role),
                        );
                      },
                    ).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          List<String> existing = List<String>.from(
                            member['roles'] ?? [],
                          );
                          if (existing.contains('SUPER_ADMIN')) {
                            member['roles'] = ['SUPER_ADMIN', val];
                          } else {
                            member['roles'] = [val];
                          }
                        });
                      }
                    },
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

