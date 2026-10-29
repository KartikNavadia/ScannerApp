import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'utils/app_colors.dart';
import 'utils/app_text_styles.dart';
import 'providers/barcode_scan_provider.dart';

class CapturedImagesPage extends StatelessWidget {
  const CapturedImagesPage({
    super.key,
    required this.imagePaths,
    this.scanned = const {},
    this.plainChecked = const {},
  });

  final List<String> imagePaths;

  /// Codes already found while capturing, and the images that already had a
  /// quick pass.
  final Map<String, List<Barcode>> scanned;
  final Set<String> plainChecked;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => BarcodeScanProvider(
        imagePaths,
        scanned: scanned,
        plainChecked: plainChecked,
      ),
      child: const _GalleryView(),
    );
  }
}

class _GalleryView extends StatelessWidget {
  const _GalleryView();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BarcodeScanProvider>();
    final paths = provider.visiblePaths;
    final showCodes = provider.filter == GalleryFilter.qr;

    return Scaffold(
      appBar: const _GalleryAppBar(),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _FilterBar(),
            if (showCodes) const _CodesSummaryRow() else const _StatsRow(),
            if (!provider.isDone) const _ScanProgress(),
            Expanded(
              child: paths.isEmpty
                  ? const _EmptyState()
                  : showCodes
                  ? const _CodesList()
                  : GridView.builder(
                      padding: EdgeInsets.only(
                        bottom: 24 + MediaQuery.paddingOf(context).bottom,
                      ),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 4 / 5,
                          ),
                      itemCount: paths.length,
                      itemBuilder: (context, index) =>
                          _GalleryTile(path: paths[index]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GalleryAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _GalleryAppBar();

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final total = context.select((BarcodeScanProvider p) => p.totalCount);
    return AppBar(
      toolbarHeight: 64,
      foregroundColor: AppColors.textPrimary,
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      shadowColor: Colors.black.withValues(alpha: 0.04),
      titleSpacing: 0,
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.qr_code_scanner,
              size: 22,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 8),
          const Text('Gallery', style: AppTextStyles.headlineSm),
        ],
      ),
      actions: [
        IconButton(
          onPressed: total == 0 ? null : () => _confirmClear(context),
          tooltip: 'Clear all',
          color: AppColors.textSecondary,
          iconSize: 22,
          constraints: const BoxConstraints.tightFor(width: 44, height: 44),
          icon: const Icon(Icons.delete_sweep_outlined),
        ),
        const SizedBox(width: 12),
      ],
      bottom: PreferredSize(
        preferredSize: Size.zero,
        child: Container(
          height: 1,
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BarcodeScanProvider>();
    final filter = provider.filter;
    final qrCount = provider.codeImagePaths.length;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          _FilterPill(
            label: 'All',
            count: provider.totalCount,
            selected: filter == GalleryFilter.all,
            onTap: () => provider.setFilter(GalleryFilter.all),
          ),
          const SizedBox(width: 4),
          _FilterPill(
            label: 'QR Detected',
            icon: Icons.qr_code_scanner,
            count: qrCount > 0 ? qrCount : null,
            inactiveColor: AppColors.primary,
            selected: filter == GalleryFilter.qr,
            onTap: () => provider.setFilter(GalleryFilter.qr),
          ),
          const SizedBox(width: 4),
          _FilterPill(
            label: 'No QR',
            selected: filter == GalleryFilter.noQr,
            onTap: () => provider.setFilter(GalleryFilter.noQr),
          ),
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.count,
    this.inactiveColor = AppColors.textSecondary,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final int? count;
  final Color inactiveColor;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? AppColors.onPrimary : inactiveColor;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(999),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 15, color: foreground),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: AppTextStyles.labelMd.copyWith(color: foreground),
              ),
              if (count != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.white.withValues(alpha: 0.2)
                        : AppColors.primaryLight.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$count',
                    style: AppTextStyles.labelSm.copyWith(color: foreground),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BarcodeScanProvider>();
    final total = provider.totalCount;
    final date = total == 0
        ? DateTime.now()
        : provider.capturedAt(provider.imagePaths.first);

    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 8, 2, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(_dayLabel(date), style: AppTextStyles.headlineSm),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Text(
              '$total ${total == 1 ? 'capture' : 'captures'}',
              style: AppTextStyles.bodySm.copyWith(letterSpacing: 0.3),
            ),
          ),
          const Spacer(),
          const Icon(
            Icons.calendar_today_outlined,
            size: 16,
            color: AppColors.primary,
          ),
          const SizedBox(width: 4),
          Text(
            _shortDate(date),
            style: AppTextStyles.labelSm.copyWith(color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

class _ScanProgress extends StatelessWidget {
  const _ScanProgress();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BarcodeScanProvider>();
    final scanned = provider.scannedCount;
    final total = provider.totalCount;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: total == 0 ? null : scanned / total,
              minHeight: 4,
              color: AppColors.primary,
              backgroundColor: AppColors.surfaceContainer,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Scanning for QR/barcodes · $scanned / $total',
            style: AppTextStyles.bodySm,
          ),
        ],
      ),
    );
  }
}

