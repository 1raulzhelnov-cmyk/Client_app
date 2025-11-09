import 'package:eazy_client_mvp/features/venue/widgets/menu_catalog.dart';
import 'package:eazy_client_mvp/models/product_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('filterMenuProducts', () {
    final products = [
      _product(
        id: 'p1',
        name: 'Маргарита',
        description: 'Классическая пицца с сыром',
        category: 'Пицца',
      ),
      _product(
        id: 'p2',
        name: 'Том Ям',
        description: 'Суп с креветками и кокосовым молоком',
        category: 'Супы',
      ),
      _product(
        id: 'p3',
        name: 'Чизкейк Нью-Йорк',
        description: 'Нежный десерт с сыром',
        category: 'Десерты',
      ),
    ];

    test('возвращает исходный список при пустом запросе', () {
      final result = filterMenuProducts(products, '');
      expect(result, equals(products));
    });

    test('фильтрует по названию и описанию', () {
      final nameMatch = filterMenuProducts(products, 'маргар');
      final descriptionMatch = filterMenuProducts(products, 'креветками');
      expect(nameMatch, hasLength(1));
      expect(nameMatch.first.id, equals('p1'));
      expect(descriptionMatch, hasLength(1));
      expect(descriptionMatch.first.id, equals('p2'));
    });

    test('фильтрует по категории', () {
      final result = filterMenuProducts(products, 'десер');
      expect(result, hasLength(1));
      expect(result.first.id, equals('p3'));
    });
  });

  group('buildMenuSections', () {
    test('группирует товары по категориям и сортирует', () {
      final products = [
        _product(
          id: 'p1',
          name: 'Маргарита',
          category: 'Пицца',
        ),
        _product(
          id: 'p2',
          name: 'Пепперони',
          category: 'Пицца',
        ),
        _product(
          id: 'p3',
          name: 'Том Ям',
          category: 'Супы',
        ),
        _product(
          id: 'p4',
          name: 'Салат Цезарь',
        ),
      ];

      final sections = buildMenuSections(products, 'Прочее');

      expect(sections, hasLength(3));
      expect(sections.first.title, equals('Пицца'));
      expect(sections.first.products.first.name, equals('Маргарита'));
      expect(sections[1].title, equals('Прочее'));
      expect(sections[1].products.single.id, equals('p4'));
      expect(sections.last.title, equals('Супы'));
    });
  });
}

ProductModel _product({
  required String id,
  required String name,
  String description = 'Описание',
  String? category,
}) {
  return ProductModel(
    id: id,
    venueId: 'venue',
    name: name,
    description: description,
    price: 100,
    imageUrl: 'https://example.com/$id.jpg',
    available: true,
    category: category,
  );
}
