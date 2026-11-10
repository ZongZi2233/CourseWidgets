part of '../glass_menu.dart';

class _GlassMenuState extends State<GlassMenu> with TickerProviderStateMixin {
  final OverlayPortalController _overlayController = OverlayPortalController();

  late final GlassMorphController _morphController;
  late final ScrollController _scrollController;
  Size? _triggerSize;
  double? _triggerBorderRadius;
  Offset _triggerGlobalPosition = Offset.zero; // captured in _openMenu
  int? _hoveredIndex;
  bool _isDragging = false;
  bool _hasStretched =
      false; // Prevents closing if we moved into stretch territory
  double _initialScrollOffset = 0.0;
  Offset _initialLocalPosition = Offset.zero;
  double _horizontalOffset = 0.0;
  double _verticalOffset = 0.0;

  /// Live screen-space nudge added to the captured trigger position while the
  /// menu is OPEN, so an external owner can keep the floating menu glued to a
  /// moving anchor (e.g. a canvas tile trailing under a rubberband) WITHOUT
  /// re-opening. Reset to zero on each [_openMenu].
  Offset _followOffset = Offset.zero;

  // --- Granular Update System (Performance + No flicker) ---
  late final ValueNotifier<int?> _hoveredIndexNotifier;
  late final ValueNotifier<bool> _isDraggingNotifier;
  List<Widget>? _cachedWrappedItems;

