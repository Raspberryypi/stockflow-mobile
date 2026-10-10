class AlertStats {
  const AlertStats({
    this.lowStockCount = 0,
    this.outOfStockCount = 0,
    this.lowStockProducts = const [],
  });

  final int lowStockCount;
  final int outOfStockCount;
  final List<Map<String, dynamic>> lowStockProducts;

  int get total => lowStockCount + outOfStockCount;

  factory AlertStats.fromDashboard(Map<String, dynamic> data) => AlertStats(
        lowStockCount: (data['lowStockCount'] as num?)?.toInt() ?? 0,
        outOfStockCount: (data['outOfStockCount'] as num?)?.toInt() ?? 0,
        lowStockProducts: ((data['lowStockProducts'] as List?) ?? const [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(),
      );
}