class _GalleryTile extends StatelessWidget {
  const _GalleryTile({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BarcodeScanProvider>();
    final hasCodes = provider.hasCodes(path);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: AppColors.surfaceContainer),
            Image.file(File(path), fit: BoxFit.cover, cacheWidth: 400),
            if (hasCodes)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.85),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.qr_code_2,
                    size: 15,
                    color: AppColors.primary,
                  ),
                ),
              ),
            Positioned(
              left: 10,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _time(provider.capturedAt(path)),
                  style: AppTextStyles.labelSm,
                ),
              ),
            ),
            Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: () => _showImageDialog(
                  context,
                  path,
                  provider.resultsFor(path) ?? const [],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CodesSummaryRow extends StatelessWidget {
  const _CodesSummaryRow();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BarcodeScanProvider>();
    final codes = provider.detectedCodes;
    final count = codes.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 16),
      child: Row(
        children: [
          Flexible(
            child: Text(
              '$count ${count == 1 ? 'code' : 'codes'} found',
              style: AppTextStyles.headlineSm,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (!provider.isDone) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainer,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Live',
                style: AppTextStyles.labelSm.copyWith(color: AppColors.primary),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CodesList extends StatelessWidget {
  const _CodesList();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BarcodeScanProvider>();
    final codes = provider.detectedCodes;

    return ListView.separated(
      padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
      itemCount: codes.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        if (index == codes.length) {
          return _EndOfListNote(count: codes.length, isDone: provider.isDone);
        }
        final entry = codes[index];
        return _CodeCard(path: entry.path, barcode: entry.barcode);
      },
    );
  }
}

class _CodeCard extends StatelessWidget {
  const _CodeCard({required this.path, required this.barcode});

  final String path;
  final Barcode barcode;

  @override
  Widget build(BuildContext context) {
    final provider = context.read<BarcodeScanProvider>();
    final info = _CodeInfo.of(barcode);
    final capturedAt = provider.capturedAt(path);
    final when = _dayLabel(capturedAt) == 'Today'
        ? _time(capturedAt)
        : _dayLabel(capturedAt);

    return Container(
      height: 288,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.file(File(path), fit: BoxFit.cover, cacheWidth: 800),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Color(0x99000000), Colors.transparent],
                stops: [0, 0.5],
              ),
            ),
          ),
          Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: () => _showImageDialog(
                context,
                path,
                provider.resultsFor(path) ?? const [],
              ),
            ),
          ),
          // Top badges.
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(info.badgeIcon, size: 13, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(
                        info.badgeLabel,
                        style: AppTextStyles.labelSm.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    when,
                    style: AppTextStyles.bodySm.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Bottom action banner.
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 6,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      info.tileIcon,
                      size: 20,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          info.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.labelSm.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          info.value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              (info.isCode
                                      ? AppTextStyles.labelMd
                                      : AppTextStyles.bodyMd)
                                  .copyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w500,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: info.prominentAction
                        ? AppColors.primary
                        : AppColors.surfaceContainer,
                    borderRadius: BorderRadius.circular(8),
                    elevation: info.prominentAction ? 1 : 0,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => _copy(context, _codeText(barcode)),
                      child: Tooltip(
                        message: 'Copy',
                        child: SizedBox(
                          width: 36,
                          height: 36,
                          child: Icon(
                            Icons.content_copy,
                            size: 18,
                            color: info.prominentAction
                                ? AppColors.onPrimary
                                : AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EndOfListNote extends StatelessWidget {
  const _EndOfListNote({required this.count, required this.isDone});

  final int count;
  final bool isDone;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: AppColors.surfaceContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isDone ? Icons.done_all : Icons.hourglass_top,
              size: 20,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isDone
                ? count == 1
                      ? 'The only code has been indexed'
                      : 'All $count codes indexed'
                : 'Scanning remaining photos…',
            style: AppTextStyles.labelMd.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Scanned on-device',
            style: AppTextStyles.labelSm.copyWith(
              color: AppColors.primaryLight,
            ),
          ),
        ],
      ),
    );
  }
}

