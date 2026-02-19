# Mechanic Screen Animation Guidelines

This document defines the unified animation conventions for Mechanic ("Angkas") screens.

## Core Entrance Animation
- Widget: `AngkasSlideIn`
- Duration: 600ms
- Curve: `Curves.easeOut`
- Offset: `begin: Offset(0, 0.3) -> Offset.zero`
- Fade: Enabled (opacity tween matches full duration)

Usage example (wrap top-level screen content inside `SafeArea`):
```dart
SafeArea(
  child: AngkasSlideIn(
    child: Column(
      children: [ /* screen content */ ],
    ),
  ),
)
```

## When NOT to use `AngkasSlideIn`
- Transient overlays (e.g. incoming request popup) that deliberately use a distinct feel (elastic / spring) for urgency.
- Inner list item animations or micro-interactions (use implicit animations or AnimatedSwitcher instead).

## Internal State Transitions
For swapping content (loading/error/data) in a section:
- Use `AnimatedSwitcher` with duration 600ms.
- Inbound transition: `FadeTransition + SlideTransition` with a subtle vertical offset `Offset(0, 0.05)`.
- Curves: `switchInCurve: Curves.easeOut`, `switchOutCurve: Curves.easeIn`.

Code pattern:
```dart
AnimatedSwitcher(
  duration: const Duration(milliseconds: 600),
  switchInCurve: Curves.easeOut,
  switchOutCurve: Curves.easeIn,
  transitionBuilder: (child, animation) => FadeTransition(
    opacity: animation,
    child: SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.05),
        end: Offset.zero,
      ).animate(animation),
      child: child,
    ),
  ),
  child: _isLoading
      ? const CircularProgressIndicator()
      : _error != null
          ? ErrorWidget(...)
          : ActualContentWidget(),
)
```

## Numeric / Metric Count Animations
- Use a separate `AnimationController` (e.g. 1500ms) with a curve like `Curves.easeOutCubic` for counting-up stats.
- Keep entrance (slide) and metric (count) animations decoupled to avoid jank.

## Rationale
| Aspect | Choice | Reason |
| ------ | ------ | ------ |
| Duration (600ms) | Balanced between responsiveness & perceivable motion | Avoids sluggishness of 800ms while retaining smoothness |
| Curve (`easeOut`) | Natural deceleration | Consistent UI language across screens |
| Offset (0, 0.3) | Subtle vertical rise | Feels grounded; avoids large travel from off-screen |
| Fade combo | Softens motion & hides layout pop | Improves perceived polish |

## Migration Checklist
If converting an older screen:
1. Remove root `AnimationController` + `Tween<Offset>` unless needed for custom sequencing.
2. Wrap root content with `AngkasSlideIn`.
3. Replace any large off-screen offsets like `(0,1)` or `(0,-1)` unless intentionally modal.
4. Standardize internal content swaps to `AnimatedSwitcher` pattern.
5. Keep any specialized animations (e.g., pulsing availability indicators) separate.

## Exceptions Policy
A screen may diverge only if:
- It represents a distinct interaction model (modal, critical alert, real-time overlay), OR
- Performance constraints require reducing animation cost (very large lists). In such cases reduce duration to 300–400ms but keep curve & direction.

Document the exception inline with a comment:
```dart
// Exception: using faster 400ms slide due to extremely frequent rebuilds in live tracking view.
```

## Future Enhancements
- Potential: add stagger utility for list items.
- Potential: global animation theme extension for centralized durations.

---
Maintained: September 2025
