class DashboardStats {
  final double todaySales;
  final int todayOrders;
  final int lowStockCount;
  final int expiringCount;
  final double totalRevenue;

  DashboardStats({
    required this.todaySales,
    required this.todayOrders,
    required this.lowStockCount,
    required this.expiringCount,
    required this.totalRevenue,
  });
}
