import 'package:latlong2/latlong.dart';
import '../models/account.dart';
import '../models/payment.dart';

class DummyDataService {
  static List<Account> getAccounts() {
    return [
      Account(
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
        expirationDate: DateTime.now().add(const Duration(days: 5)),
        totalAmount: 1500.0,
        paidAmount: 500.0,
        status: AccountStatus.partiallyPaid,
        payments: [
          Payment(
            id: 'p1',
            accountId: '1',
            amount: 500.0,
            date: DateTime.now().subtract(const Duration(days: 5)),
            method: PaymentMethod.cash,
            cashReceived: 500.0,
            cashChange: 0.0,
          ),
        ],
      ),
      Account(
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
        concept: 'Suministro de harina',
        expirationDate: DateTime.now().subtract(const Duration(days: 2)),
        totalAmount: 800.0,
        paidAmount: 0.0,
        status: AccountStatus.expired,
      ),
      Account(
        id: '3',
        customer: Customer(
          id: '103',
          commercialName: 'Restaurante El Sabor',
          legalName: 'Gastronomía Peruana E.I.R.L.',
          ruc: '20567891234',
          contact: Contact(
            name: 'Carlos Rodríguez',
            address: 'Av. La Marina 789, Lima',
            phone: '945678123',
            location: LatLng(-12.076374, -77.052793),
          ),
        ),
        concept: 'Suministro de insumos alimenticios',
        expirationDate: DateTime.now().add(const Duration(days: 15)),
        totalAmount: 2500.0,
        paidAmount: 0.0,
        status: AccountStatus.pending,
      ),
      Account(
        id: '4',
        customer: Customer(
          id: '104',
          commercialName: 'Farmacia Salud Total',
          legalName: 'Medicamentos y Salud S.A.',
          ruc: '20345678912',
          contact: Contact(
            name: 'Ana Gómez',
            address: 'Jr. Huancavelica 321, Lima',
            phone: '956781234',
            location: LatLng(-12.036374, -77.062793),
          ),
        ),
        concept: 'Suministro de productos farmacéuticos',
        expirationDate: DateTime.now().add(const Duration(days: 10)),
        totalAmount: 3000.0,
        paidAmount: 3000.0,
        status: AccountStatus.paid,
        payments: [
          Payment(
            id: 'p2',
            accountId: '4',
            amount: 1500.0,
            date: DateTime.now().subtract(const Duration(days: 20)),
            method: PaymentMethod.transfer,
            reconciliationCode: 'TR-12345',
          ),
          Payment(
            id: 'p3',
            accountId: '4',
            amount: 1500.0,
            date: DateTime.now().subtract(const Duration(days: 10)),
            method: PaymentMethod.pos,
            reconciliationCode: 'POS-67890',
          ),
        ],
      ),
      Account(
        id: '5',
        customer: Customer(
          id: '105',
          commercialName: 'Librería El Saber',
          legalName: 'Libros y Útiles S.A.C.',
          ruc: '20678912345',
          contact: Contact(
            name: 'Pedro Díaz',
            address: 'Av. Arequipa 654, Lima',
            phone: '967812345',
            location: LatLng(-12.086374, -77.022793),
          ),
        ),
        concept: 'Venta de útiles escolares',
        expirationDate: DateTime.now().add(const Duration(days: 3)),
        totalAmount: 1200.0,
        paidAmount: 600.0,
        status: AccountStatus.partiallyPaid,
        payments: [
          Payment(
            id: 'p4',
            accountId: '5',
            amount: 600.0,
            date: DateTime.now().subtract(const Duration(days: 7)),
            method: PaymentMethod.qr,
            reconciliationCode: 'QR-54321',
          ),
        ],
      ),
    ];
  }
}
