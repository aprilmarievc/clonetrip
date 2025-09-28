class Expense {
  const Expense({
    required this.id,
    required this.groupId,
    required this.payerUserId,
    required this.amount,
    required this.currency,
    required this.splits,
    required this.description,
    required this.createdAtIso,
    this.receiptUrl,
  });

  final String id;
  final String groupId;
  final String payerUserId;
  final double amount;
  final String currency;
  final Map<String, double> splits; // userId -> amount
  final String description;
  final String createdAtIso;
  final String? receiptUrl;

  factory Expense.fromMap(String id, Map<String, dynamic> data) {
    final rawSplits =
        (data['splits'] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};
    return Expense(
      id: id,
      groupId: data['groupId'] as String? ?? '',
      payerUserId: data['payerUserId'] as String? ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      currency: data['currency'] as String? ?? 'USD',
      splits: rawSplits.map((k, v) => MapEntry(k, (v as num).toDouble())),
      description: data['description'] as String? ?? '',
      createdAtIso:
          data['createdAtIso'] as String? ?? DateTime.now().toIso8601String(),
      receiptUrl: data['receiptUrl'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'groupId': groupId,
      'payerUserId': payerUserId,
      'amount': amount,
      'currency': currency,
      'splits': splits,
      'description': description,
      'createdAtIso': createdAtIso,
      if (receiptUrl != null) 'receiptUrl': receiptUrl,
    };
  }
}
