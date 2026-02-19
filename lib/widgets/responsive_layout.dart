import 'package:flutter/material.dart';
import '../utils/responsive_helper.dart';

/// Responsive layout wrapper that adapts to different screen sizes
class ResponsiveLayout extends StatelessWidget {
  final Widget? mobile;
  final Widget? tablet;
  final Widget? desktop;
  final Widget? fallback;

  const ResponsiveLayout({
    Key? key,
    this.mobile,
    this.tablet,
    this.desktop,
    this.fallback,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (ResponsiveHelper.isDesktop(context)) {
      return desktop ?? tablet ?? mobile ?? fallback ?? const SizedBox.shrink();
    } else if (ResponsiveHelper.isTablet(context)) {
      return tablet ?? mobile ?? fallback ?? const SizedBox.shrink();
    } else {
      return mobile ?? fallback ?? const SizedBox.shrink();
    }
  }
}

/// Responsive scaffold with adaptive layout
class ResponsiveScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final Widget? drawer;
  final Widget? endDrawer;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final List<Widget>? actions;
  final Widget? bottomNavigationBar;
  final bool centerTitle;
  final Color? backgroundColor;
  final PreferredSizeWidget? bottom;
  final bool showAppBar;
  final bool constrainContent;

  const ResponsiveScaffold({
    Key? key,
    required this.title,
    required this.body,
    this.drawer,
    this.endDrawer,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.actions,
    this.bottomNavigationBar,
    this.centerTitle = true,
    this.backgroundColor,
    this.bottom,
    this.showAppBar = true,
    this.constrainContent = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final content = constrainContent
        ? ResponsiveHelper.constrainedContent(
            context: context,
            child: body,
          )
        : body;

    return Scaffold(
      appBar: showAppBar
          ? AppBar(
              title: Text(title),
              centerTitle: centerTitle,
              actions: actions,
              bottom: bottom,
              toolbarHeight: ResponsiveHelper.appBarHeight(context),
            )
          : null,
      drawer: drawer,
      endDrawer: endDrawer,
      body: SafeArea(child: content),
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      bottomNavigationBar: bottomNavigationBar,
      backgroundColor: backgroundColor,
    );
  }
}

/// Responsive grid view
class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final double? spacing;
  final EdgeInsets? padding;
  final ScrollPhysics? physics;
  final bool shrinkWrap;

  const ResponsiveGrid({
    Key? key,
    required this.children,
    this.spacing,
    this.padding,
    this.physics,
    this.shrinkWrap = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final columns = ResponsiveHelper.gridColumns(context);
    final gap = spacing ?? ResponsiveHelper.spacing(context);

    return GridView.builder(
      padding: padding ?? ResponsiveHelper.responsivePadding(context),
      physics: physics,
      shrinkWrap: shrinkWrap,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: gap,
        mainAxisSpacing: gap,
        childAspectRatio: ResponsiveHelper.gridAspectRatio(context),
      ),
      itemCount: children.length,
      itemBuilder: (context, index) => children[index],
    );
  }
}

/// Responsive card with adaptive padding and elevation
class ResponsiveCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final double? elevation;
  final Color? color;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;

  const ResponsiveCard({
    Key? key,
    required this.child,
    this.padding,
    this.elevation,
    this.color,
    this.onTap,
    this.borderRadius,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final cardPadding = padding ?? ResponsiveHelper.responsivePadding(context);
    final cardElevation = elevation ?? ResponsiveHelper.cardElevation(context);
    final radius = borderRadius ?? BorderRadius.circular(ResponsiveHelper.borderRadius(context));

    final card = Card(
      elevation: cardElevation,
      color: color,
      shape: RoundedRectangleBorder(borderRadius: radius),
      child: Padding(
        padding: cardPadding,
        child: child,
      ),
    );

    return onTap != null
        ? InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: card,
          )
        : card;
  }
}

/// Responsive container with max width constraint
class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final Color? color;
  final double? maxWidth;
  final BoxDecoration? decoration;

  const ResponsiveContainer({
    Key? key,
    required this.child,
    this.padding,
    this.margin,
    this.color,
    this.maxWidth,
    this.decoration,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: BoxConstraints(
          maxWidth: maxWidth ?? ResponsiveHelper.maxContentWidth(context),
        ),
        padding: padding ?? ResponsiveHelper.responsivePadding(context),
        margin: margin,
        color: decoration == null ? color : null,
        decoration: decoration,
        child: child,
      ),
    );
  }
}

/// Responsive button with adaptive sizing
class ResponsiveButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final Color? color;
  final Color? textColor;
  final IconData? icon;
  final bool isLoading;
  final double? width;

  const ResponsiveButton({
    Key? key,
    required this.text,
    required this.onPressed,
    this.color,
    this.textColor,
    this.icon,
    this.isLoading = false,
    this.width,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final buttonHeight = ResponsiveHelper.buttonHeight(context);
    final fontSize = ResponsiveHelper.bodyFontSize(context);

    return SizedBox(
      height: buttonHeight,
      width: width,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? Colors.red,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              ResponsiveHelper.borderRadius(context),
            ),
          ),
        ),
        child: isLoading
            ? SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: textColor ?? Colors.white,
                  strokeWidth: 2,
                ),
              )
            : icon != null
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: ResponsiveHelper.iconSize(context, base: 20)),
                      const SizedBox(width: 8),
                      Text(
                        text,
                        style: TextStyle(
                          fontSize: fontSize,
                          fontWeight: FontWeight.bold,
                          color: textColor ?? Colors.white,
                        ),
                      ),
                    ],
                  )
                : Text(
                    text,
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.bold,
                      color: textColor ?? Colors.white,
                    ),
                  ),
      ),
    );
  }
}

/// Responsive text with adaptive font size
class ResponsiveText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final ResponsiveTextType type;

  const ResponsiveText(
    this.text, {
    Key? key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.type = ResponsiveTextType.body,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    double fontSize;
    FontWeight fontWeight;

    switch (type) {
      case ResponsiveTextType.headline:
        fontSize = ResponsiveHelper.headlineFontSize(context);
        fontWeight = FontWeight.bold;
        break;
      case ResponsiveTextType.title:
        fontSize = ResponsiveHelper.titleFontSize(context);
        fontWeight = FontWeight.w600;
        break;
      case ResponsiveTextType.body:
        fontSize = ResponsiveHelper.bodyFontSize(context);
        fontWeight = FontWeight.normal;
        break;
      case ResponsiveTextType.caption:
        fontSize = ResponsiveHelper.captionFontSize(context);
        fontWeight = FontWeight.normal;
        break;
    }

    return Text(
      text,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
      ).merge(style),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

enum ResponsiveTextType {
  headline,
  title,
  body,
  caption,
}

/// Responsive spacing widget
class ResponsiveSpacing extends StatelessWidget {
  final double base;
  final bool vertical;

  const ResponsiveSpacing({
    Key? key,
    this.base = 16.0,
    this.vertical = true,
  }) : super(key: key);

  const ResponsiveSpacing.small({Key? key, this.vertical = true})
      : base = 8.0,
        super(key: key);

  const ResponsiveSpacing.medium({Key? key, this.vertical = true})
      : base = 16.0,
        super(key: key);

  const ResponsiveSpacing.large({Key? key, this.vertical = true})
      : base = 24.0,
        super(key: key);

  @override
  Widget build(BuildContext context) {
    final spacing = ResponsiveHelper.spacing(context, base: base);
    return SizedBox(
      height: vertical ? spacing : null,
      width: vertical ? null : spacing,
    );
  }
}
