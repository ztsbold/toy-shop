import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../config/shop_config_view_model.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cfg = context.watch<ShopConfigViewModel>().config;

    Widget tile(IconData icon, String title, String subtitle,
            {VoidCallback? onTap}) =>
        ListTile(
          leading: CircleAvatar(
            backgroundColor: AppColors.sky,
            child: Icon(icon, color: AppColors.blue),
          ),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(subtitle),
          trailing: onTap != null ? const Icon(Icons.chevron_right) : null,
          onTap: onTap,
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Бусад')),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: BrandHeader(),
          ),
          if (cfg.shopPhone.isNotEmpty)
            tile(Icons.phone_outlined, 'Холбогдох утас', cfg.shopPhone,
                onTap: () => launchUrl(Uri(scheme: 'tel', path: cfg.shopPhone))),
          if (cfg.workHours.isNotEmpty)
            tile(Icons.schedule_outlined, 'Ажлын цаг', cfg.workHours),
          if (cfg.shopAddress.isNotEmpty)
            tile(Icons.location_on_outlined, 'Хаяг', cfg.shopAddress),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 20, 16, 6),
            child: Text('Хүргэлтийн нөхцөл',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          ),
          for (final o in cfg.deliveryOptions)
            ListTile(
              leading: const Icon(Icons.local_shipping_outlined,
                  color: AppColors.blue),
              title: Text(o.name),
              subtitle: o.eta.isNotEmpty ? Text(o.eta) : null,
              trailing: Text(o.fee == 0 ? 'Үнэгүй' : formatMnt(o.fee),
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          if (cfg.freeDeliveryFrom > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                '${formatMnt(cfg.freeDeliveryFrom)}-с дээш захиалгад стандарт хүргэлт үнэгүй.',
                style: const TextStyle(color: AppColors.muted),
              ),
            ),
          const SizedBox(height: 24),
          const Center(
            child: Text('Хувилбар 1.1.0',
                style: TextStyle(color: AppColors.muted, fontSize: 12)),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
