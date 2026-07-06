import 'package:flutter/material.dart';
import '../../models/reflection.dart';
import '../../services/translation_service.dart';

class ChangePhoneScreen extends StatelessWidget {
  const ChangePhoneScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(TranslationService.tr('bind_phone'), style: TextStyle(fontWeight: FontWeight.bold)),
        surfaceTintColor: Colors.transparent,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: ZoosyTheme.primary.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.phone_android, color: ZoosyTheme.primary, size: 36),
              ),
              const SizedBox(height: 24),
              Text(
                TranslationService.tr('phone_bind_title'),
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: ZoosyTheme.textDarkOf(context)),
              ),
              const SizedBox(height: 12),
              Text(
                TranslationService.tr('phone_bind_coming_soon'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: ZoosyTheme.textMutedOf(context), height: 1.6),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: ZoosyTheme.primary.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: ZoosyTheme.primary.withOpacity(0.1)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 18, color: ZoosyTheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        TranslationService.tr('phone_bind_desc'),
                        style: TextStyle(fontSize: 12, color: ZoosyTheme.textMutedOf(context)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
