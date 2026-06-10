import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DurationPicker extends StatelessWidget {
  final GlobalKey textFieldHrsKey = GlobalKey();
  final GlobalKey textFieldMinsKey = GlobalKey();
  final TextEditingController hrController;
  final TextEditingController minController;
  final ValueChanged<String> onHrChange;
  final ValueChanged<String> onMinChange;
  final ValueChanged<int> onHrsDropdownChange;
  final ValueChanged<int> onMinsDropdownChange;

  DurationPicker({
    required this.hrController,
    required this.minController,
    required this.onHrChange,
    required this.onMinChange,
    required this.onHrsDropdownChange,
    required this.onMinsDropdownChange,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: hrController,
            key: textFieldHrsKey,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(1),
            ],
            decoration: InputDecoration(
              labelText: 'Hours',
              suffixIcon: GestureDetector(
                onTap: () {
                  showHoursDropdownMenu(context, onHrsDropdownChange);
                },
                child: Icon(Icons.arrow_drop_down),
              ),
              border: OutlineInputBorder(),
            ),
            onChanged: onHrChange,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: minController,
            key: textFieldMinsKey,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(2),
            ],
            decoration: InputDecoration(
              labelText: 'Minutes',
              suffixIcon: GestureDetector(
                onTap: () {
                  showMinuteDropdownMenu(context, onMinsDropdownChange);
                },
                child: Icon(Icons.arrow_drop_down),
              ),
              border: OutlineInputBorder(),
            ),
            onChanged: onMinChange,
          ),
        ),
      ],
    );
  }

  void showHoursDropdownMenu(
    BuildContext context,
    ValueChanged<int> onHrsChange,
  ) async {
    final List<int> itemsHrs = List.generate(10, (i) => i);
    final RenderBox textFieldRenderBox =
        textFieldHrsKey.currentContext!.findRenderObject() as RenderBox;
    final Offset textFieldPosition = textFieldRenderBox.localToGlobal(
      Offset.zero,
    );
    final Size textFieldSize = textFieldRenderBox.size;

    final selectedItem = await showMenu<int>(
      context: context,
      position: RelativeRect.fromLTRB(
        textFieldPosition.dx,
        textFieldPosition.dy + textFieldSize.height, // Just below TextField
        textFieldPosition.dx + textFieldSize.width,
        textFieldPosition.dy,
      ),
      items: itemsHrs.map((item) {
        return PopupMenuItem<int>(value: item, child: Text(item.toString()));
      }).toList(),
    );

    if (selectedItem != null) {
      onHrsChange(selectedItem);
    }
  }

  void showMinuteDropdownMenu(
    BuildContext context,
    ValueChanged<int> onMinChanges,
  ) async {
    final List<int> itemsMinutes = List.generate(12, (i) => i * 5);

    final RenderBox textFieldRenderBox =
        textFieldMinsKey.currentContext!.findRenderObject() as RenderBox;
    final Offset textFieldPosition = textFieldRenderBox.localToGlobal(
      Offset.zero,
    );
    final Size textFieldSize = textFieldRenderBox.size;
    final selectedItem = await showMenu<int>(
      context: context,
      position: RelativeRect.fromLTRB(
        textFieldPosition.dx,
        textFieldPosition.dy + textFieldSize.height, // Just below TextField
        textFieldPosition.dx + textFieldSize.width,
        textFieldPosition.dy,
      ),
      items: itemsMinutes.map((item) {
        return PopupMenuItem<int>(
          value: item,
          child: Text(item.toString().padLeft(2, '0')),
        );
      }).toList(),
    );

    if (selectedItem != null) {
      onMinChanges(selectedItem);
    }
  }
}
