import 'package:latlong2/latlong.dart';
import '../models/invoice_account.dart';
import '../models/payment.dart';

class DummyDataService {
  static List<InvoiceAccount> getInvoiceAccounts() {
    return [
      InvoiceAccount(
        id: '1',
        customer: Customer(
          id: '101',
          commercialName: 'Ferretería El Constructor',
          legalName: 'Materiales de Construcción S.A.',
          ruc: '20123456789',
          contact: Contact(
            name: 'Juan Pérez',
            address: 'Av. Los Constructores 123, Lima',
            phone: '987654321',
            location: LatLng(-12.046374, -77.042793),
          ),
        ),
        concept: 'Venta de materiales de construcción',
        invoiceNumber: 'F001-00001',
        expirationDate: DateTime.now().add(const Duration(days: 5)),
        totalAmount: 1500.0,
        paidAmount: 500.0,
        status: InvoiceAccountStatus.partiallyPaid,
        payments: [
          Payment(
            id: 'p1',
            invoiceAccountId: '1',
            amount: 500.0,
            date: DateTime.now().subtract(const Duration(days: 5)),
            method: PaymentMethod.cash,
            cashReceived: 500.0,
            cashChange: 0.0,
          ),
        ],
      ),
      InvoiceAccount(
        id: '2',
        customer: Customer(
          id: '102',
          commercialName: 'Panadería La Espiga',
          legalName: 'Panes y Pasteles S.A.C.',
          ruc: '20987654321',
          contact: Contact(
            name: 'María López',
            address: 'Jr. Las Delicias 456, Lima',
            phone: '912345678',
            location: LatLng(-12.056374, -77.032793),
          ),
        ),
        concept: 'Compra de insumos para panadería',
        invoiceNumber: 'F001-00002',
        expirationDate: DateTime.now().subtract(const Duration(days: 10)),
        totalAmount: 800.0,
        paidAmount: 0.0,
        status: InvoiceAccountStatus.expired,
        payments: [],
      ),
      InvoiceAccount(
        id: '3',
        customer: Customer(
          id: '103',
          commercialName: 'Restaurante El Buen Sabor',
          legalName: 'Gastronomía Peruana E.I.R.L.',
          ruc: '20567891234',
          contact: Contact(
            name: 'Carlos Rodríguez',
            address: 'Av. La Marina 789, Lima',
            phone: '945678123',
            location: LatLng(-12.076374, -77.052793),
          ),
        ),
        concept: 'Servicio de catering para evento',
        invoiceNumber: 'F001-00003',
        expirationDate: DateTime.now().add(const Duration(days: 15)),
        totalAmount: 2500.0,
        paidAmount: 0.0,
        status: InvoiceAccountStatus.pending,
        payments: [],
      ),
      InvoiceAccount(
        id: '4',
        customer: Customer(
          id: '104',
          commercialName: 'Librería El Saber',
          legalName: 'Distribuidora de Libros S.A.',
          ruc: '20345678912',
          contact: Contact(
            name: 'Ana García',
            address: 'Jr. Arequipa 321, Lima',
            phone: '978123456',
            location: LatLng(-12.086374, -77.022793),
          ),
        ),
        concept: 'Compra de libros escolares',
        invoiceNumber: 'F001-00004',
        expirationDate: DateTime.now().subtract(const Duration(days: 5)),
        totalAmount: 1200.0,
        paidAmount: 1200.0,
        status: InvoiceAccountStatus.paid,
        payments: [
          Payment(
            id: 'p2',
            invoiceAccountId: '4',
            amount: 1200.0,
            date: DateTime.now().subtract(const Duration(days: 7)),
            method: PaymentMethod.transfer,
            reconciliationCode: 'TRF123456',
          ),
        ],
      ),
    ];
  }
}
