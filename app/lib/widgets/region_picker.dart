import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:haoka_app/data/china_regions.dart';
import 'package:haoka_app/widgets/app_surface.dart';

Future<RegionSelection?> showRegionPicker(
  BuildContext context, {
  RegionSelection? initial,
}) async {
  await ChinaRegions.ensureLoaded();
  if (!context.mounted) return null;
  return showModalBottomSheet<RegionSelection>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => _RegionPickerSheet(initial: initial),
  );
}

class _RegionPickerSheet extends StatefulWidget {
  const _RegionPickerSheet({this.initial});

  final RegionSelection? initial;

  @override
  State<_RegionPickerSheet> createState() => _RegionPickerSheetState();
}

class _RegionPickerSheetState extends State<_RegionPickerSheet> {
  static const _itemExtent = 40.0;

  late int _p;
  late int _c;
  late int _d;

  late FixedExtentScrollController _pCtrl;
  late FixedExtentScrollController _cCtrl;
  late FixedExtentScrollController _dCtrl;

  List<RegionNode> get _provinces => ChinaRegions.tree;
  List<RegionNode> get _cities {
    if (_provinces.isEmpty) return const [];
    return _provinces[_p].children;
  }

  List<RegionNode> get _districts {
    if (_cities.isEmpty) return const [];
    return _cities[_c].children;
  }

  @override
  void initState() {
    super.initState();
    _p = 0;
    _c = 0;
    _d = 0;
    final init = widget.initial;
    if (init != null && _provinces.isNotEmpty) {
      final pi = ChinaRegions.provinceIndexOf(init.province);
      _p = pi.clamp(0, _provinces.length - 1);
      final ci = _cities.indexWhere((e) => e.name == init.city);
      _c = ci < 0 ? 0 : ci;
      final di = _districts.indexWhere((e) => e.name == init.district);
      _d = di < 0 ? 0 : di;
    }
    _pCtrl = FixedExtentScrollController(initialItem: _p);
    _cCtrl = FixedExtentScrollController(initialItem: _c);
    _dCtrl = FixedExtentScrollController(initialItem: _d);
  }

  @override
  void dispose() {
    _pCtrl.dispose();
    _cCtrl.dispose();
    _dCtrl.dispose();
    super.dispose();
  }

  void _onProvince(int index) {
    if (index == _p) return;
    final oldC = _cCtrl;
    final oldD = _dCtrl;
    setState(() {
      _p = index;
      _c = 0;
      _d = 0;
      _cCtrl = FixedExtentScrollController(initialItem: 0);
      _dCtrl = FixedExtentScrollController(initialItem: 0);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      oldC.dispose();
      oldD.dispose();
    });
  }

  void _onCity(int index) {
    if (index == _c) return;
    final oldD = _dCtrl;
    setState(() {
      _c = index;
      _d = 0;
      _dCtrl = FixedExtentScrollController(initialItem: 0);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      oldD.dispose();
    });
  }

  RegionSelection? get _value {
    if (_provinces.isEmpty || _cities.isEmpty || _districts.isEmpty)
      return null;
    return RegionSelection(
      province: _provinces[_p].name,
      city: _cities[_c].name,
      district: _districts[_d].name,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    if (_provinces.isEmpty) {
      return const SizedBox(
        height: 220,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
      );
    }

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 52,
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      '取消',
                      style: TextStyle(color: AppStyle.subtitle),
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      '选择省 / 市 / 区',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppStyle.title,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      final v = _value;
                      if (v != null) Navigator.pop(context, v);
                    },
                    child: const Text(
                      '确定',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppStyle.divider),
            SizedBox(
              height: 216,
              child: Row(
                children: [
                  _col(
                    _provinces.map((e) => e.name).toList(),
                    _pCtrl,
                    _onProvince,
                  ),
                  _col(
                    _cities.map((e) => e.name).toList(),
                    _cCtrl,
                    _onCity,
                    key: ValueKey('c-$_p'),
                  ),
                  _col(
                    _districts.map((e) => e.name).toList(),
                    _dCtrl,
                    (i) => setState(() => _d = i),
                    key: ValueKey('d-$_p-$_c'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _col(
    List<String> items,
    FixedExtentScrollController controller,
    ValueChanged<int> onChanged, {
    Key? key,
  }) {
    return Expanded(
      child: CupertinoPicker(
        key: key,
        scrollController: controller,
        itemExtent: _itemExtent,
        magnification: 1.08,
        squeeze: 1.15,
        useMagnifier: true,
        onSelectedItemChanged: onChanged,
        children: [
          for (final name in items)
            Center(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15, color: AppStyle.title),
              ),
            ),
        ],
      ),
    );
  }
}
