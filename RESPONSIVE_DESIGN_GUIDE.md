# 📱 RoadAid Responsive Design System

Complete guide for making RoadAid responsive across all device sizes (mobile, tablet, desktop).

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Breakpoints](#breakpoints)
3. [Core Components](#core-components)
4. [Usage Examples](#usage-examples)
5. [Migration Guide](#migration-guide)
6. [Best Practices](#best-practices)

---

## 🎯 Overview

The RoadAid responsive design system automatically adapts UI elements to different screen sizes:

- **Mobile**: < 600px width (phones)
- **Tablet**: 600px - 1199px width (tablets, small laptops)
- **Desktop**: ≥ 1200px width (large screens)

---

## 📏 Breakpoints

### Material Design Standard Breakpoints

```dart
// Mobile: screenWidth < 600
// Tablet: 600 <= screenWidth < 1200
// Desktop: screenWidth >= 1200
```

### Device Detection

```dart
import 'package:roadaid/utils/responsive_helper.dart';

// In your widget:
if (context.isMobile) {
  // Mobile layout
} else if (context.isTablet) {
  // Tablet layout
} else if (context.isDesktop) {
  // Desktop layout
}

// Or use the helper:
ResponsiveHelper.isMobile(context)
ResponsiveHelper.isTablet(context)
ResponsiveHelper.isDesktop(context)
```

---

## 🧩 Core Components

### 1. ResponsiveHelper

Main utility class for responsive values.

```dart
import 'package:roadaid/utils/responsive_helper.dart';

// Screen dimensions
double width = ResponsiveHelper.screenWidth(context);
double height = ResponsiveHelper.screenHeight(context);

// Responsive values
double padding = ResponsiveHelper.responsiveValue(
  context,
  mobile: 16.0,
  tablet: 24.0,
  desktop: 32.0,
);

// Font sizes
double headlineSize = ResponsiveHelper.headlineFontSize(context);
double titleSize = ResponsiveHelper.titleFontSize(context);
double bodySize = ResponsiveHelper.bodyFontSize(context);
double captionSize = ResponsiveHelper.captionFontSize(context);

// Spacing
double small = ResponsiveHelper.smallSpacing(context);
double medium = ResponsiveHelper.mediumSpacing(context);
double large = ResponsiveHelper.largeSpacing(context);

// Layout dimensions
double appBarHeight = ResponsiveHelper.appBarHeight(context);
double maxWidth = ResponsiveHelper.maxContentWidth(context);
double buttonHeight = ResponsiveHelper.buttonHeight(context);
int gridColumns = ResponsiveHelper.gridColumns(context);
```

### 2. ResponsiveScaffold

Drop-in replacement for Scaffold with responsive features.

```dart
import 'package:roadaid/widgets/responsive_layout.dart';

return ResponsiveScaffold(
  title: 'My Screen',
  body: MyContent(),
  constrainContent: true, // Constrains width on desktop
  actions: [
    IconButton(icon: Icon(Icons.settings), onPressed: () {}),
  ],
);
```

### 3. ResponsiveLayout

Different widgets for different screen sizes.

```dart
return ResponsiveLayout(
  mobile: MobileView(),
  tablet: TabletView(),
  desktop: DesktopView(),
  fallback: MobileView(), // Used if specific view not provided
);
```

### 4. ResponsiveCard

Auto-adjusting card with responsive padding/elevation.

```dart
ResponsiveCard(
  child: Column(
    children: [
      Text('Card Content'),
    ],
  ),
  onTap: () {
    // Handle tap
  },
)
```

### 5. ResponsiveButton

Button with adaptive sizing.

```dart
ResponsiveButton(
  text: 'Submit',
  icon: Icons.check,
  onPressed: () {},
  isLoading: false,
  color: Colors.red,
)
```

### 6. ResponsiveText

Text with adaptive font sizes.

```dart
ResponsiveText(
  'Headline Text',
  type: ResponsiveTextType.headline,
)

ResponsiveText(
  'Title Text',
  type: ResponsiveTextType.title,
)

ResponsiveText(
  'Body Text',
  type: ResponsiveTextType.body,
)

ResponsiveText(
  'Caption Text',
  type: ResponsiveTextType.caption,
)
```

### 7. ResponsiveSpacing

Responsive spacing widgets.

```dart
ResponsiveSpacing.small()  // 8px base
ResponsiveSpacing.medium() // 16px base
ResponsiveSpacing.large()  // 24px base

// Horizontal spacing
ResponsiveSpacing.medium(vertical: false)
```

### 8. ResponsiveGrid

Auto-adjusting grid layout.

```dart
ResponsiveGrid(
  children: [
    ShopCard(),
    ShopCard(),
    ShopCard(),
    // Mobile: 2 columns
    // Tablet: 3 columns
    // Desktop: 4 columns
  ],
)
```

### 9. ResponsiveContainer

Container with max-width constraint.

```dart
ResponsiveContainer(
  maxWidth: 1200,
  child: MyContent(),
)
```

---

## 💡 Usage Examples

### Example 1: Simple Screen

**Before (Fixed):**
```dart
class MyScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('My Screen')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Hello', style: TextStyle(fontSize: 24)),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {},
              child: Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }
}
```

**After (Responsive):**
```dart
import 'package:roadaid/widgets/responsive_layout.dart';
import 'package:roadaid/utils/responsive_helper.dart';

class MyScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffold(
      title: 'My Screen',
      constrainContent: true, // Centers on desktop
      body: Padding(
        padding: ResponsiveHelper.responsivePadding(context),
        child: Column(
          children: [
            ResponsiveText(
              'Hello',
              type: ResponsiveTextType.headline,
            ),
            ResponsiveSpacing.medium(),
            ResponsiveButton(
              text: 'Submit',
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
  }
}
```

### Example 2: Grid Layout

**Before (Fixed):**
```dart
GridView.builder(
  padding: EdgeInsets.all(16),
  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 2,
    crossAxisSpacing: 16,
    mainAxisSpacing: 16,
  ),
  itemCount: shops.length,
  itemBuilder: (context, index) => ShopCard(shops[index]),
)
```

**After (Responsive):**
```dart
ResponsiveGrid(
  children: shops.map((shop) => ShopCard(shop)).toList(),
  // Automatically adapts:
  // Mobile: 2 columns
  // Tablet: 3 columns
  // Desktop: 4 columns
)
```

### Example 3: Conditional Layout

**Before (Fixed):**
```dart
Row(
  children: [
    Expanded(child: LeftPanel()),
    Expanded(child: RightPanel()),
  ],
)
```

**After (Responsive):**
```dart
ResponsiveLayout(
  mobile: Column(
    children: [
      LeftPanel(),
      RightPanel(),
    ],
  ),
  tablet: Row(
    children: [
      Expanded(child: LeftPanel()),
      Expanded(child: RightPanel()),
    ],
  ),
  desktop: Row(
    children: [
      Expanded(flex: 2, child: LeftPanel()),
      Expanded(flex: 3, child: RightPanel()),
    ],
  ),
)
```

### Example 4: List with Responsive Tiles

**Before (Fixed):**
```dart
ListView.builder(
  itemCount: items.length,
  itemBuilder: (context, index) {
    return ListTile(
      leading: Icon(Icons.shop, size: 24),
      title: Text(items[index].name, style: TextStyle(fontSize: 16)),
      subtitle: Text(items[index].address, style: TextStyle(fontSize: 14)),
    );
  },
)
```

**After (Responsive):**
```dart
ListView.builder(
  padding: ResponsiveHelper.responsivePadding(context),
  itemCount: items.length,
  itemBuilder: (context, index) {
    return ResponsiveCard(
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveHelper.spacing(context),
        vertical: ResponsiveHelper.spacing(context, base: 12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.shop,
            size: ResponsiveHelper.iconSize(context),
          ),
          SizedBox(width: ResponsiveHelper.smallSpacing(context)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ResponsiveText(
                  items[index].name,
                  type: ResponsiveTextType.title,
                ),
                ResponsiveText(
                  items[index].address,
                  type: ResponsiveTextType.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  },
)
```

### Example 5: Form with Responsive Inputs

```dart
Form(
  child: Padding(
    padding: ResponsiveHelper.responsivePadding(context),
    child: Column(
      children: [
        ResponsiveText(
          'Shop Settings',
          type: ResponsiveTextType.headline,
        ),
        ResponsiveSpacing.large(),
        
        TextFormField(
          decoration: InputDecoration(
            labelText: 'Shop Name',
            contentPadding: EdgeInsets.all(
              ResponsiveHelper.spacing(context),
            ),
          ),
          style: TextStyle(
            fontSize: ResponsiveHelper.bodyFontSize(context),
          ),
        ),
        
        ResponsiveSpacing.medium(),
        
        ResponsiveButton(
          text: 'Save Changes',
          onPressed: _save,
          width: double.infinity,
        ),
      ],
    ),
  ),
)
```

---

## 🔄 Migration Guide

### Step-by-Step Migration

#### 1. Update Imports
```dart
// Add these imports to your screens
import 'package:roadaid/utils/responsive_helper.dart';
import 'package:roadaid/widgets/responsive_layout.dart';
```

#### 2. Replace Scaffold
```dart
// Before
Scaffold(
  appBar: AppBar(title: Text('Title')),
  body: MyBody(),
)

// After
ResponsiveScaffold(
  title: 'Title',
  body: MyBody(),
  constrainContent: true, // Optional: constrains width on desktop
)
```

#### 3. Replace Fixed Padding
```dart
// Before
Padding(
  padding: EdgeInsets.all(16),
  child: child,
)

// After
Padding(
  padding: ResponsiveHelper.responsivePadding(context),
  child: child,
)
```

#### 4. Replace Fixed Font Sizes
```dart
// Before
Text(
  'Hello',
  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
)

// After
ResponsiveText(
  'Hello',
  type: ResponsiveTextType.headline,
)
```

#### 5. Replace Fixed SizedBox
```dart
// Before
SizedBox(height: 16)

// After
ResponsiveSpacing.medium()
```

#### 6. Replace Fixed Grid
```dart
// Before
GridView.count(
  crossAxisCount: 2,
  children: items,
)

// After
ResponsiveGrid(
  children: items,
)
```

---

## ✅ Best Practices

### 1. Use Context Extensions
```dart
// Instead of
if (ResponsiveHelper.isMobile(context)) { }

// Use
if (context.isMobile) { }
```

### 2. Test on Multiple Devices
- Test on mobile (< 600px)
- Test on tablet (600px - 1199px)
- Test on desktop (≥ 1200px)
- Test portrait and landscape

### 3. Constrain Desktop Content
```dart
// Prevent content from stretching too wide on desktop
ResponsiveScaffold(
  title: 'My Screen',
  constrainContent: true, // ✅ Good
  body: MyContent(),
)
```

### 4. Use Responsive Spacing
```dart
// ❌ Bad
SizedBox(height: 16)

// ✅ Good
ResponsiveSpacing.medium()

// ✅ Good (custom)
SizedBox(height: ResponsiveHelper.spacing(context, base: 20))
```

### 5. Use Responsive Values
```dart
// ❌ Bad
Container(
  padding: EdgeInsets.all(16),
  child: child,
)

// ✅ Good
Container(
  padding: ResponsiveHelper.responsivePadding(context),
  child: child,
)

// ✅ Good (custom)
Container(
  padding: EdgeInsets.all(
    ResponsiveHelper.responsiveValue(
      context,
      mobile: 12,
      tablet: 20,
      desktop: 28,
    ),
  ),
  child: child,
)
```

### 6. Optimize for Touch Targets
```dart
// Minimum touch target: 48px
ResponsiveButton(
  text: 'Button',
  onPressed: () {},
  // Automatically uses responsive button height
  // Mobile: 48px, Tablet: 52px, Desktop: 56px
)
```

### 7. Use MediaQuery Wisely
```dart
// ❌ Bad (doesn't rebuild on size change)
final width = MediaQuery.of(context).size.width;

// ✅ Good (rebuilds on size change)
return LayoutBuilder(
  builder: (context, constraints) {
    final width = constraints.maxWidth;
    return MyWidget(width: width);
  },
);
```

---

## 🎨 Component Reference

### Spacing Scale

| Size | Mobile | Tablet | Desktop |
|------|--------|--------|---------|
| Small | 8px | 10px | 12px |
| Medium | 16px | 20px | 24px |
| Large | 24px | 30px | 36px |

### Font Sizes

| Type | Mobile | Tablet | Desktop |
|------|--------|--------|---------|
| Headline | 24px | 28px | 32px |
| Title | 20px | 22px | 24px |
| Body | 14px | 15px | 16px |
| Caption | 12px | 13px | 14px |

### Grid Columns

| Device | Columns |
|--------|---------|
| Mobile | 2 |
| Tablet | 3 |
| Desktop | 4 |

### Button Heights

| Device | Height |
|--------|--------|
| Mobile | 48px |
| Tablet | 52px |
| Desktop | 56px |

---

## 🧪 Testing Checklist

- [ ] Test on mobile device (< 600px)
- [ ] Test on tablet (600px - 1199px)
- [ ] Test on desktop (≥ 1200px)
- [ ] Test portrait orientation
- [ ] Test landscape orientation
- [ ] Test with different font scales (accessibility)
- [ ] Test with keyboard navigation
- [ ] Verify touch targets are at least 48px
- [ ] Verify content doesn't stretch on large screens
- [ ] Verify scrolling works properly
- [ ] Verify dialogs/bottom sheets adapt

---

## 📝 Quick Reference

### Common Patterns

```dart
// Responsive padding
padding: ResponsiveHelper.responsivePadding(context)

// Responsive spacing
ResponsiveSpacing.medium()

// Responsive text
ResponsiveText('Text', type: ResponsiveTextType.title)

// Responsive button
ResponsiveButton(text: 'Button', onPressed: () {})

// Responsive card
ResponsiveCard(child: MyContent())

// Responsive grid
ResponsiveGrid(children: items)

// Device detection
if (context.isMobile) { }
if (context.isTablet) { }
if (context.isDesktop) { }

// Responsive value
final value = ResponsiveHelper.responsiveValue(
  context,
  mobile: 16,
  tablet: 24,
  desktop: 32,
)
```

---

## 🚀 Summary

1. **Import** responsive utilities
2. **Replace** fixed values with responsive ones
3. **Use** responsive widgets
4. **Test** on multiple devices
5. **Iterate** based on feedback

The RoadAid app is now fully responsive and adapts beautifully to any device size! 📱💻🖥️

---

**Files:**
- `lib/utils/responsive_helper.dart` - Core utilities
- `lib/widgets/responsive_layout.dart` - Responsive widgets

**Need help?** Check examples above or refer to Flutter documentation.
