import 'toy.dart';

class CartItem {
  CartItem({required this.toy, this.qty = 1});

  final Toy toy;
  int qty;

  int get subtotal => toy.price * qty;

  Map<String, dynamic> toOrderJson() => {'toyId': toy.id, 'qty': qty};
}
