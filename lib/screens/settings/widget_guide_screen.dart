import 'package:flutter/material.dart';
import '../../models/reflection.dart';
import '../../services/translation_service.dart';

class WidgetGuideScreen extends StatelessWidget {
  const WidgetGuideScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(TranslationService.tr('how_to_add_widget'), style: TextStyle(fontWeight: FontWeight.bold)),
        surfaceTintColor: Colors.transparent,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 顶部提示：不同机型存在差异
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: ZoosyTheme.primary.withOpacity(0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: ZoosyTheme.primary.withOpacity(0.15)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: ZoosyTheme.primary, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      TranslationService.tr('widget_diff_notice'),
                      style: TextStyle(fontSize: 12, color: ZoosyTheme.textMutedOf(context), height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // ===== 第一步 =====
            _buildStep(
              context,
              step: '1',
              title: TranslationService.tr('step_press_home'),
              desc: TranslationService.tr('step_select_plugin'),
            ),
            const SizedBox(height: 28),

            // ===== 第二步 =====
            _buildStep(
              context,
              step: '2',
              title: TranslationService.tr('step_scroll_down'),
              desc: TranslationService.tr('step_window_widgets'),
            ),
            const SizedBox(height: 28),

            // ===== 第三步 =====
            _buildStep(
              context,
              step: '3',
              title: TranslationService.tr('step_find_zoosy'),
              desc: TranslationService.tr('step_drag_to_home'),
            ),
            const SizedBox(height: 28),

            // 小提示
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ZoosyTheme.primary.withOpacity(0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ZoosyTheme.primary.withOpacity(0.15)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_outline, color: ZoosyTheme.primary, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(TranslationService.tr('widget_tip'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: ZoosyTheme.primary)),
                        const SizedBox(height: 6),
                        Text(
                          TranslationService.tr('widget_tip_content'),
                          style: TextStyle(fontSize: 12, color: ZoosyTheme.textMutedOf(context), height: 1.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(BuildContext context, {required String step, required String title, required String desc}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 步骤编号圆圈
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: ZoosyTheme.primary, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text(step, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ZoosyTheme.textDarkOf(context))),
              const SizedBox(height: 8),
              Text(desc, style: TextStyle(fontSize: 13, color: ZoosyTheme.textMutedOf(context), height: 1.6)),
            ],
          ),
        ),
      ],
    );
  }
}
