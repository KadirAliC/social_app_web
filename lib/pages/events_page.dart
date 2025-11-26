import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:universal_html/html.dart' as html;
import '../models/event.dart';
import '../models/business.dart';

class EventsPage extends StatefulWidget {
  final VoidCallback? onRequireBusinessInfo;

  const EventsPage({
    super.key,
    this.onRequireBusinessInfo,
  });

  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  final _editFormKey = GlobalKey<FormState>();
  final _editTitleController = TextEditingController();
  final _editDescriptionController = TextEditingController();
  final _editDiscountRateController = TextEditingController();
  DateTime _editSelectedDate = DateTime.now();
  TimeOfDay? _editSelectedTime;
  String? _editImageBase64;
  bool _isEditing = false;
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _cityCodeController = TextEditingController();
  final _districtCodeController = TextEditingController();
  final _discountRateController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  TimeOfDay? _selectedTime;
  String? _imageBase64;
  bool _isSaving = false;
  final List<Event> _events = [];
  bool _isLoading = true;
  Event? _selectedEvent;
  bool _isBusinessInfoValid = true;

  @override
  void initState() {
    super.initState();
    _loadEvents();
    _checkBusinessInfo();
  }

  Future<void> _checkBusinessInfo() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('businesses')
          .doc(userId)
          .get();

