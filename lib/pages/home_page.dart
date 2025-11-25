import 'dart:html' as html;
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart'
    hide GoogleMapController;
import '../models/business.dart';
import 'events_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 1;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _capacityController = TextEditingController();
  final _addressController = TextEditingController();
  final _addressDescriptionController = TextEditingController();
  String? _selectedCity;
  String? _selectedDistrict;
  List<Map<String, dynamic>>? _cities;

  String? _imagePath;
  Business? _originalBusiness;
  final _hasChangesNotifier = ValueNotifier<bool>(false);
  final _isSavingNotifier = ValueNotifier<bool>(false);
  final _imageNotifier = ValueNotifier<String?>(null);
  double? _latitude;
  double? _longitude;
  bool _isLoading = false;

  Future<void> _loadCities() async {
    try {
      print('Cities.json yükleniyor...');
      final response = await rootBundle.loadString('assets/cities.json');
      print('JSON dosyası okundu: ${response.substring(0, 100)}...');
      
      final data = json.decode(response) as Map<String, dynamic>;
      print('JSON parse edildi: ${data.keys}');
      
      final citiesList = List<Map<String, dynamic>>.from(data['cities']);
      print('Cities listesi oluşturuldu: ${citiesList.length} şehir');
      
      if (mounted) {
        setState(() {
          _cities = citiesList;
          print('State güncellendi. Şehirler: ${_cities?.map((c) => c['name']).toList()}');
        });
      }
    } catch (e, stackTrace) {
      print('Şehirler yüklenirken hata: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Şehir listesi yüklenemedi')),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_checkForChanges);
    _capacityController.addListener(_checkForChanges);
    _addressController.addListener(_checkForChanges);
    _addressDescriptionController.addListener(_checkForChanges);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBusinessData();
      _loadCities();
    });
  }

  @override
  void dispose() {
    _nameController.removeListener(_checkForChanges);
    _capacityController.removeListener(_checkForChanges);
    _addressController.removeListener(_checkForChanges);
    _addressDescriptionController.removeListener(_checkForChanges);
    _hasChangesNotifier.dispose();
    _isSavingNotifier.dispose();
    _imageNotifier.dispose();
    _nameController.dispose();
    _capacityController.dispose();
    _addressController.dispose();
    _addressDescriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadBusinessData() async {
    _isLoading = true;
    _isSavingNotifier.value = true;
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('businesses')
          .doc(userId)
          .get();

      if (doc.exists) {
        final business = Business.fromMap(doc.data()!, doc.id);
        _nameController.text = business.name;
        _capacityController.text = business.capacity?.toString() ?? '';
        _addressController.text = business.address ?? '';
        _addressDescriptionController.text = business.addressDescription ?? '';
        _imagePath = business.imagePath;
        _originalBusiness = business;
        _latitude = business.latitude;
        _longitude = business.longitude;
        _selectedCity = business.cityName;
        _selectedDistrict = business.districtName;
        if (_latitude != null && _longitude != null) {
          _updateMarker(LatLng(_latitude!, _longitude!));
        }
      }
    } finally {
      _isLoading = false;
      _isSavingNotifier.value = false;
      _imageNotifier.value = _imagePath;
    }
  }

  void _updateMarker(LatLng position) {
    setState(() {
    });
  }


  Future<void> _uploadLogo() async {
    final input = html.FileUploadInputElement()..accept = 'image/*';
    input.click();

    await input.onChange.first;
    if (input.files?.isEmpty ?? true) return;

    _isSavingNotifier.value = true;

    try {
      final file = input.files!.first;
      final reader = html.FileReader();
      reader.readAsDataUrl(file);
      await reader.onLoad.first;

      final base64String = reader.result as String;
      _imagePath = base64String;
      _imageNotifier.value = base64String;
      _checkForChanges();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logo yüklenirken bir hata oluştu')),
      );
    } finally {
      _isSavingNotifier.value = false;
    }
  }

  void _checkForChanges() {
    if (!mounted) return;

    if (_originalBusiness == null) {
      _hasChangesNotifier.value = true;
      return;
    }

    final newHasChanges =
        _nameController.text != _originalBusiness!.name ||
        _capacityController.text !=
            (_originalBusiness!.capacity?.toString() ?? '') ||
        _addressDescriptionController.text !=
            (_originalBusiness!.addressDescription ?? '') ||
        _imagePath != _originalBusiness!.imagePath ||
        _latitude != _originalBusiness!.latitude ||
        _longitude != _originalBusiness!.longitude ||
        _selectedCity != _originalBusiness!.cityName ||
        _selectedDistrict != _originalBusiness!.districtName;

    _hasChangesNotifier.value = newHasChanges;
  }

  Future<void> _saveBusiness() async {
    if (!_formKey.currentState!.validate()) return;

    _isSavingNotifier.value = true;

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      final business = Business(
        id: userId,
        name: _nameController.text,
        capacity: int.tryParse(_capacityController.text),
        email: _originalBusiness?.email ?? '',
        imagePath: _imagePath,
        address: _addressController.text,
        addressDescription: _addressDescriptionController.text,
        latitude: _latitude,
        longitude: _longitude,
        cityName: _selectedCity,
        districtName: _selectedDistrict,
      );

      await FirebaseFirestore.instance
          .collection('businesses')
          .doc(userId)
          .set(business.toMap());

      if (mounted) {
        _originalBusiness = business;
        _hasChangesNotifier.value = false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('İşletme bilgileri kaydedildi')),
        );
      }
    } finally {
      _isSavingNotifier.value = false;
    }
  }

  Widget _buildContent() {
    if (_isLoading && _selectedIndex == 0) {
      return const Center(child: CircularProgressIndicator());
    }

    switch (_selectedIndex) {
      case 1:
        return const EventsPage();
      case 0:
        return SingleChildScrollView(
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  ValueListenableBuilder<String?>(
                                    valueListenable: _imageNotifier,
                                    builder: (context, imagePath, _) {
                                      final hasImage = imagePath != null;
                                      if (!hasImage)
                                        return const SizedBox.shrink();
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 16,
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: Image.memory(
                                            Uri.parse(
                                              _imagePath!,
                                            ).data!.contentAsBytes(),
                                            height: 200,
                                            width: double.infinity,
                                            fit: BoxFit.contain,
                                            gaplessPlayback: true,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  ValueListenableBuilder<bool>(
                                    valueListenable: _isSavingNotifier,
                                    builder: (context, isSaving, _) =>
                                        ElevatedButton.icon(
                                          onPressed: isSaving
                                              ? null
                                              : _uploadLogo,
                                          icon: isSaving
                                              ? const SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                )
                                              : const Icon(Icons.upload),
                                          label: Text(
                                            isSaving
                                                ? 'Yükleniyor...'
                                                : 'Logo Yükle',
                                          ),
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextFormField(
                              controller: _nameController,
                              decoration: const InputDecoration(
                                labelText: 'İşletme Adı *',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value?.isEmpty ?? true) {
                                  return 'İşletme adı zorunludur';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _capacityController,
                              decoration: const InputDecoration(
                                labelText: 'İşletme Kapasitesi',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: _selectedCity,
                                    decoration: const InputDecoration(
                                      labelText: 'Şehir *',
                                      border: OutlineInputBorder(),
                                    ),
                                    items: _cities?.map((city) {
                                      final name = city['name'] as String;
                                      return DropdownMenuItem(
                                        value: name,
                                        child: Text(name),
                                      );
                                    }).toList() ?? [],
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedCity = value;
                                        _selectedDistrict = null;
                                      });
                                      _checkForChanges();
                                    },
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Şehir seçimi zorunludur';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: _selectedDistrict,
                                    decoration: const InputDecoration(
                                      labelText: 'İlçe *',
                                      border: OutlineInputBorder(),
                                    ),
                                    items: _selectedCity != null
                                        ? (_cities
                                                ?.firstWhere(
                                                    (city) => city['name'] == _selectedCity,
                                                    orElse: () => {'districts': []})
                                                ['districts'] as List<dynamic>)
                                            .map((district) {
                                              final name = district['name'] as String;
                                              return DropdownMenuItem(
                                                value: name,
                                                child: Text(name),
                                              );
                                            }).toList()
                                        : [],
                                    onChanged: _selectedCity == null
                                        ? null
                                        : (value) {
                                            setState(() {
                                              _selectedDistrict = value;
                                            });
                                            _checkForChanges();
                                          },
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'İlçe seçimi zorunludur';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextFormField(
                              controller: _addressController,
                              decoration: const InputDecoration(
                                labelText: 'Adres',
                                border: OutlineInputBorder(),
                                counterText: null,
                              ),
                              maxLength: 250,
                              maxLines: 3,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _addressDescriptionController,
                              decoration: const InputDecoration(
                                labelText: 'Adres Tarifi',
                                border: OutlineInputBorder(),
                                counterText: null,
                                hintText:
                                    'Örn: Sağlık ocağının yanı, mavi tabelanın karşısı',
                              ),
                              maxLength: 250,
                              maxLines: 3,
                            ),
                            const SizedBox(height: 16),
                            if (_latitude != null && _longitude != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  'Konum: ${_latitude!.toStringAsFixed(6)}, ${_longitude!.toStringAsFixed(6)}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    ValueListenableBuilder<bool>(
                      valueListenable: _hasChangesNotifier,
                      builder: (context, hasChanges, _) =>
                          ValueListenableBuilder<bool>(
                            valueListenable: _isSavingNotifier,
                            builder: (context, isSaving, _) =>
                                ElevatedButton.icon(
                                  onPressed: (isSaving || !hasChanges)
                                      ? null
                                      : _saveBusiness,
                                  icon: isSaving
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.save),
                                  label: const Text('Kaydet'),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.all(16),
                                  ),
                                ),
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      default:
        return const Center(child: Text('Hoş Geldiniz'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isSmallScreen = screenWidth < 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ana Sayfa'),
        leading: isSmallScreen
            ? Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              )
            : null,
      ),
      drawer: isSmallScreen ? _buildDrawer(context) : null,
      body: Row(
        children: [
          if (!isSmallScreen)
            SizedBox(width: 250, child: _buildDrawerContents(context)),
          Expanded(
            child: Container(
              color: Colors.grey[100],
              padding: const EdgeInsets.all(16),
              child: _buildContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(child: _buildDrawerContents(context));
  }

  Widget _buildDrawerContents(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        DrawerHeader(
          decoration: const BoxDecoration(color: Colors.blue),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ValueListenableBuilder<String?>(
                valueListenable: _imageNotifier,
                builder: (context, imagePath, _) => CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white,
                  child: imagePath != null
                      ? ClipOval(
                          child: Image.memory(
                            Uri.parse(imagePath).data!.contentAsBytes(),
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                          ),
                        )
                      : const Icon(Icons.person, size: 35),
                ),
              ),
              const SizedBox(height: 10),
              ValueListenableBuilder<Business?>(
                valueListenable: ValueNotifier<Business?>(_originalBusiness),
                builder: (context, business, _) => Text(
                  business?.name ?? 'Menü',
                  style: const TextStyle(color: Colors.white, fontSize: 24),
                ),
              ),
            ],
          ),
        ),
        ListTile(
          leading: const Icon(Icons.event),
          title: const Text('Etkinliklerim'),
          onTap: () {
            if (MediaQuery.of(context).size.width < 600) {
              Navigator.pop(context);
            }
            setState(() {
              _selectedIndex = 1;
            });
          },
        ),
        ListTile(
          leading: const Icon(Icons.business),
          title: const Text('İşletme Bilgileri'),
          onTap: () {
            if (MediaQuery.of(context).size.width < 600) {
              Navigator.pop(context);
            }
            setState(() {
              _selectedIndex = 0;
            });
          },
        ),

        ListTile(
          leading: const Icon(Icons.exit_to_app),
          title: const Text('Çıkış Yap'),
          onTap: () async {
            if (MediaQuery.of(context).size.width < 600) {
              Navigator.pop(context);
            }
            await FirebaseAuth.instance.signOut();
            if (context.mounted) {
              Navigator.pushReplacementNamed(context, '/login');
            }
          },
        ),
      ],
    );
  }
}
