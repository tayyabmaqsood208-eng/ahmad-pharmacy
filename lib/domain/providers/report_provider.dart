import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/dashboard_stats.dart';
import '../../data/repositories/report_repository.dart';

final reportRepositoryProvider = Provider((ref) => ReportRepository());

final dashboardStatsProvider = FutureProvider<DashboardStats>((ref) async {
  final repo = ref.watch(reportRepositoryProvider);
  return repo.getDashboardStats();
});

final salesTrendProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(reportRepositoryProvider);
  return repo.getSalesTrendData(days: 7);
});

final profitAndLossProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final repo = ref.watch(reportRepositoryProvider);
  return repo.getProfitAndLossReport();
});

final topSellingMedicinesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(reportRepositoryProvider);
  return repo.getTopSellingMedicines(limit: 5);
});

final stockValuationProvider = FutureProvider<Map<String, double>>((ref) async {
  final repo = ref.watch(reportRepositoryProvider);
  return repo.getStockValuation();
});