/// Display details for a detected code, based on its ML Kit value type.
class _CodeInfo {
  const _CodeInfo({
    required this.badgeIcon,
    required this.badgeLabel,
    required this.tileIcon,
    required this.subtitle,
    required this.value,
    this.isCode = false,
    this.prominentAction = true,
  });

  final IconData badgeIcon;
  final String badgeLabel;
  final IconData tileIcon;
  final String subtitle;
  final String value;

  /// Product/ISBN-style values read better in the label style.
  final bool isCode;

  /// Filled primary action button vs. the lighter variant.
  final bool prominentAction;

  factory _CodeInfo.of(Barcode barcode) {
    final raw = _codeText(barcode);
    final value = barcode.value;
    final isQr = barcode.format == BarcodeFormat.qrCode;

    switch (barcode.type) {
      case BarcodeType.url:
        final url = value is BarcodeUrl ? value.url ?? raw : raw;
        return _CodeInfo(
          badgeIcon: Icons.link,
          badgeLabel: 'Website',
          tileIcon: Icons.public,
          subtitle: value is BarcodeUrl && (value.title?.isNotEmpty ?? false)
              ? value.title!
              : 'URL',
          value: url.replaceFirst(RegExp(r'^https?://'), ''),
        );
      case BarcodeType.wifi:
        final wifi = value is BarcodeWifi ? value : null;
        return _CodeInfo(
          badgeIcon: Icons.wifi,
          badgeLabel: 'Network',
          tileIcon: Icons.wifi_tethering,
          subtitle: switch (wifi?.encryptionType) {
            2 => 'WPA Secured',
            3 => 'WEP Secured',
            1 => 'Open network',
            _ => 'Wi-Fi',
          },
          value: 'Wi-Fi: ${wifi?.ssid ?? raw}',
        );
      case BarcodeType.contactInfo:
        final contact = value is BarcodeContactInfo ? value : null;
        final name =
            contact?.formattedName ??
            [
              contact?.firstName,
              contact?.lastName,
            ].whereType<String>().join(' ');
        return _CodeInfo(
          badgeIcon: Icons.badge_outlined,
          badgeLabel: 'Contact',
          tileIcon: Icons.person_outline,
          subtitle: contact?.jobTitle?.isNotEmpty ?? false
              ? '${contact!.jobTitle} • vCard'
              : 'vCard',
          value: 'Contact: ${name.isEmpty ? raw : name}',
          prominentAction: false,
        );
      case BarcodeType.calendarEvent:
        final event = value is BarcodeCalenderEvent ? value : null;
        return _CodeInfo(
          badgeIcon: Icons.confirmation_number_outlined,
          badgeLabel: 'Event',
          tileIcon: Icons.calendar_month_outlined,
          subtitle: event?.location?.isNotEmpty ?? false
              ? event!.location!
              : 'Calendar event',
          value: 'Event: ${event?.summary ?? raw}',
        );
      case BarcodeType.email:
        final email = value is BarcodeEmail ? value : null;
        return _CodeInfo(
          badgeIcon: Icons.mail_outline,
          badgeLabel: 'Email',
          tileIcon: Icons.alternate_email,
          subtitle: email?.subject?.isNotEmpty ?? false
              ? email!.subject!
              : 'Email address',
          value: email?.address ?? raw,
        );
      case BarcodeType.phone:
        final phone = value is BarcodePhone ? value : null;
        return _CodeInfo(
          badgeIcon: Icons.call_outlined,
          badgeLabel: 'Phone',
          tileIcon: Icons.phone_outlined,
          subtitle: 'Phone number',
          value: phone?.number ?? raw,
        );
      case BarcodeType.sms:
        final sms = value is BarcodeSMS ? value : null;
        return _CodeInfo(
          badgeIcon: Icons.sms_outlined,
          badgeLabel: 'SMS',
          tileIcon: Icons.textsms_outlined,
          subtitle: sms?.phoneNumber ?? 'Message',
          value: sms?.message ?? raw,
        );
      case BarcodeType.geoCoordinates:
        final geo = value is BarcodeGeoPoint ? value : null;
        return _CodeInfo(
          badgeIcon: Icons.place_outlined,
          badgeLabel: 'Location',
          tileIcon: Icons.map_outlined,
          subtitle: 'Coordinates',
          value: geo == null ? raw : '${geo.latitude}, ${geo.longitude}',
        );
      case BarcodeType.product:
      case BarcodeType.isbn:
        final isIsbn = barcode.type == BarcodeType.isbn;
        return _CodeInfo(
          badgeIcon: Icons.inventory_2_outlined,
          badgeLabel: isIsbn ? 'ISBN' : 'Product',
          tileIcon: Icons.barcode_reader,
          subtitle: isIsbn ? 'Book number' : 'Product code',
          value: raw,
          isCode: true,
          prominentAction: false,
        );
      case BarcodeType.driverLicense:
        final id = value is BarcodeDriverLicense ? value : null;
        final name = [
          id?.firstName,
          id?.lastName,
        ].whereType<String>().join(' ');
        return _CodeInfo(
          badgeIcon: Icons.badge_outlined,
          badgeLabel: 'ID',
          tileIcon: Icons.credit_card,
          subtitle: 'Driver license',
          value: name.isEmpty ? raw : name,
          prominentAction: false,
        );
      case BarcodeType.text:
      case BarcodeType.unknown:
        return _CodeInfo(
          badgeIcon: Icons.notes,
          badgeLabel: 'Text',
          tileIcon: isQr ? Icons.qr_code_2 : Icons.barcode_reader,
          subtitle: isQr ? 'QR code' : 'Barcode • ${barcode.format.name}',
          value: raw,
          isCode: !isQr,
          prominentAction: false,
        );
    }
  }
}

