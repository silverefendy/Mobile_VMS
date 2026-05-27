class MenuItem {
  const MenuItem({
    required this.id,
    required this.label,
    required this.route,
    required this.iconKey,
    required this.order,
    required this.permissions,
    this.group = 'Operations',
    this.featureFlag,
  });

  final String id;
  final String label;
  final String route;
  final String iconKey;
  final int order;
  final List<String> permissions;
  final String group;
  final String? featureFlag;
}

class DashboardCard {
  const DashboardCard({
    required this.id,
    required this.title,
    required this.value,
    required this.iconKey,
    required this.order,
    this.route,
    this.featureFlag,
  });

  final String id;
  final String title;
  final String value;
  final String iconKey;
  final int order;
  final String? route;
  final String? featureFlag;
}