      if (doc.exists) {
        final business = Business.fromMap(doc.data()!, doc.id);
        
        final isValid = business.name.isNotEmpty &&
            business.cityName != null &&
            business.cityName!.isNotEmpty &&
            business.districtName != null &&
            business.districtName!.isNotEmpty;

        if (mounted) {
          setState(() {
            _isBusinessInfoValid = isValid;
          });

          if (!isValid) {
            await showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => AlertDialog(
                title: const Text('Eksik Bilgi'),
                content: const Text(
                  'Etkinlik girişi yapabilmek için İşletme Adı, Şehir ve İlçe bilgisi gibi zorunlu alanların doldurulmuş olması gerekmektedir.',
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onRequireBusinessInfo?.call();
                    },
                    child: const Text('Tamam'),
                  ),
                ],
              ),
            );
          }
        }
      }
    } catch (e) {
      print('Business info check failed: $e');
    }
  }
  void _showDetailDialog(Event event) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (event.detail.imageBase64 != null)
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        Uri.parse(event.detail.imageBase64!).data!.contentAsBytes(),
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                Text(
                  event.detail.title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Tarih: ${event.master.eventDate.day}/${event.master.eventDate.month}/${event.master.eventDate.year}${event.master.eventTime != null ? ' ${event.master.eventTime}' : ''}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                Text(
                  event.detail.description,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
                Text(
                  'İndirim Oranı: %${(event.detail.discountRate * 100).toStringAsFixed(0)}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 8),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Kapat'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showEditDialog(Event event) async {
    _editTitleController.text = event.detail.title;
    _editDescriptionController.text = event.detail.description;
    _editDiscountRateController.text = (event.detail.discountRate * 100).toString();
    _editSelectedDate = event.master.eventDate;
    _editImageBase64 = event.detail.imageBase64;

    if (event.master.eventTime != null) {
      final parts = event.master.eventTime!.split(':');
      if (parts.length == 2) {
        _editSelectedTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
    } else {
      _editSelectedTime = null;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Form(
            key: _editFormKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Etkinliği Düzenle',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  if (_editImageBase64 != null)
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            Uri.parse(_editImageBase64!).data!.contentAsBytes(),
                            height: 200,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          right: 8,
                          top: 8,
                          child: IconButton(
                            onPressed: () => setState(() => _editImageBase64 = null),
                            icon: const Icon(Icons.close),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _isEditing ? null : () async {
                      final input = html.FileUploadInputElement()..accept = 'image/*';
                      input.click();

                      await input.onChange.first;
                      if (input.files?.isEmpty ?? true) return;

                      setState(() => _isEditing = true);

                      try {
                        final file = input.files!.first;
                        final reader = html.FileReader();
                        reader.readAsDataUrl(file);
                        await reader.onLoad.first;
                        
                        final base64String = reader.result as String;
                        setState(() {
                          _editImageBase64 = base64String;
                          _isEditing = false;
                        });
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Görsel yüklenirken bir hata oluştu')),
                          );
                          setState(() => _isEditing = false);
                        }
                      }
                    },
                    icon: _isEditing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.upload),
                    label: Text(_isEditing ? 'Yükleniyor...' : 'Görsel Yükle'),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _editTitleController,
                    decoration: const InputDecoration(
                      labelText: 'Etkinlik Başlığı *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value?.isEmpty ?? true) {
                        return 'Başlık zorunludur';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _editDescriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Etkinlik Açıklaması *',
                      border: OutlineInputBorder(),
                      counterText: null,
                    ),
                    maxLength: 500,
                    maxLines: 5,
                    validator: (value) {
                      if (value?.isEmpty ?? true) {
                        return 'Açıklama zorunludur';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _editDiscountRateController,
                          decoration: const InputDecoration(
                            labelText: 'İndirim Oranı (%) *',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          validator: (value) {
                            if (value?.isEmpty ?? true) {
                              return 'İndirim oranı zorunludur';
                            }
                            final rate = int.tryParse(value!);
                            if (rate == null || rate < 0 || rate > 100) {
                              return 'Geçerli bir oran giriniz (0-100)';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _editSelectedDate,
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null && picked != _editSelectedDate) {
                              setState(() => _editSelectedDate = picked);
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Etkinlik Tarihi *',
                              border: OutlineInputBorder(),
                            ),
                            child: Text(
                              '${_editSelectedDate.day}/${_editSelectedDate.month}/${_editSelectedDate.year}',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: _editSelectedTime ?? TimeOfDay.now(),
                            );
                            if (picked != null) {
                              setState(() => _editSelectedTime = picked);
                            }
                          },
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Etkinlik Saati (Opsiyonel)',
                              border: const OutlineInputBorder(),
                              suffixIcon: _editSelectedTime != null
                                  ? IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: () => setState(() => _editSelectedTime = null),
                                    )
                                  : null,
                            ),
                            child: Text(
                              _editSelectedTime != null
                                  ? '${_editSelectedTime!.hour.toString().padLeft(2, '0')}:${_editSelectedTime!.minute.toString().padLeft(2, '0')}'
                                  : 'Seçiniz',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('İptal'),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: _isEditing
                            ? null
                            : () async {
                                if (_editFormKey.currentState!.validate()) {
                                  setState(() => _isEditing = true);
                                  try {
                                    await FirebaseFirestore.instance
                                        .collection('event_master')
                                        .doc(event.master.id)
                                        .update({
                                      'event_date': _editSelectedDate,
                                      'event_time': _editSelectedTime != null 
                                          ? '${_editSelectedTime!.hour.toString().padLeft(2, '0')}:${_editSelectedTime!.minute.toString().padLeft(2, '0')}' 
                                          : null,
                                    });

                                    await FirebaseFirestore.instance
                                        .collection('event_detail')
                                        .doc(event.detail.id)
                                        .update({
                                      'event_title': _editTitleController.text,
                                      'event_description': _editDescriptionController.text,
                                      'event_discount_rate': double.parse(_editDiscountRateController.text) / 100,
                                      'event_image_base64': _editImageBase64,
                                    });

                                    if (mounted) {
                                      Navigator.of(context).pop(true);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Etkinlik başarıyla güncellendi')),
                                      );
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Etkinlik güncellenirken bir hata oluştu')),
                                      );
                                    }
                                  } finally {
                                    if (mounted) {
                                      setState(() => _isEditing = false);
                                    }
                                  }
                                }
                              },
                        child: Text(_isEditing ? 'Güncelleniyor...' : 'Güncelle'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (result == true) {
      _loadEvents();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _cityCodeController.dispose();
    _districtCodeController.dispose();
    _discountRateController.dispose();
    _editTitleController.dispose();
    _editDescriptionController.dispose();
    _editDiscountRateController.dispose();
    super.dispose();
  }


  Future<void> _uploadEventImage() async {
    final input = html.FileUploadInputElement()..accept = 'image/*';
    input.click();

    await input.onChange.first;
    if (input.files?.isEmpty ?? true) return;

    setState(() => _isSaving = true);

    try {
      final file = input.files!.first;
      final reader = html.FileReader();
      reader.readAsDataUrl(file);
      await reader.onLoad.first;
      
      final base64String = reader.result as String;
      setState(() {
        _imageBase64 = base64String;
        _isSaving = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Görsel yüklenirken bir hata oluştu')),
        );
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _saveEvent() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      final masterRef = await FirebaseFirestore.instance
          .collection('event_master')
          .add({
        'business_id': userId,
        'event_create_date': DateTime.now(),
        'event_date': _selectedDate,
        'event_time': _selectedTime != null 
            ? '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}' 
            : null,
      });

      await FirebaseFirestore.instance
          .collection('event_detail')
          .add({
        'event_master_id': masterRef.id,
        'event_city_code': _cityCodeController.text,
        'event_district_code': _districtCodeController.text,
        'event_title': _titleController.text,
        'event_description': _descriptionController.text,
        'event_discount_rate': double.parse(_discountRateController.text) / 100,
        'event_image_base64': _imageBase64,
      });

      if (mounted) {
        _titleController.clear();
        _descriptionController.clear();
        _cityCodeController.clear();
        _districtCodeController.clear();
        _discountRateController.clear();
        setState(() {
          _imageBase64 = null;
          _selectedDate = DateTime.now();
          _selectedTime = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Etkinlik başarıyla oluşturuldu')),
        );

        _loadEvents();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Etkinlik oluşturulurken bir hata oluştu')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _loadEvents() async {
    try {
      setState(() => _isLoading = true);
      
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      print('Firestore sorgusu başlıyor... User ID: $userId');

      final masterSnapshot = await FirebaseFirestore.instance
          .collection('event_master')
          .where('business_id', isEqualTo: userId)
          .get();

      print('event_master kayıt sayısı: ${masterSnapshot.docs.length}');

      if (masterSnapshot.docs.isEmpty) {
        print('Hiç event_master kaydı bulunamadı');
        setState(() {
          _events.clear();
          _isLoading = false;
        });
        return;
      }

      final masterIds = masterSnapshot.docs.map((doc) => doc.id).toList();
      print('Master ID listesi: $masterIds');

      final detailSnapshot = await FirebaseFirestore.instance
          .collection('event_detail')
          .where('event_master_id', whereIn: masterIds)
          .get();

      print('event_detail kayıt sayısı: ${detailSnapshot.docs.length}');

      final detailMap = <String, DocumentSnapshot>{};
      for (final doc in detailSnapshot.docs) {
        final masterId = doc.data()['event_master_id'] as String;
        detailMap[masterId] = doc;
      }

      final events = <Event>[];
      for (final masterDoc in masterSnapshot.docs) {
        final masterData = masterDoc.data();
        print('Master veri: $masterData');

        final detailDoc = detailMap[masterDoc.id];
        if (detailDoc != null) {
          final detailData = detailDoc.data() as Map<String, dynamic>;
          print('Detail veri: $detailData');

          try {
            final master = EventMaster.fromMap(masterData, masterDoc.id);
            final detail = EventDetail.fromMap(detailData, detailDoc.id);
            events.add(Event(master: master, detail: detail));
          } catch (e) {
            print('Veri dönüşüm hatası: $e');
          }
        }
      }

      print('Toplam eşleşen etkinlik sayısı: ${events.length}');

      events.sort((a, b) => b.master.eventDate.compareTo(a.master.eventDate));

      if (mounted) {
        setState(() {
          _events.clear();
          _events.addAll(events);
          _isLoading = false;
          if (events.isNotEmpty && _selectedEvent == null) {
            _selectedEvent = events.first;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Etkinlikler yüklenirken bir hata oluştu')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_isBusinessInfoValid) {
      return const Center(
        child: Text('Etkinlik girişi yapmak için işletme bilgilerinizi tamamlayınız.'),
      );
    }

    return Row(
      children: [
        SizedBox(
          width: 300,
          child: Card(
            margin: const EdgeInsets.all(8),
            child: ListView.builder(
              itemCount: _events.length,
              itemBuilder: (context, index) {
                final event = _events[index];
                return ListTile(
                  selected: _selectedEvent == event,
                  leading: event.detail.imageBase64 != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.memory(
                            Uri.parse(event.detail.imageBase64!).data!.contentAsBytes(),
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(Icons.event, color: Colors.grey),
                        ),
                  title: Text(
                    event.detail.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    'Tarih: ${event.master.eventDate.day}/${event.master.eventDate.month}/${event.master.eventDate.year}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _showEditDialog(event),
                      ),
                    ],
                  ),
                  onTap: () => _showDetailDialog(event),
                );
              },
            ),
          ),
        ),
        Expanded(
          child: Card(
            margin: const EdgeInsets.all(8),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Yeni Etkinlik Oluştur',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    if (_imageBase64 != null)
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              Uri.parse(_imageBase64!).data!.contentAsBytes(),
                              height: 200,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            right: 8,
                            top: 8,
                            child: IconButton(
                              onPressed: () => setState(() => _imageBase64 = null),
                              icon: const Icon(Icons.close),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _isSaving ? null : _uploadEventImage,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.upload),
                      label: Text(_isSaving ? 'Yükleniyor...' : 'Görsel Yükle'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Etkinlik Başlığı *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value?.isEmpty ?? true) {
                          return 'Başlık zorunludur';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Etkinlik Açıklaması *',
                        border: OutlineInputBorder(),
                        counterText: null,
                      ),
                      maxLength: 500,
                      maxLines: 5,
                      validator: (value) {
                        if (value?.isEmpty ?? true) {
                          return 'Açıklama zorunludur';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _discountRateController,
                            decoration: const InputDecoration(
                              labelText: 'İndirim Oranı (%) *',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            validator: (value) {
                              if (value?.isEmpty ?? true) {
                                return 'İndirim oranı zorunludur';
                              }
                              final rate = int.tryParse(value!);
                              if (rate == null || rate < 0 || rate > 100) {
                                return 'Geçerli bir oran giriniz (0-100)';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: InkWell(
                            onTap: () => _selectDate(context),
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Etkinlik Tarihi *',
                                border: OutlineInputBorder(),
                              ),
                              child: Text(
                                '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: _selectedTime ?? TimeOfDay.now(),
                              );
                              if (picked != null) {
                                setState(() => _selectedTime = picked);
                              }
                            },
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: 'Etkinlik Saati (Opsiyonel)',
                                border: const OutlineInputBorder(),
                                suffixIcon: _selectedTime != null
                                    ? IconButton(
                                        icon: const Icon(Icons.clear),
                                        onPressed: () => setState(() => _selectedTime = null),
                                      )
                                    : null,
                              ),
                              child: Text(
                                _selectedTime != null
                                    ? '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}'
                                    : 'Seçiniz',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _saveEvent,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.save),
                        label: Text(_isSaving ? 'Kaydediliyor...' : 'Etkinlik Oluştur'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.all(16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
