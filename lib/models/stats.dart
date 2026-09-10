import 'json_helpers.dart';

class OwnerStats {
  OwnerStats({
    required this.lossDeclarations,
    required this.findDeclarations,
    required this.returnedDocuments,
    required this.pendingDocuments,
    required this.escrowTotal,
    required this.releasedTotal,
    required this.walletBalance,
  });

  factory OwnerStats.fromJson(Map<String, dynamic> json) => OwnerStats(
        lossDeclarations: asInt(json['loss_declarations']),
        findDeclarations: asInt(json['find_declarations']),
        returnedDocuments: asInt(json['returned_documents']),
        pendingDocuments: asInt(json['pending_documents']),
        escrowTotal: asDouble(json['escrow_total']),
        releasedTotal: asDouble(json['released_total']),
        walletBalance: asDouble(json['wallet_balance']),
      );

  factory OwnerStats.empty() => OwnerStats(
        lossDeclarations: 0,
        findDeclarations: 0,
        returnedDocuments: 0,
        pendingDocuments: 0,
        escrowTotal: 0,
        releasedTotal: 0,
        walletBalance: 0,
      );

  final int lossDeclarations;
  final int findDeclarations;
  final int returnedDocuments;
  final int pendingDocuments;
  final double escrowTotal;
  final double releasedTotal;
  final double walletBalance;
}

class FinderStats {
  FinderStats({
    required this.findsDone,
    required this.rewardedLosses,
    required this.ongoing,
    required this.returnedDocuments,
    required this.earningsTotal,
    required this.walletBalance,
  });

  factory FinderStats.fromJson(Map<String, dynamic> json) => FinderStats(
        findsDone: asInt(json['finds_done']),
        rewardedLosses: asInt(json['rewarded_losses']),
        ongoing: asInt(json['ongoing']),
        returnedDocuments: asInt(json['returned_documents']),
        earningsTotal: asDouble(json['earnings_total']),
        walletBalance: asDouble(json['wallet_balance']),
      );

  factory FinderStats.empty() => FinderStats(
        findsDone: 0,
        rewardedLosses: 0,
        ongoing: 0,
        returnedDocuments: 0,
        earningsTotal: 0,
        walletBalance: 0,
      );

  final int findsDone;
  final int rewardedLosses;
  final int ongoing;
  final int returnedDocuments;
  final double earningsTotal;
  final double walletBalance;
}

class FinanceReport {
  FinanceReport({
    required this.date,
    required this.dayRevenue,
    required this.monthRevenue,
    required this.yearRevenue,
    required this.totalRevenue,
    required this.escrowBalance,
    required this.rows,
  });

  factory FinanceReport.fromJson(Map<String, dynamic> json) => FinanceReport(
        date: asString(json['date']),
        dayRevenue: asDouble(json['day_revenue']),
        monthRevenue: asDouble(json['month_revenue']),
        yearRevenue: asDouble(json['year_revenue']),
        totalRevenue: asDouble(json['total_revenue']),
        escrowBalance: asDouble(json['escrow_balance']),
        rows: asMapList(json['rows'])
            .map((Map<String, dynamic> row) => FinanceRow.fromJson(row))
            .toList(),
      );

  factory FinanceReport.empty() => FinanceReport(
        date: '',
        dayRevenue: 0,
        monthRevenue: 0,
        yearRevenue: 0,
        totalRevenue: 0,
        escrowBalance: 0,
        rows: <FinanceRow>[],
      );

  final String date;
  final double dayRevenue;
  final double monthRevenue;
  final double yearRevenue;
  final double totalRevenue;
  final double escrowBalance;
  final List<FinanceRow> rows;
}

class FinanceRow {
  FinanceRow({
    required this.reference,
    required this.provider,
    required this.amount,
    required this.commission,
    required this.createdAt,
  });

  factory FinanceRow.fromJson(Map<String, dynamic> json) => FinanceRow(
        reference: asString(json['reference']),
        provider: asString(json['provider']),
        amount: asDouble(json['amount']),
        commission: asDouble(json['commission']),
        createdAt: asString(json['created_at']),
      );

  final String reference;
  final String provider;
  final double amount;
  final double commission;
  final String createdAt;
}

class AdminOverview {
  AdminOverview({
    required this.users,
    required this.blockedUsers,
    required this.documents,
    required this.losses,
    required this.finds,
    required this.matches,
    required this.returned,
    required this.escrowBalance,
    required this.yearRevenue,
    required this.monthRevenue,
    required this.aiEngine,
    required this.emailDelivery,
    required this.smsDelivery,
  });

  factory AdminOverview.fromJson(Map<String, dynamic> json) => AdminOverview(
        users: asInt(json['users']),
        blockedUsers: asInt(json['blocked_users']),
        documents: asInt(json['documents']),
        losses: asInt(json['losses']),
        finds: asInt(json['finds']),
        matches: asInt(json['matches']),
        returned: asInt(json['returned']),
        escrowBalance: asDouble(json['escrow_balance']),
        yearRevenue: asDouble(json['year_revenue']),
        monthRevenue: asDouble(json['month_revenue']),
        aiEngine: asString(json['ai_engine']),
        emailDelivery: asString(json['email_delivery']),
        smsDelivery: asString(json['sms_delivery']),
      );

  factory AdminOverview.empty() => AdminOverview(
        users: 0,
        blockedUsers: 0,
        documents: 0,
        losses: 0,
        finds: 0,
        matches: 0,
        returned: 0,
        escrowBalance: 0,
        yearRevenue: 0,
        monthRevenue: 0,
        aiEngine: '—',
        emailDelivery: '—',
        smsDelivery: '—',
      );

  final int users;
  final int blockedUsers;
  final int documents;
  final int losses;
  final int finds;
  final int matches;
  final int returned;
  final double escrowBalance;
  final double yearRevenue;
  final double monthRevenue;
  final String aiEngine;
  final String emailDelivery;
  final String smsDelivery;
}

class AdminStats {
  AdminStats({
    required this.losses,
    required this.finds,
    required this.returns,
    required this.pendingMatching,
    required this.counts,
  });

  factory AdminStats.fromJson(Map<String, dynamic> json) => AdminStats(
        losses: asMapList(json['losses']),
        finds: asMapList(json['finds']),
        returns: asMapList(json['returns']),
        pendingMatching: asMapList(json['pending_matching']),
        counts: asMap(json['counts']).map((String key, dynamic value) => MapEntry(key, asInt(value))),
      );

  factory AdminStats.empty() => AdminStats(
        losses: <Map<String, dynamic>>[],
        finds: <Map<String, dynamic>>[],
        returns: <Map<String, dynamic>>[],
        pendingMatching: <Map<String, dynamic>>[],
        counts: <String, int>{},
      );

  final List<Map<String, dynamic>> losses;
  final List<Map<String, dynamic>> finds;
  final List<Map<String, dynamic>> returns;
  final List<Map<String, dynamic>> pendingMatching;
  final Map<String, int> counts;
}
