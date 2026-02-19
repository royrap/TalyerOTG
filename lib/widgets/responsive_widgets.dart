import 'package:flutter/material.dart';
import '../utils/responsive_helper.dart';

class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final Decoration? decoration;
  final double? width;
  final double? height;
  
  const ResponsiveContainer({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.decoration,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: padding ?? ResponsiveHelper.responsivePadding(context),
      margin: margin ?? EdgeInsets.all(ResponsiveHelper.spacing(context, base: 8)),
      decoration: decoration,
      child: child,
    );
  }
}

class ResponsiveText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final double baseFontSize;
  final FontWeight? fontWeight;
  final Color? color;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  
  const ResponsiveText(
    this.text, {
    super.key,
    this.style,
    this.baseFontSize = 16.0,
    this.fontWeight,
    this.color,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: (style ?? const TextStyle()).copyWith(
        fontSize: ResponsiveHelper.responsiveFontSize(context, baseFontSize: baseFontSize),
        fontWeight: fontWeight,
        color: color,
      ),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

class ResponsiveButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final IconData? icon;
  final bool isOutlined;
  final double? width;
  
  const ResponsiveButton({
    super.key,
    required this.text,
    this.onPressed,
    this.backgroundColor,
    this.foregroundColor,
    this.icon,
    this.isOutlined = false,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final double buttonHeight = ResponsiveHelper.responsiveValue(
      context,
      mobile: 48.0,
      tablet: 56.0,
      desktop: 64.0,
    );
    
    final double fontSize = ResponsiveHelper.responsiveFontSize(context, baseFontSize: 16);
    final EdgeInsets padding = EdgeInsets.symmetric(
      horizontal: ResponsiveHelper.spacing(context),
      vertical: ResponsiveHelper.spacing(context, base: 12),
    );

    Widget button;
    
    if (isOutlined) {
      button = OutlinedButton.icon(
        onPressed: onPressed,
        icon: icon != null ? Icon(icon, size: fontSize + 2) : const SizedBox.shrink(),
        label: ResponsiveText(
          text,
          baseFontSize: 16,
          fontWeight: FontWeight.bold,
          color: foregroundColor,
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: foregroundColor,
          side: BorderSide(color: backgroundColor ?? Theme.of(context).primaryColor),
          padding: padding,
          minimumSize: Size(width ?? double.infinity, buttonHeight),
        ),
      );
    } else {
      button = ElevatedButton.icon(
        onPressed: onPressed,
        icon: icon != null ? Icon(icon, size: fontSize + 2) : const SizedBox.shrink(),
        label: ResponsiveText(
          text,
          baseFontSize: 16,
          fontWeight: FontWeight.bold,
          color: foregroundColor ?? Colors.white,
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor ?? Theme.of(context).primaryColor,
          foregroundColor: foregroundColor ?? Colors.white,
          padding: padding,
          minimumSize: Size(width ?? double.infinity, buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ResponsiveHelper.spacing(context, base: 8)),
          ),
        ),
      );
    }
    
    return SizedBox(
      width: width,
      child: button,
    );
  }
}

class ResponsiveCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final VoidCallback? onTap;
  
  const ResponsiveCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        margin: margin ?? EdgeInsets.all(ResponsiveHelper.spacing(context, base: 8)),
        elevation: ResponsiveHelper.responsiveValue(context, mobile: 2, tablet: 4, desktop: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ResponsiveHelper.spacing(context, base: 12)),
        ),
        child: Padding(
          padding: padding ?? ResponsiveHelper.responsivePadding(context),
          child: child,
        ),
      ),
    );
  }
}










