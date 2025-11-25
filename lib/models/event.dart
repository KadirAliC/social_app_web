import 'package:cloud_firestore/cloud_firestore.dart';

class EventMaster {
  final String id;
  final String businessId;
  final DateTime createDate;
  final DateTime eventDate;

  EventMaster({
    required this.id,
    required this.businessId,
    required this.createDate,
    required this.eventDate,
  });

  factory EventMaster.fromMap(Map<String, dynamic> map, String id) {
    return EventMaster(
      id: id,
      businessId: map['business_id'] ?? '',
      createDate: (map['event_create_date'] as Timestamp).toDate(),
      eventDate: (map['event_date'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'business_id': businessId,
      'event_create_date': createDate,
      'event_date': eventDate,
    };
  }
}

class EventDetail {
  final String id;
  final String eventMasterId;
  final String title;
  final String description;
  final double discountRate;
  final String? imageBase64;

  EventDetail({
    required this.id,
    required this.eventMasterId,
    required this.title,
    required this.description,
    required this.discountRate,
    this.imageBase64,
  });

  factory EventDetail.fromMap(Map<String, dynamic> map, String id) {
    return EventDetail(
      id: id,
      eventMasterId: map['event_master_id'] ?? '',
      title: map['event_title'] ?? '',
      description: map['event_description'] ?? '',
      discountRate: (map['event_discount_rate'] ?? 0.0).toDouble(),
      imageBase64: map['event_image_base64'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'event_master_id': eventMasterId,
      'event_title': title,
      'event_description': description,
      'event_discount_rate': discountRate,
      'event_image_base64': imageBase64,
    };
  }
}

class Event {
  final EventMaster master;
  final EventDetail detail;

  Event({
    required this.master,
    required this.detail,
  });
}