String _codeText(Barcode barcode) {
  final text = barcode.rawValue ?? barcode.displayValue ?? '';
  return text.isEmpty ? '(no data)' : text;
}

void _copy(BuildContext context, String text, {String message = 'Copied'}) {
  Clipboard.setData(ClipboardData(text: text));
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BarcodeScanProvider>();
    final isFiltered = provider.filter != GalleryFilter.all;
    final isScanning = !provider.isDone;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 64),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: AppColors.surfaceContainer,
                shape: BoxShape.circle,
              ),
              child: isScanning
                  ? const Padding(
                      padding: EdgeInsets.all(18),
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.primary,
                      ),
                    )
                  : const Icon(
                      Icons.filter_vintage_outlined,
                      size: 28,
                      color: AppColors.primary,
                    ),
            ),
            const SizedBox(height: 12),
            Text(
              isScanning ? 'Scanning photos…' : 'No photos here',
              style: AppTextStyles.headlineSm,
            ),
            const SizedBox(height: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 200),
              child: Text(
                isScanning
                    ? 'Photos will appear here once they are checked.'
                    : isFiltered
                    ? 'Switch back to All captures to browse your full '
                          'collection.'
                    : 'Captured photos will show up here.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySm,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _confirmClear(BuildContext context) async {
  final provider = context.read<BarcodeScanProvider>();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      icon: const CircleAvatar(
        radius: 28,
        backgroundColor: AppColors.surfaceContainer,
        foregroundColor: AppColors.primary,
        child: Icon(Icons.delete_outline, size: 28),
      ),
      title: const Text('Clear all images?', style: AppTextStyles.headlineSm),
      content: Text(
        'All ${provider.totalCount} captured images will be deleted. '
        'This cannot be undone.',
        textAlign: TextAlign.center,
        style: AppTextStyles.bodyMd.copyWith(color: AppColors.textSecondary),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryDark,
                  side: const BorderSide(color: AppColors.primaryLight),
                  minimumSize: const Size.fromHeight(44),
                  shape: const StadiumBorder(),
                  textStyle: AppTextStyles.labelMd,
                ),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  minimumSize: const Size.fromHeight(44),
                  shape: const StadiumBorder(),
                  textStyle: AppTextStyles.labelMd.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text('Clear'),
              ),
            ),
          ],
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  await provider.clearAll();
  if (context.mounted) Navigator.of(context).pop();
}

