import 'package:flutter/material.dart';
import 'package:haoka_app/models/order.dart';
import 'package:haoka_app/pages/catalog_product_list_page.dart';

class HaokaProductListPage extends StatelessWidget {
  const HaokaProductListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const CatalogProductListPage(bizType: BizType.haoka);
  }
}
