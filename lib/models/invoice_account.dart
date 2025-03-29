import 'package:latlong2/latlong.dart';
import 'payment.dart';

class Customer {
  final String id;
  final String commercialName;
  final String legalName;
  final String ruc;
  final Contact contact;

  Customer({
    required this.id,
    required this.commercialName,
    required this.legalName,
    required this.ruc,
    required this.contact,
  });
}

class Contact {
  final String name;
  final String address;
  final String phone;
  final LatLng? location;

  Contact({
    required this.name,
    required this.address,
    required this.phone,
    this.location,
  });
}

enum InvoiceAccountStatus {
  pending,
  partiallyPaid,
  paid,
  expired,
}

class InvoiceAccount {
  final String id;
  final Customer customer;
  final String concept;
  final String invoiceNumber;
  final DateTime expirationDate;
  final double totalAmount;
  final double paidAmount;
  final InvoiceAccountStatus status;
  final List<Payment> payments;

  InvoiceAccount({
    required this.id,
    required this.customer,
    required this.concept,
    required this.invoiceNumber,
    required this.expirationDate,
    required this.totalAmount,
    this.paidAmount = 0.0,
    this.status = InvoiceAccountStatus.pending,
    this.payments = const [],
  });

  double get remainingAmount => totalAmount - paidAmount;
  
  bool get isExpired => expirationDate.isBefore(DateTime.now());
}