/// Shows the image with its QR/barcode data (if any) and a close button.
void _showImageDialog(
  BuildContext context,
  String path,
  List<Barcode> barcodes,
) {
  if (barcodes.isNotEmpty) {
    _showDetectedDialog(context, path, barcodes);
    return;
  }
  showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: Stack(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Flexible(
                  flex: 3,
                  child: InteractiveViewer(
                    child: Image.file(File(path), fit: BoxFit.contain),
                  ),
                ),
                if (barcodes.isNotEmpty)
                  Flexible(
                    flex: 2,
                    child: ListView(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                      children: [
                        for (final code in barcodes)
                          _BarcodeTile(barcode: code),
                      ],
                    ),
                  ),
              ],
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton.filled(
                onPressed: () => Navigator.of(context).pop(),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.textPrimary.withValues(alpha: 0.6),
                  foregroundColor: Colors.white,
                ),
                tooltip: 'Close',
                icon: const Icon(Icons.close),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Dialog for an image with detected codes: status pill + close button, the
/// photo, then each code's text with copy and (for links) an Open Link button.
void _showDetectedDialog(
  BuildContext context,
  String path,
  List<Barcode> barcodes,
) {
  final isQr = barcodes.any((b) => b.format == BarcodeFormat.qrCode);
  showDialog<void>(
    context: context,
    barrierColor: const Color(0x66D2D9F4),
    builder: (context) => Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shadowColor: AppColors.primary.withValues(alpha: 0.3),
      elevation: 12,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      // Same height as the plain image dialog: a full-width 9:16 photo,
      // capped at 85% of the screen.
      child: SizedBox(
        height: math.min(
          MediaQuery.sizeOf(context).height * 0.85,
          (MediaQuery.sizeOf(context).width - 32) * 16 / 9,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isQr ? 'QR Code Detected' : 'Barcode Detected',
                          style: AppTextStyles.labelSm.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Material(
                    color: AppColors.surfaceContainer,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => Navigator.of(context).pop(),
                      child: const Tooltip(
                        message: 'Close',
                        child: SizedBox(
                          width: 36,
                          height: 36,
                          child: Icon(
                            Icons.close,
                            size: 20,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: ColoredBox(
                    color: AppColors.surfaceContainer,
                    child: InteractiveViewer(
                      child: Image.file(File(path), fit: BoxFit.contain),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                flex: 0,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.3,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: barcodes.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 16),
                    itemBuilder: (context, i) =>
                        _DetectedCode(barcode: barcodes[i]),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// One decoded code: its text with a copy button, and an Open Link button when
/// the text is a web link.
class _DetectedCode extends StatelessWidget {
  const _DetectedCode({required this.barcode});

  final Barcode barcode;

  @override
  Widget build(BuildContext context) {
    final value = _codeText(barcode);
    final uri = Uri.tryParse(barcode.rawValue ?? '');
    final isLink =
        uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                isLink ? Icons.link : Icons.notes,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.labelMd.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _copy(context, value),
                tooltip: 'Copy',
                visualDensity: VisualDensity.compact,
                icon: const Icon(
                  Icons.content_copy,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        if (isLink) ...[
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () => _open(context, uri),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              minimumSize: const Size.fromHeight(44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Open Link',
                  style: AppTextStyles.bodyMd.copyWith(
                    color: AppColors.onPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_outward, size: 18),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _open(BuildContext context, Uri uri) async {
    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Exception catch (e) {
      debugPrint('Could not open $uri: $e');
    }
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Could not open link')));
    }
  }
}

class _BarcodeTile extends StatelessWidget {
  const _BarcodeTile({required this.barcode});

  final Barcode barcode;

  @override
  Widget build(BuildContext context) {
    final isQr = barcode.format == BarcodeFormat.qrCode;
    final value = barcode.displayValue ?? barcode.rawValue ?? '';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        isQr ? Icons.qr_code_2 : Icons.barcode_reader,
        size: 32,
        color: AppColors.primary,
      ),
      title: SelectableText(
        value.isEmpty ? '(no data)' : value,
        style: AppTextStyles.bodyMd,
      ),
      subtitle: Text(
        '${isQr ? 'QR code' : 'Barcode'} • ${barcode.format.name}',
        style: AppTextStyles.bodySm,
      ),
      trailing: IconButton(
        icon: const Icon(Icons.copy, color: AppColors.primaryDark),
        tooltip: 'Copy',
        onPressed: () => _copy(context, value),
      ),
    );
  }
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// "Today", "Yesterday", or e.g. "Oct 24".
String _dayLabel(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(date.year, date.month, date.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  return _shortDate(date);
}

/// e.g. "Oct 24".
String _shortDate(DateTime date) => '${_months[date.month - 1]} ${date.day}';

/// e.g. "09:05 AM".
String _time(DateTime date) {
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  final period = date.hour < 12 ? 'AM' : 'PM';
  return '${hour.toString().padLeft(2, '0')}:$minute $period';
}
