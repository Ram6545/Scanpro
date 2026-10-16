import 'package:flutter/material.dart';

/// Represents a category or folder for organizing [ScannedDocument] items.
class DocumentFolder {
  const DocumentFolder({
    required this.id,
    required this.name,
    required this.iconKey,
    required this.colorValue,
    required this.createdAt,
    this.isDefault = false,
  });

  final String id;
  final String name;

  /// Semantic key mapped to a constant [IconData] so Flutter icon tree-shaking
  /// remains 100% compatible with release APK/AAB builds.
  final String iconKey;

  final int colorValue;
  final DateTime createdAt;
  final bool isDefault;

  Color get color => Color(colorValue);

  /// Resolves [iconKey] to a compile-time constant [IconData].
  IconData get icon => iconFromKey(iconKey);

  static const Map<String, IconData> availableIcons = {
    'receipts': Icons.receipt_long_rounded,
    'id_cards': Icons.badge_rounded,
    'contracts': Icons.gavel_rounded,
    'invoices': Icons.request_quote_rounded,
    'notes': Icons.sticky_note_2_rounded,
    'work': Icons.business_center_rounded,
    'medical': Icons.medical_information_rounded,
    'education': Icons.school_rounded,
    'folder': Icons.folder_rounded,
  };

  static IconData iconFromKey(String key) {
    return availableIcons[key] ?? Icons.folder_rounded;
  }

  DocumentFolder copyWith({
    String? id,
    String? name,
    String? iconKey,
    int? colorValue,
    DateTime? createdAt,
    bool? isDefault,
  }) {
    return DocumentFolder(
      id: id ?? this.id,
      name: name ?? this.name,
      iconKey: iconKey ?? this.iconKey,
      colorValue: colorValue ?? this.colorValue,
      createdAt: createdAt ?? this.createdAt,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'icon_key': iconKey,
      'color_value': colorValue,
      'created_at': createdAt.toIso8601String(),
      'is_default': isDefault ? 1 : 0,
    };
  }

  factory DocumentFolder.fromMap(Map<String, dynamic> map) {
    return DocumentFolder(
      id: map['id'] as String,
      name: map['name'] as String,
      iconKey: map['icon_key'] as String? ?? 'folder',
      colorValue: map['color_value'] as int,
      createdAt: DateTime.parse(map['created_at'] as String),
      isDefault: (map['is_default'] as int? ?? 0) == 1,
    );
  }

  /// Pre-configured default categories seeded into ScanPro.
  static List<DocumentFolder> defaultFolders([DateTime? timestamp]) {
    final now = timestamp ?? DateTime.utc(2026, 1, 1);
    return [
      DocumentFolder(
        id: 'folder_receipts',
        name: 'Receipts',
        iconKey: 'receipts',
        colorValue: 0xFF00897B,
        createdAt: now,
        isDefault: true,
      ),
      DocumentFolder(
        id: 'folder_id_cards',
        name: 'ID Cards',
        iconKey: 'id_cards',
        colorValue: 0xFF1565C0,
        createdAt: now,
        isDefault: true,
      ),
      DocumentFolder(
        id: 'folder_contracts',
        name: 'Contracts',
        iconKey: 'contracts',
        colorValue: 0xFF6A1B9A,
        createdAt: now,
        isDefault: true,
      ),
      DocumentFolder(
        id: 'folder_invoices',
        name: 'Invoices',
        iconKey: 'invoices',
        colorValue: 0xFFEF6C00,
        createdAt: now,
        isDefault: true,
      ),
      DocumentFolder(
        id: 'folder_notes',
        name: 'Notes',
        iconKey: 'notes',
        colorValue: 0xFF2E7D32,
        createdAt: now,
        isDefault: true,
      ),
    ];
  }
}
