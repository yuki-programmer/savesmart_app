import 'package:flutter/material.dart';

/// カテゴリで使用できるアイコン候補
/// Material Iconsから家計管理に適したものを30個選定
class CategoryIcons {
  CategoryIcons._();

  /// アイコン名からIconDataを取得
  static IconData getIcon(String? iconName) {
    if (iconName == null) return Icons.category;
    return _iconMap[iconName] ?? Icons.category;
  }

  /// 全てのアイコン候補（選択UI用）
  static List<CategoryIconItem> get allIcons => _allIcons;

  /// アイコン名 -> IconData のマップ
  static const Map<String, IconData> _iconMap = {
    // 食事系
    'restaurant': Icons.restaurant,
    'local_cafe': Icons.local_cafe,
    'lunch_dining': Icons.lunch_dining,
    'local_grocery_store': Icons.local_grocery_store,
    'local_bar': Icons.local_bar,
    // 移動・交通
    'train': Icons.train,
    'directions_car': Icons.directions_car,
    'local_taxi': Icons.local_taxi,
    'flight': Icons.flight,
    // 生活・日用品
    'home': Icons.home,
    'shopping_bag': Icons.shopping_bag,
    'local_laundry_service': Icons.local_laundry_service,
    'pets': Icons.pets,
    // 美容・健康
    'content_cut': Icons.content_cut,
    'spa': Icons.spa,
    'medical_services': Icons.medical_services,
    'local_pharmacy': Icons.local_pharmacy,
    // 娯楽・趣味
    'sports_esports': Icons.sports_esports,
    'movie': Icons.movie,
    'music_note': Icons.music_note,
    'menu_book': Icons.menu_book,
    'fitness_center': Icons.fitness_center,
    // お金・サービス
    'subscriptions': Icons.subscriptions,
    'wifi': Icons.wifi,
    'bolt': Icons.bolt,
    'school': Icons.school,
    'card_giftcard': Icons.card_giftcard,
    // その他汎用
    'attach_money': Icons.attach_money,
    'category': Icons.category,
    'more_horiz': Icons.more_horiz,
  };

  /// 選択UI用のアイコンリスト（ラベル付き）
  static const List<CategoryIconItem> _allIcons = [
    // 食事系
    CategoryIconItem('restaurant', Icons.restaurant, '外食'),
    CategoryIconItem('local_cafe', Icons.local_cafe, 'カフェ'),
    CategoryIconItem('lunch_dining', Icons.lunch_dining, 'ランチ'),
    CategoryIconItem('local_grocery_store', Icons.local_grocery_store, '食料品'),
    CategoryIconItem('local_bar', Icons.local_bar, '飲み会'),
    // 移動・交通
    CategoryIconItem('train', Icons.train, '電車'),
    CategoryIconItem('directions_car', Icons.directions_car, '車'),
    CategoryIconItem('local_taxi', Icons.local_taxi, 'タクシー'),
    CategoryIconItem('flight', Icons.flight, '旅行'),
    // 生活・日用品
    CategoryIconItem('home', Icons.home, '住居'),
    CategoryIconItem('shopping_bag', Icons.shopping_bag, '買い物'),
    CategoryIconItem('local_laundry_service', Icons.local_laundry_service, 'クリーニング'),
    CategoryIconItem('pets', Icons.pets, 'ペット'),
    // 美容・健康
    CategoryIconItem('content_cut', Icons.content_cut, '美容室'),
    CategoryIconItem('spa', Icons.spa, 'エステ'),
    CategoryIconItem('medical_services', Icons.medical_services, '医療'),
    CategoryIconItem('local_pharmacy', Icons.local_pharmacy, '薬局'),
    // 娯楽・趣味
    CategoryIconItem('sports_esports', Icons.sports_esports, 'ゲーム'),
    CategoryIconItem('movie', Icons.movie, '映画'),
    CategoryIconItem('music_note', Icons.music_note, '音楽'),
    CategoryIconItem('menu_book', Icons.menu_book, '本'),
    CategoryIconItem('fitness_center', Icons.fitness_center, 'ジム'),
    // お金・サービス
    CategoryIconItem('subscriptions', Icons.subscriptions, 'サブスク'),
    CategoryIconItem('wifi', Icons.wifi, '通信'),
    CategoryIconItem('bolt', Icons.bolt, '光熱費'),
    CategoryIconItem('school', Icons.school, '教育'),
    CategoryIconItem('card_giftcard', Icons.card_giftcard, 'プレゼント'),
    // その他汎用
    CategoryIconItem('attach_money', Icons.attach_money, 'お金'),
    CategoryIconItem('category', Icons.category, 'その他'),
    CategoryIconItem('more_horiz', Icons.more_horiz, '未分類'),
  ];
}

/// アイコン候補アイテム
class CategoryIconItem {
  final String name;
  final IconData icon;
  final String label;

  const CategoryIconItem(this.name, this.icon, this.label);
}
