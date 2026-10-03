import 'package:flutter/material.dart';

enum BuildSlotType {
  cpu,
  motherboard,
  ram,
  gpu,
  psu,
  storage,
  pcCase,
  cooler;

  String get name => toString().split('.').last;
}

class BuildSlotInfo {
  final BuildSlotType type;
  final String title;
  final String description;
  final IconData icon;
  final int? categoryId; // Corresponds to database CategoryId
  final bool isRequired;

  const BuildSlotInfo({
    required this.type,
    required this.title,
    required this.description,
    required this.icon,
    this.categoryId,
    this.isRequired = true,
  });

  static const List<BuildSlotInfo> allSlots = [
    BuildSlotInfo(
      type: BuildSlotType.cpu,
      title: 'Processor (CPU)',
      description: 'AMD Ryzen or Intel Core',
      icon: Icons.memory,
      categoryId: 1, // CPU Category in DB
      isRequired: true,
    ),
    BuildSlotInfo(
      type: BuildSlotType.motherboard,
      title: 'Motherboard',
      description: 'Socket AM5 or LGA1700',
      icon: Icons.developer_board,
      categoryId: 3, // Motherboard Category in DB
      isRequired: true,
    ),
    BuildSlotInfo(
      type: BuildSlotType.ram,
      title: 'Memory (RAM)',
      description: 'DDR4 or DDR5 Kits',
      icon: Icons.straighten,
      categoryId: 4, // RAM Category in DB
      isRequired: true,
    ),
    BuildSlotInfo(
      type: BuildSlotType.gpu,
      title: 'Graphics Card (GPU)',
      description: 'NVIDIA RTX or AMD Radeon',
      icon: Icons.videogame_asset,
      categoryId: 2, // GPU Category in DB
      isRequired: true,
    ),
    BuildSlotInfo(
      type: BuildSlotType.psu,
      title: 'Power Supply (PSU)',
      description: '80+ Gold/Bronze wattage supply',
      icon: Icons.power,
      categoryId: 5, // PSU Category in DB
      isRequired: true,
    ),
    BuildSlotInfo(
      type: BuildSlotType.storage,
      title: 'Storage (NVMe / SSD)',
      description: 'Fast M.2 NVMe or SATA SSD',
      icon: Icons.storage,
      categoryId: null, // Any / Future Category
      isRequired: false,
    ),
    BuildSlotInfo(
      type: BuildSlotType.pcCase,
      title: 'Case / Chassis',
      description: 'ATX or Micro-ATX chassis',
      icon: Icons.desktop_windows_outlined,
      categoryId: null,
      isRequired: false,
    ),
    BuildSlotInfo(
      type: BuildSlotType.cooler,
      title: 'CPU Cooler',
      description: 'Air or Liquid AIO Cooler',
      icon: Icons.ac_unit,
      categoryId: null,
      isRequired: false,
    ),
  ];
}
