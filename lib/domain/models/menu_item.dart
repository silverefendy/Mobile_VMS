class MenuItem {
  const MenuItem({required this.id, required this.label, required this.route, required this.iconKey, required this.order, required this.permissions});

  final String id;
  final String label;
  final String route;
  final String iconKey;
  final int order;
  final List<String> permissions;
}