  @override
  void didUpdateWidget(GlassMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.controller, oldWidget.controller)) {
      oldWidget.controller?._detach(this);
      widget.controller?._attach(this);
    }
    if (!identical(widget.items, oldWidget.items)) {
      _cachedWrappedItems = null;
      if (widget.items.length < oldWidget.items.length) {
        _hoveredIndex = null;
        _hoveredIndexNotifier.value = null;
      }
    }
  }

  Alignment _morphAlignment = Alignment.topLeft;

  Alignment? _getAlignment(GlassMenuAlignment align) {
    switch (align) {
      case GlassMenuAlignment.none:
        return null;

      case GlassMenuAlignment.topLeft:
        return Alignment.topLeft;
      case GlassMenuAlignment.topCenter:
        return Alignment.topCenter;
      case GlassMenuAlignment.topRight:
        return Alignment.topRight;
      case GlassMenuAlignment.centerLeft:
        return Alignment.centerLeft;
      case GlassMenuAlignment.center:
        return Alignment.center;
      case GlassMenuAlignment.centerRight:
        return Alignment.centerRight;
      case GlassMenuAlignment.bottomLeft:
        return Alignment.bottomLeft;
      case GlassMenuAlignment.bottomCenter:
        return Alignment.bottomCenter;
      case GlassMenuAlignment.bottomRight:
        return Alignment.bottomRight;
    }
  }

  @override
  void initState() {
    super.initState();
    _morphController = GlassMorphController(vsync: this);
    _morphController.addListener(() {
      // Hide overlay only when the spring has FULLY SETTLED near 0 during close.
      if (_overlayController.isShowing &&
          _morphController.isClosing &&
          _morphController.value <= 0.001 &&
          _morphController.velocity.abs() < 0.5 &&
          _morphController.status != AnimationStatus.forward) {
        _overlayController.hide();
        _horizontalOffset = 0.0;
        _verticalOffset = 0.0;
      }

      if (mounted) setState(() {});
    });
    _scrollController = ScrollController();
    _hoveredIndexNotifier = ValueNotifier(null);
    _isDraggingNotifier = ValueNotifier(false);
    widget.controller?._attach(this);
  }

  ModalRoute<dynamic>? _route;

  @override
  void dispose() {
    _removeRouteListeners();
    _route = null;
    widget.controller?._detach(this);
    _morphController.dispose();
    _scrollController.dispose();
    _hoveredIndexNotifier.dispose();
    _isDraggingNotifier.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _morphController.setDisableAnimations(
      MediaQuery.of(context).disableAnimations,
    );
    _updateRouteListener();
  }

  void _updateRouteListener() {
    final currentRoute = ModalRoute.of(context);
    if (_route != currentRoute) {
      _removeRouteListeners();
      _route = currentRoute;
      _addRouteListeners();
    }
  }

  void _addRouteListeners() {
    final route = _route;
    if (route == null) return;
    route.secondaryAnimation
        ?.addStatusListener(_handleSecondaryAnimationStatus);
    route.animation?.addStatusListener(_handlePrimaryAnimationStatus);
  }

  void _removeRouteListeners() {
    final route = _route;
    if (route == null) return;
    route.secondaryAnimation
        ?.removeStatusListener(_handleSecondaryAnimationStatus);
    route.animation?.removeStatusListener(_handlePrimaryAnimationStatus);
  }

  void _handleSecondaryAnimationStatus(AnimationStatus status) {
    if (!_overlayController.isShowing) return;
    if (status == AnimationStatus.forward) {
      _dismissImmediately();
    }
  }

  void _handlePrimaryAnimationStatus(AnimationStatus status) {
    if (!_overlayController.isShowing) return;
    if (status == AnimationStatus.reverse) {
      _dismissImmediately();
    }
  }

  void _dismissImmediately() {
    if (!_overlayController.isShowing && _morphController.value == 0.0) {
      return;
    }
    final wasClosing = _morphController.isClosing;
    _overlayController.hide();
    _morphController.reset();
    _horizontalOffset = 0.0;
    _verticalOffset = 0.0;
    _hoveredIndex = null;
    _hoveredIndexNotifier.value = null;
    _isDragging = false;
    _isDraggingNotifier.value = false;
    _hasStretched = false;
    _followOffset = Offset.zero;
    if (!wasClosing) {
      widget.onClose?.call();
    }
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget triggerChild = widget.triggerBuilder != null
        ? widget.triggerBuilder!(context, _toggleMenu)
        : GestureDetector(
            onTap: _toggleMenu,
            child: widget.trigger,
          );

    return AnimatedBuilder(
      animation: _morphController.animation,
      builder: (context, child) {
        final rawValue = _morphController.value;
        final clampedValue = rawValue.clamp(0.0, 1.0);

        // Block trigger taps while menu is significantly open.
        final isMenuBlocking = _overlayController.isShowing && rawValue > 0.8;

        final isHandoff =
            _morphController.isClosing && _morphController.hasHandedOff;
        // Smoothly crossfade trigger out over first 25% of morph so the icon
        // never blinks out on frame 1.
        final triggerOpacity = (_overlayController.isShowing && !isHandoff)
            ? (1.0 - (clampedValue / 0.25)).clamp(0.0, 1.0)
            : 1.0;

        final tw = _triggerSize?.width ?? 44.0;
        final th = _triggerSize?.height ?? 44.0;
        final menuWidth = widget.menuWidth;
        final menuHeight = _calculateMenuHeight();
        final dxMag = (menuWidth - tw) / 2.0;
        final dyMag = (menuHeight - th) / 2.0;
        final finalDx = -_morphAlignment.x * dxMag;
        final finalDy = -_morphAlignment.y * dyMag;

        final double pushDx =
            isHandoff ? (finalDx + _horizontalOffset) * (rawValue * 0.25) : 0.0;
        final double pushDy =
            isHandoff ? (finalDy + _verticalOffset) * (rawValue * 0.25) : 0.0;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Transform.translate(
              offset: Offset(pushDx, pushDy),
              child: Opacity(
                opacity: triggerOpacity,
                child: GlassMaterializeScope(
                  glassProgress: triggerOpacity,
                  contentOpacity: triggerOpacity,
                  contentSigma: 0.0,
                  child: IgnorePointer(
                    ignoring: isMenuBlocking,
                    child: triggerChild,
                  ),
                ),
              ),
            ),
            OverlayPortal(
              controller: _overlayController,
              overlayChildBuilder: _buildMorphingOverlay,
              overlayLocation: OverlayChildLocation.rootOverlay,
            ),
          ],
        );
      },
    );
  }

  void _toggleMenu() {
    if (_overlayController.isShowing && _morphController.value > 0.1) {
      _closeMenu();
    } else {
      _openMenu();
    }
  }

  void setFollowOffset(Offset offset) {
    if (_followOffset == offset) return;
    setState(() => _followOffset = offset);
  }

  void _openMenu() {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) {
      return;
    }

    _updateRouteListener();

    _triggerSize = renderBox.size;
    _triggerBorderRadius = _triggerSize!.shortestSide / 2.0;
    _triggerGlobalPosition = renderBox.localToGlobal(Offset.zero);
    _followOffset = Offset.zero;
    final position = _triggerGlobalPosition;
    final mediaQuery = MediaQuery.maybeOf(context);
    final screenWidth = mediaQuery?.size.width ?? double.infinity;
    final screenHeight = mediaQuery?.size.height ?? double.infinity;

    final menuHeight = _calculateMenuHeight();

    // 1. Determine base alignment (Auto vs Manual)
    if (widget.menuAlignment == null ||
        widget.menuAlignment == GlassMenuAlignment.none) {
      final triggerCenterX = position.dx + _triggerSize!.width / 2.0;
      final isRightHalf =
          screenWidth.isFinite && triggerCenterX > screenWidth / 2;
      final isCenterBand = screenWidth.isFinite &&
          _triggerSize!.width <= 68.0 &&
          triggerCenterX > screenWidth * 0.24 &&
          triggerCenterX < screenWidth * 0.76;

      final spaceBelow = screenHeight.isFinite
          ? screenHeight - (position.dy + _triggerSize!.height) - 72.0
          : double.infinity;
      final spaceAbove =
          screenHeight.isFinite ? position.dy - 64.0 : double.infinity;

      final shouldFlipVertical =
          spaceBelow < menuHeight && spaceAbove > spaceBelow;

      if (shouldFlipVertical) {
        _morphAlignment = isCenterBand
            ? Alignment.bottomCenter
            : (isRightHalf ? Alignment.bottomRight : Alignment.bottomLeft);
      } else {
        _morphAlignment = isCenterBand
            ? Alignment.topCenter
            : (isRightHalf ? Alignment.topRight : Alignment.topLeft);
      }
    } else {
      _morphAlignment =
          _getAlignment(widget.menuAlignment!) ?? Alignment.center;
    }

    // 2. Clamping: calculate offsets to keep menu within screen bounds
    double hOffset = 0.0;
    double vOffset = 0.0;

    if (widget.autoAdjustToScreen) {
      final flutterView = View.of(context);
      final mqPadding = EdgeInsets.fromViewPadding(
          flutterView.padding, flutterView.devicePixelRatio);

      final double safeTop = widget.menuPadding.top + mqPadding.top;
      final double safeBottom = widget.menuPadding.bottom + mqPadding.bottom;
      final double safeLeft = widget.menuPadding.left + mqPadding.left;
      final double safeRight = widget.menuPadding.right + mqPadding.right;

      final double targetX =
          position.dx + (1 + _morphAlignment.x) * _triggerSize!.width / 2;
      final double targetY =
          position.dy + (1 + _morphAlignment.y) * _triggerSize!.height / 2;
      final double menuLeft =
          targetX - (1 + _morphAlignment.x) * widget.menuWidth / 2;
      final double menuTop = targetY - (1 + _morphAlignment.y) * menuHeight / 2;

      if (menuLeft < safeLeft) {
        hOffset = safeLeft - menuLeft;
      } else if (screenWidth.isFinite &&
          menuLeft + widget.menuWidth > screenWidth - safeRight) {
        hOffset = (screenWidth - safeRight) - (menuLeft + widget.menuWidth);
      }

      if (menuTop < safeTop) {
        vOffset = safeTop - menuTop;
      } else if (screenHeight.isFinite &&
          menuTop + menuHeight > screenHeight - safeBottom) {
        vOffset = (screenHeight - safeBottom) - (menuTop + menuHeight);
      }
    }

    setState(() {
      _horizontalOffset = hOffset;
      _verticalOffset = vOffset;
    });

    _overlayController.show();
    _morphController.open();
  }

  void _closeMenu() {
    if (!_overlayController.isShowing) return;
    setState(() {
      _hoveredIndex = null;
      _isDragging = false;
    });
    _morphController.close();
    widget.onClose?.call();
  }

  Widget _buildMorphingOverlay(BuildContext context) {
    if (_triggerSize == null) return const SizedBox.shrink();

    final rawValue = _morphController.value;
    final clampedValue = rawValue.clamp(0.0, 1.0);

    final tw = _triggerSize!.width;
    final th = _triggerSize!.height;
    final menuWidth = widget.menuWidth.toDouble();
    final menuHeight = _calculateMenuHeight();
    final targetHeight = widget.menuHeight ?? menuHeight;

    final dxMag = (menuWidth - tw) / 2.0;
    final dyMag = (targetHeight - th) / 2.0;
    final finalDx = -_morphAlignment.x * dxMag;
    final finalDy = -_morphAlignment.y * dyMag;

    final state = _morphController.computeState(
      finalDx: finalDx,
      finalDy: finalDy,
      horizontalOffset: _horizontalOffset,
      verticalOffset: _verticalOffset,
    );

    // ── FlClash / Prism-UI Style Anchored Rect Interpolation ────────────────
    // Interpolating directly from triggerRect to targetMenuRect guarantees that
    // the anchored corner stays locked to the trigger button with zero drift.
    final triggerLeft = _triggerGlobalPosition.dx + _followOffset.dx;
    final triggerTop = _triggerGlobalPosition.dy + _followOffset.dy;
    final Rect startRect = widget.morphFromZero
        ? Rect.fromCenter(
            center: Offset(triggerLeft + tw / 2.0, triggerTop + th / 2.0),
            width: 0.0,
            height: 0.0,
          )
        : Rect.fromLTWH(triggerLeft, triggerTop, tw, th);

    final double anchorX = triggerLeft + (1.0 + _morphAlignment.x) * tw / 2.0;
    final double anchorY = triggerTop + (1.0 + _morphAlignment.y) * th / 2.0;
    final double targetLeft =
        anchorX - (1.0 + _morphAlignment.x) * menuWidth / 2.0 + _horizontalOffset;
    final double targetTop =
        anchorY - (1.0 + _morphAlignment.y) * targetHeight / 2.0 + _verticalOffset;
    final Rect targetRect =
        Rect.fromLTWH(targetLeft, targetTop, menuWidth, targetHeight);

    final Rect currentRect = Rect.lerp(startRect, targetRect, state.sizeT)!;
    final double currentWidth = math.max(0.0, currentRect.width);
    final double currentHeight = math.max(0.0, currentRect.height);

    final double startRadius =
        (_triggerBorderRadius ?? (math.min(tw, th) / 2.0))
            .clamp(4.0, widget.menuBorderRadius);
    final double currentRadius = lerpDouble(
      startRadius,
      widget.menuBorderRadius,
      Curves.easeOutCubic.transform(clampedValue),
    )!
        .clamp(0.0, math.min(currentWidth, currentHeight) / 2.0);

    final double overlayOpacity =
        (_morphController.isClosing && _morphController.hasHandedOff)
            ? 0.0
            : (clampedValue / 0.16).clamp(0.0, 1.0);

    return Stack(
      children: [
        // Invisible full-screen tap-to-close barrier
        if (clampedValue > 0.25 && widget.showDismissBarrier)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _closeMenu,
              child: const ColoredBox(color: Color(0x00000000)),
            ),
          ),

        Positioned(
          left: currentRect.left,
          top: currentRect.top,
          child: Opacity(
            opacity: overlayOpacity,
            child: IgnorePointer(
              ignoring: clampedValue < 0.75,
              child: _buildMorphingContainer(
                state,
                clampedValue,
                currentWidth,
                currentHeight,
                currentRadius,
                targetHeight,
              ),
            ),
          ),
        ),
      ],
    );
  }

  double _calculateMenuHeight() {
    if (widget.menuHeight != null) {
      return widget.menuHeight!;
    }

    // Account for system text scaling when calculating natural height.
    // Without this, increased text size causes items to render taller than
    // the height budget, triggering unwanted scrolling (GitHub issue).
    final mediaQuery = MediaQuery.maybeOf(context);

    // Sum all menu item heights, scaled by text scaler
    final itemHeights = widget.items.fold<double>(
      0.0,
      (sum, item) => sum + _getScaledItemHeight(item, context),
    );

    // Add vertical padding (12px top + 12px bottom = 24px total)
    // plus vertical gaps between items (2px each)
    final gaps = (widget.items.length - 1) * 2.0;
    final naturalHeight = itemHeights + 24.0 + gaps;

    if (widget.autoAdjustToScreen) {
      if (mediaQuery != null) {
        final flutterView = View.of(context);
        final mqPadding = EdgeInsets.fromViewPadding(
            flutterView.padding, flutterView.devicePixelRatio);

        // Clamp to screen height minus safe areas and a 20px safety buffer
        final maxHeight = mediaQuery.size.height -
            mqPadding.vertical -
            widget.menuPadding.vertical -
            20.0;
        return math.min(naturalHeight, math.max(0.0, maxHeight));
      }
    }

    return naturalHeight;
  }

  Widget _buildMorphingContainer(
    LiquidMorphState state,
    double clampedValue,
    double currentWidth,
    double currentHeight,
    double currentRadius,
    double targetHeight,
  ) {
    if (currentWidth < 1.0 || currentHeight < 1.0) {
      return const SizedBox.shrink();
    }

    final teardropShape = LiquidRoundedSuperellipse(
      borderRadius: currentRadius,
    );

    final containerScale = state.containerScale;

    final inheritedSettings = InheritedLiquidGlass.of(context);
    final effectiveSettings = widget.settings ??
        inheritedSettings ??
        const LiquidGlassSettings(
          blur: 10,
          thickness: 10,
          glassColor: Color.fromRGBO(255, 255, 255, 0.12),
          lightAngle: GlassDefaults.lightAngle,
          lightIntensity: 0.7,
          ambientStrength: 0.4,
          saturation: 1.2,
          refractiveIndex: 0.7,
          chromaticAberration: 0.0,
        );

    final scrollCtrl = _scrollController;
    final double contentOpacity =
        ((clampedValue - 0.18) / 0.52).clamp(0.0, 1.0);
    final double scaleX = widget.menuWidth > 0
        ? (currentWidth / widget.menuWidth).clamp(0.01, 1.15)
        : 1.0;
    final double scaleY = targetHeight > 0
        ? (currentHeight / targetHeight).clamp(0.01, 1.15)
        : 1.0;

    final glassContent = LiquidStretch(
      stretch: widget.stretch,
      interactionScale: widget.interactionScale,
      resistance: widget.stretchResistance,
      axis: widget.stretchAxis,
      suppressInteractionOnChildren: false,
      anchorStretch: false,
      allowPositiveX: widget.allowPositiveX ?? (_morphAlignment.x < 0),
      allowNegativeX: widget.allowNegativeX ?? (_morphAlignment.x > 0),
      allowPositiveY: widget.allowPositiveY ?? (_morphAlignment.y < 0),
      allowNegativeY: widget.allowNegativeY ?? (_morphAlignment.y > 0),
      child: GlassContainer(
        useOwnLayer: true,
        settings: effectiveSettings,
        // Use Standard tier (LightweightLiquidGlass + ClipRSuperellipse + cached
        // BackdropFilterLayer + 3D Fresnel shader) to guarantee 0 Picture.toImageSync
        // calls during 120Hz size/radius morphing.
        quality: GlassQuality.standard,
        platformViewBackdrop: widget.platformViewBackdrop,
        allowElevation: false,
        width: currentWidth,
        height: currentHeight,
        shape: teardropShape,
        clipBehavior: Clip.antiAlias,
        glowIntensity: widget.glowIntensity,
        child: Builder(builder: (context) {
          final isDark = GlassTheme.brightnessOf(context) == Brightness.dark;
          return GlassGlow(
            enabled: widget.enableInteractionGlow,
            glowOnTapOnly: widget.glowOnTapOnly,
            glowColor: widget.glowColor ??
                (isDark
                    ? CupertinoColors.white
                        .withValues(alpha: GlassDefaults.specularLightAlpha)
                    : CupertinoColors.black
                        .withValues(alpha: GlassDefaults.specularDarkAlpha)),
            glowRadius: widget.glowRadius,
            glowBlurRadius: 40,
            clipper: ShapeBorderClipper(
              shape: teardropShape,
            ),
            child: Transform.scale(
              scale: containerScale,
              alignment: _morphAlignment,
              child: OverflowBox(
                alignment: _morphAlignment,
                minWidth: widget.menuWidth,
                maxWidth: widget.menuWidth,
                minHeight: targetHeight,
                maxHeight: targetHeight,
                child: Transform.scale(
                  scaleX: scaleX,
                  scaleY: scaleY,
                  alignment: _morphAlignment,
                  child: Opacity(
                    opacity: contentOpacity,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Sliding selection pill (background)
                        ValueListenableBuilder<int?>(
                          valueListenable: _hoveredIndexNotifier,
                          builder: (context, hoveredIndex, _) {
                            if (hoveredIndex == null) {
                              return const SizedBox.shrink();
                            }
                            return AnimatedPositioned(
                              duration: const Duration(milliseconds: 140),
                              curve: Curves.easeOutCubic,
                              left: 12,
                              right: 12,
                              top: _getItemOffset(hoveredIndex, context) -
                                  (scrollCtrl.hasClients
                                      ? scrollCtrl.offset
                                      : 0.0),
                              height: _getScaledItemHeight(
                                  widget.items[hoveredIndex], context),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: widget.selectionColor,
                                  borderRadius: BorderRadius.circular(
                                      widget.itemBorderRadius),
                                  border: Border.all(
                                    color: isDark
                                        ? const Color(0x0DFFFFFF)
                                        : const Color(0x0D000000),
                                    width: 0.5,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        Listener(
                          onPointerDown: (event) {
                            _isDragging = true;
                            _isDraggingNotifier.value = true;
                            _hasStretched = false;
                            _initialLocalPosition = event.localPosition;
                            _initialScrollOffset = scrollCtrl.hasClients
                                ? scrollCtrl.offset
                                : 0.0;
                            _updateHoveredIndex(event.localPosition);
                          },
                          onPointerMove: (event) {
                            if (_isDragging) {
                              _updateHoveredIndex(event.localPosition);
                            }
                          },
                          onPointerUp: (event) {
                            if (_isDragging) {
                              final currentOffset = scrollCtrl.hasClients
                                  ? scrollCtrl.offset
                                  : 0.0;
                              final scrollDisplacement =
                                  (currentOffset - _initialScrollOffset).abs();
                              final dragDisplacement =
                                  (event.localPosition - _initialLocalPosition)
                                      .distance;

                              if (scrollDisplacement < 10 &&
                                  dragDisplacement < 10 &&
                                  !_isScrollable) {
                                final indexToTap = _hoveredIndex ??
                                    _calculateIndexFromPosition(
                                        event.localPosition, context);
                                if (indexToTap != null) {
                                  final item = widget.items[indexToTap];
                                  if (item is GlassMenuItem && item.enabled) {
                                    _closeMenu();
                                    item.onTap();
                                  }
                                }
                              }
                              _isDragging = false;
                              _isDraggingNotifier.value = false;
                              _hoveredIndex = null;
                              _hoveredIndexNotifier.value = null;
                              _hasStretched = false;
                            }
                          },
                          onPointerCancel: (_) {
                            _isDragging = false;
                            _isDraggingNotifier.value = false;
                            _hoveredIndex = null;
                            _hoveredIndexNotifier.value = null;
                          },
                          child: SizedBox(
                            width: widget.menuWidth,
                            height: targetHeight,
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              child: SingleChildScrollView(
                                controller: scrollCtrl,
                                physics: _isScrollable
                                    ? const ClampingScrollPhysics()
                                    : const NeverScrollableScrollPhysics(),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    const SizedBox(height: 12),
                                    ..._buildWrappedItems()
                                        .asMap()
                                        .entries
                                        .expand((entry) {
                                      return [
                                        entry.value,
                                        if (entry.key <
                                            widget.items.length - 1)
                                          const SizedBox(height: 2),
                                      ];
                                    }),
                                    const SizedBox(height: 12),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );

    return glassContent;
  }

  List<Widget> _buildWrappedItems() {
    return _cachedWrappedItems ??= widget.items.asMap().entries.map((entry) {
      final item = entry.value;

      if (item is GlassMenuItem) {
        return _SelectionItemWrapper(
          index: entry.key,
          hoverNotifier: _hoveredIndexNotifier,
          dragNotifier: _isDraggingNotifier,
          builder: (context, isSelected, isPressed) {
            return GlassMenuItem(
              key: item.key ?? ValueKey(item.title),
              title: item.title,
              subtitle: item.subtitle,
              icon: item.icon,
              isDestructive: item.isDestructive,
              enabled: item.enabled,
              trailing: item.trailing,
              height: item.height,
              titleStyle: item.titleStyle,
              subtitleStyle: item.subtitleStyle,
              iconColor: item.iconColor,
              iconSize: item.iconSize,
              maxLines: item.maxLines,
              isSelected: isSelected,
              isPressed: isPressed,
              onTap: () {
                if (_isScrollable && item.enabled) {
                  _closeMenu();
                  item.onTap();
                }
              },
            );
          },
        );
      }
      return item;
    }).toList();
  }

  bool get _isScrollable {
    final visibleHeight = _calculateMenuHeight();
    final itemHeights = widget.items.fold<double>(
      0.0,
      (sum, item) => sum + _getScaledItemHeight(item, context),
    );
    final gaps = (widget.items.length - 1) * 2.0;
    final naturalHeight = itemHeights + 24.0 + gaps;
    return widget.menuHeight != null || visibleHeight < naturalHeight - 1.0;
  }

  /// Accounts for system text scaling.
  ///
  /// When the user increases the system text size, GlassMenuItem renders
  /// with scaled text inside a ConstrainedBox (minHeight). The text content
  /// may push the actual height beyond the nominal [GlassMenuItem.height].
  /// This method estimates the rendered height to prevent the menu from
  /// becoming scrollable when it shouldn't be.
  double _getScaledItemHeight(Widget item, BuildContext context) {
    final mediaQuery = MediaQuery.maybeOf(context);
    final textScaler = mediaQuery?.textScaler ?? TextScaler.noScaling;

    if (item is GlassMenuItem) {
      // The item has 8px vertical padding top + bottom = 16px fixed chrome.
      // The remaining space is text content that scales with system text size.
      const fixedPadding = 16.0;
      final baseFontSize = item.titleStyle?.fontSize ?? 17.0;
      final scaledFontSize = textScaler.scale(baseFontSize);
      final lineHeight = scaledFontSize * 1.2; // Approximate line height
      final textHeight = lineHeight * item.maxLines;

      // Subtitle adds another scaled line
      double subtitleHeight = 0;
      if (item.subtitle != null) {
        final subFontSize = item.subtitleStyle?.fontSize ?? 13.0;
        subtitleHeight = textScaler.scale(subFontSize) * 1.2;
      }

      final contentHeight = textHeight + subtitleHeight + fixedPadding;
      // Use the larger of nominal height or scaled content height
      return math.max(item.height, contentHeight);
    }
    // Dividers and labels don't contain user-facing scaled text
    if (item is GlassMenuDivider) return item.height;
    if (item is GlassMenuLabel) return item.height;
    return 44.0;
  }

  double _getItemOffset(int index, BuildContext context) {
    double offset = 12.0; // Top padding
    for (int i = 0; i < index; i++) {
      offset += _getScaledItemHeight(widget.items[i], context) +
          2.0; // height + 2px gap
    }
    return offset;
  }

  int? _calculateIndexFromPosition(Offset localPosition, BuildContext context) {
    final visibleHeight = _calculateMenuHeight();
    final x = localPosition.dx;
    final dy = localPosition.dy;
    final scrollCtrl = _scrollController;
    final y =
        dy + (scrollCtrl.hasClients ? scrollCtrl.offset : 0.0);

    final isWithinActiveZone = x > -20 &&
        x < widget.menuWidth + 20 &&
        dy > -20 &&
        dy < visibleHeight + 20;

    if (!isWithinActiveZone) return null;

    double currentOffset = 12.0;
    for (int i = 0; i < widget.items.length; i++) {
      final item = widget.items[i];
      final itemHeight = _getScaledItemHeight(item, context);

      if (y >= currentOffset && y <= currentOffset + itemHeight) {
        if (item is GlassMenuItem && item.enabled) {
          return i;
        }
        break;
      }
      currentOffset += itemHeight + 2.0; // height + 2px gap
    }
    return null;
  }

  void _updateHoveredIndex(Offset localPosition) {
    // Detect if we've moved into "stretch territory" (outside visible menu bounds)
    // We use the visible container height if fixed, otherwise the natural height.
    final visibleHeight = _calculateMenuHeight();
    final x = localPosition.dx;
    final dy = localPosition.dy;

    // We add a 100px buffer to allow for intense liquid stretching without accidental closure.
    // We also allow cancelling the stretch if the user moves their finger back.
    final outsideBounds = dy < -100 ||
        dy > visibleHeight + 100 ||
        x < -100 ||
        x > widget.menuWidth + 100;

    if (_hasStretched != outsideBounds) {
      setState(() => _hasStretched = outsideBounds);
    }

    int? detectedIndex;

    // Only calculate hover selection for non-scrollable menus (slide-to-select).
    if (!_isScrollable) {
      detectedIndex = _calculateIndexFromPosition(localPosition, context);
    }

    _hoveredIndex = detectedIndex;
    _hoveredIndexNotifier.value = detectedIndex;
  }
}

/// Internal helper to update selection state for cached items.
class _SelectionItemWrapper extends StatelessWidget {
  final int index;
  final ValueNotifier<int?> hoverNotifier;
  final ValueNotifier<bool> dragNotifier;
  final Widget Function(BuildContext context, bool isSelected, bool isPressed)
      builder;

  const _SelectionItemWrapper({
    required this.index,
    required this.hoverNotifier,
    required this.dragNotifier,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int?>(
      valueListenable: hoverNotifier,
      builder: (context, hoveredIndex, _) {
        final isSelected = hoveredIndex == index;
        return ValueListenableBuilder<bool>(
          valueListenable: dragNotifier,
          builder: (context, isDragging, _) {
            return builder(context, isSelected, isDragging && isSelected);
          },
        );
      },
    );
  }
}
