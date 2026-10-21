import 'package:flutter/material.dart';
import 'package:haoka_app/models/order.dart';

IconData bizIcon(BizType t) => switch (t) {
  BizType.haoka => Icons.sim_card_outlined,
  BizType.contractPhone => Icons.phonelink_setup_outlined,
  BizType.broadbandNaked => Icons.router_outlined,
  BizType.broadbandNewCard => Icons.router_outlined,
  BizType.broadbandNoCard => Icons.wifi_tethering_outlined,
  BizType.wifi => Icons.wifi_outlined,
  BizType.cpe => Icons.router_rounded,
  BizType.stock => Icons.layers_outlined,
};
