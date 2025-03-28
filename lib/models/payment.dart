enum PaymentMethod {
  cash,
  transfer,
  pos,
  qr,
}

class Payment {
  final String id;
  final String accountId;
  final double amount;
  final DateTime date;
  final PaymentMethod method;
  final String? reconciliationCode;
  final String? evidence;
  final double? cashReceived;
  final double? cashChange;

  Payment({
    required this.id,
    required this.accountId,
    required this.amount,
    required this.date,
    required this.method,
    this.reconciliationCode,
    this.evidence,
    this.cashReceived,
    this.cashChange,
  });
}
