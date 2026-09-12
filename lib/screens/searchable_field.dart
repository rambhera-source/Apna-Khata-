import 'package:flutter/material.dart';

class SearchableField extends StatelessWidget {
  final String label;
  final List<String> items;
  final TextEditingController controller;
  final ValueChanged<String> onSelected;
  final FocusNode? focusNode;
  final VoidCallback? onSubmitted;

  const SearchableField({
    super.key,
    required this.label,
    required this.items,
    required this.controller,
    required this.onSelected,
    this.focusNode,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return const Iterable<String>.empty();
        }
        return items.where((String item) {
          return item.toLowerCase().contains(textEditingValue.text.toLowerCase());
        });
      },
      onSelected: (String selection) {
        controller.text = selection;
        onSelected(selection);
        if (onSubmitted != null) onSubmitted!();
      },
      fieldViewBuilder: (context, textEditingController, fieldFocusNode, fieldOnSubmitted) {
        if (controller.text.isNotEmpty && textEditingController.text.isEmpty) {
          textEditingController.text = controller.text;
        }

        return TextField(
          controller: textEditingController,
          focusNode: focusNode ?? fieldFocusNode,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            suffixIcon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
          ),
          onChanged: (val) {
            controller.text = val;
          },
          onSubmitted: (_) {
            if (onSubmitted != null) onSubmitted!();
          },
        );
      },
    );
  }
}
