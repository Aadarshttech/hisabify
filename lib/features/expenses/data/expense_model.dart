import 'package:cloud_firestore/cloud_firestore.dart';

class Expense {
  final String id;
  final String title;
  final double amount;
  final String paidById;
  final String paidByName;
  final DateTime date;
  final String category;
  final List<String> splitAmong;
  final String? notes;
  final bool isDeleted;
  final DateTime? deletedAt;
  final String? deletedByName;

  Expense({
    required this.id,
    required this.title,
    required this.amount,
    required this.paidById,
    required this.paidByName,
    required this.date,
    required this.category,
    required this.splitAmong,
    this.notes,
    this.isDeleted = false,
    this.deletedAt,
    this.deletedByName,
  });

  factory Expense.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    
    DateTime parsedDate;
    if (data['date'] is Timestamp) {
      parsedDate = (data['date'] as Timestamp).toDate();
    } else if (data['date'] is String) {
      parsedDate = DateTime.tryParse(data['date'] as String) ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }

    DateTime? deletedDate;
    if (data['deletedAt'] is Timestamp) {
      deletedDate = (data['deletedAt'] as Timestamp).toDate();
    } else if (data['deletedAt'] is String) {
      deletedDate = DateTime.tryParse(data['deletedAt'] as String);
    }

    return Expense(
      id: doc.id,
      title: data['title'] as String? ?? 'Expense',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      paidById: data['paidById'] as String? ?? '',
      paidByName: data['paidByName'] as String? ?? '',
      date: parsedDate,
      category: data['category'] as String? ?? 'Groceries',
      splitAmong: (data['splitAmong'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      notes: data['notes'] as String?,
      isDeleted: data['isDeleted'] as bool? ?? false,
      deletedAt: deletedDate,
      deletedByName: data['deletedByName'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'amount': amount,
      'paidById': paidById,
      'paidByName': paidByName,
      'date': Timestamp.fromDate(date),
      'category': category,
      'splitAmong': splitAmong,
      'notes': notes,
      'isDeleted': isDeleted,
      if (deletedAt != null) 'deletedAt': Timestamp.fromDate(deletedAt!),
      if (deletedByName != null) 'deletedByName': deletedByName,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}

class Flatmate {
  final String id;
  final String name;
  final String role;
  final String? email;
  final String? uid;
  final String? avatarUrl;

  const Flatmate({
    required this.id,
    required this.name,
    this.role = 'Flatmate',
    this.email,
    this.uid,
    this.avatarUrl,
  });
}

class DebtTransfer {
  final String fromPerson;
  final String toPerson;
  final double amount;

  DebtTransfer({
    required this.fromPerson,
    required this.toPerson,
    required this.amount,
  });
}

class Settlement {
  final String id;
  final String fromPerson;
  final String toPerson;
  final double amount;
  final DateTime date;
  final String? note;
  final bool isDeleted;
  final DateTime? deletedAt;
  final String? deletedByName;

  Settlement({
    required this.id,
    required this.fromPerson,
    required this.toPerson,
    required this.amount,
    required this.date,
    this.note,
    this.isDeleted = false,
    this.deletedAt,
    this.deletedByName,
  });

  factory Settlement.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    
    DateTime parsedDate;
    if (data['date'] is Timestamp) {
      parsedDate = (data['date'] as Timestamp).toDate();
    } else {
      parsedDate = DateTime.now();
    }

    DateTime? deletedDate;
    if (data['deletedAt'] is Timestamp) {
      deletedDate = (data['deletedAt'] as Timestamp).toDate();
    }

    return Settlement(
      id: doc.id,
      fromPerson: data['fromPerson'] as String? ?? '',
      toPerson: data['toPerson'] as String? ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      date: parsedDate,
      note: data['note'] as String?,
      isDeleted: data['isDeleted'] as bool? ?? false,
      deletedAt: deletedDate,
      deletedByName: data['deletedByName'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'fromPerson': fromPerson,
      'toPerson': toPerson,
      'amount': amount,
      'date': Timestamp.fromDate(date),
      'note': note,
      'isDeleted': isDeleted,
      if (deletedAt != null) 'deletedAt': Timestamp.fromDate(deletedAt!),
      if (deletedByName != null) 'deletedByName': deletedByName,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
