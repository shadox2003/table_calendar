// Copyright 2019 Aleksander Woźniak
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:simple_gesture_detector/simple_gesture_detector.dart';

import 'shared/utils.dart';
import 'widgets/calendar_core.dart';

class TableCalendarBase extends StatefulWidget {
  final DateTime firstDay;
  final DateTime lastDay;
  final DateTime focusedDay;
  final CalendarFormat calendarFormat;
  final DayBuilder? dowBuilder;
  final FocusedDayBuilder dayBuilder;
  final double? dowHeight;
  final double rowHeight;
  final bool sixWeekMonthsEnforced;
  final bool dowVisible;
  final Decoration? dowDecoration;
  final Decoration? rowDecoration;
  final TableBorder? tableBorder;
  final Duration formatAnimationDuration;
  final Curve formatAnimationCurve;
  final bool pageAnimationEnabled;
  final Duration pageAnimationDuration;
  final Curve pageAnimationCurve;
  final StartingDayOfWeek startingDayOfWeek;
  final AvailableGestures availableGestures;
  final SimpleSwipeConfig simpleSwipeConfig;
  final Map<CalendarFormat, String> availableCalendarFormats;
  final Function(SwipeDirection direction, bool cross)? onVerticalSwipe;
  final void Function(DateTime focusedDay)? onPageChanged;
  final void Function(PageController pageController)? onCalendarCreated;

  TableCalendarBase({
    Key? key,
    required this.firstDay,
    required this.lastDay,
    required this.focusedDay,
    this.calendarFormat = CalendarFormat.month,
    this.dowBuilder,
    required this.dayBuilder,
    this.dowHeight,
    required this.rowHeight,
    this.sixWeekMonthsEnforced = false,
    this.dowVisible = true,
    this.dowDecoration,
    this.rowDecoration,
    this.tableBorder,
    this.formatAnimationDuration = const Duration(milliseconds: 200),
    this.formatAnimationCurve = Curves.linear,
    this.pageAnimationEnabled = true,
    this.pageAnimationDuration = const Duration(milliseconds: 300),
    this.pageAnimationCurve = Curves.easeOut,
    this.startingDayOfWeek = StartingDayOfWeek.sunday,
    this.availableGestures = AvailableGestures.all,
    this.simpleSwipeConfig = const SimpleSwipeConfig(
      verticalThreshold: 25.0,
      swipeDetectionBehavior: SwipeDetectionBehavior.continuousDistinct,
    ),
    this.availableCalendarFormats = const {
      CalendarFormat.month: 'Month',
      CalendarFormat.twoWeeks: '2 weeks',
      CalendarFormat.week: 'Week',
    },
    this.onVerticalSwipe,
    this.onPageChanged,
    this.onCalendarCreated,
  })  : assert(!dowVisible || (dowHeight != null && dowBuilder != null)),
        assert(isSameDay(focusedDay, firstDay) || focusedDay.isAfter(firstDay)),
        assert(isSameDay(focusedDay, lastDay) || focusedDay.isBefore(lastDay)),
        super(key: key);

  @override
  _TableCalendarBaseState createState() => _TableCalendarBaseState();
}

class _TableCalendarBaseState extends State<TableCalendarBase> with SingleTickerProviderStateMixin {
  late final ValueNotifier<double> _pageHeight;
  late final PageController _pageController;
  late DateTime _focusedDay;
  late int _previousIndex;
  late bool _pageCallbackDisabled;
  late AnimationController _controller;
  late double _oldHeight;
  Animation? _animation;
  late double realHeight;
  bool isDrag = false;
  CalendarFormat _format = CalendarFormat.month;
  late SwipeDirection _direction;

  @override
  void initState() {
    super.initState();
    _focusedDay = widget.focusedDay;
    final rowCount = _getRowCount(_format, _focusedDay);
    _pageHeight = ValueNotifier(_getPageHeight(rowCount));
    _oldHeight = _pageHeight.value;
    realHeight = _pageHeight.value;

    final initialPage = _calculateFocusedPage(_format, widget.firstDay, _focusedDay);

    _pageController = PageController(initialPage: initialPage);
    widget.onCalendarCreated?.call(_pageController);

    _previousIndex = initialPage;
    _pageCallbackDisabled = false;
    _controller = AnimationController(vsync: this, duration: widget.formatAnimationDuration);
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _animation = null;
        _controller.reset();
      }
    });
    _controller.addListener(() {
      if (_animation != null) {
        setState(() {
          realHeight = _animation!.value;
        });
      }
    });
  }

  @override
  void didUpdateWidget(TableCalendarBase oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (_focusedDay != widget.focusedDay ||
        widget.calendarFormat != oldWidget.calendarFormat ||
        widget.startingDayOfWeek != oldWidget.startingDayOfWeek) {
      final shouldAnimate = _focusedDay != widget.focusedDay;

      _focusedDay = widget.focusedDay;
      _format = widget.calendarFormat;
      _updatePage(shouldAnimate: shouldAnimate);
    }

    if (widget.rowHeight != oldWidget.rowHeight ||
        widget.dowHeight != oldWidget.dowHeight ||
        widget.dowVisible != oldWidget.dowVisible ||
        widget.sixWeekMonthsEnforced != oldWidget.sixWeekMonthsEnforced) {
      final rowCount = _getRowCount(_format, _focusedDay);
      _pageHeight.value = _getPageHeight(rowCount);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _pageHeight.dispose();
    super.dispose();
  }

  bool get _canScrollHorizontally =>
      widget.availableGestures == AvailableGestures.all ||
      widget.availableGestures == AvailableGestures.horizontalSwipe;

  bool get _canScrollVertically =>
      widget.availableGestures == AvailableGestures.all || widget.availableGestures == AvailableGestures.verticalSwipe;

  void _updatePage({bool shouldAnimate = false}) {
    final currentIndex = _calculateFocusedPage(_format, widget.firstDay, _focusedDay);

    final endIndex = _calculateFocusedPage(_format, widget.firstDay, widget.lastDay);

    if (currentIndex != _previousIndex || currentIndex == 0 || currentIndex == endIndex) {
      _pageCallbackDisabled = true;
    }

    if (shouldAnimate && widget.pageAnimationEnabled) {
      if ((currentIndex - _previousIndex).abs() > 1) {
        final jumpIndex = currentIndex > _previousIndex ? currentIndex - 1 : currentIndex + 1;

        _pageController.jumpToPage(jumpIndex);
      }

      _pageController.animateToPage(
        currentIndex,
        duration: widget.pageAnimationDuration,
        curve: widget.pageAnimationCurve,
      );
    } else {
      _pageController.jumpToPage(currentIndex);
    }

    _previousIndex = currentIndex;
    final rowCount = _getRowCount(_format, _focusedDay);
    _pageHeight.value = _getPageHeight(rowCount);
    if (_animation == null && isDrag == false) {
      _startAnimation(_oldHeight, _pageHeight.value);
      _oldHeight = _pageHeight.value;
    } else {
      isDrag = false;
    }
    _pageCallbackDisabled = false;
  }

  void _startAnimation(double from, double to) {
    _animation = Tween<double>(
      begin: from,
      end: to,
    ).animate(_controller);

    _controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double _monthHeight = _getPageHeight(_getRowCount(CalendarFormat.month, _focusedDay));
        final double _twoWeek = _getPageHeight(_getRowCount(CalendarFormat.twoWeeks, _focusedDay));
        final double _week = _getPageHeight(_getRowCount(CalendarFormat.week, _focusedDay));
        return GestureDetector(
          onVerticalDragDown: (detail) {
            isDrag = true;
          },
          onVerticalDragUpdate: (detail) {
            if (_format == CalendarFormat.week) {
              _format = CalendarFormat.month;
              _updatePage(shouldAnimate: false);
            }
            final double _temp = realHeight + detail.delta.dy;
            _direction = detail.delta.direction > 0 ? SwipeDirection.down : SwipeDirection.up;
            if (_temp >= _monthHeight || _temp <= _week) {
              return;
            }
            setState(() {
              realHeight = _temp;
            });
            _oldHeight = _temp;
          },
          onVerticalDragEnd: (detail) {
            bool cross = false;
            if (widget.calendarFormat == CalendarFormat.week && _oldHeight > _week * 1.5) {
              cross = true;
            } else if (widget.calendarFormat == CalendarFormat.month &&
                _oldHeight < _twoWeek &&
                _oldHeight > _week * 1.5) {
              cross = true;
            } else {
              if (widget.calendarFormat == CalendarFormat.week && _direction == SwipeDirection.up) {
                _format = CalendarFormat.week;
                _updatePage();
                _startAnimation(_oldHeight, _week);
              } else if (widget.calendarFormat == CalendarFormat.month && _direction == SwipeDirection.down) {
                _startAnimation(_oldHeight, _monthHeight);
              }
            }
            if (widget.onVerticalSwipe != null) {
              widget.onVerticalSwipe!(_direction, cross);
            }
            isDrag = false;
          },
          child: Container(
            color: Colors.red,
            height: realHeight,
            child: CalendarCore(
              constraints: constraints,
              pageController: _pageController,
              scrollPhysics: _canScrollHorizontally ? PageScrollPhysics() : NeverScrollableScrollPhysics(),
              firstDay: widget.firstDay,
              lastDay: widget.lastDay,
              startingDayOfWeek: widget.startingDayOfWeek,
              calendarFormat: _format,
              previousIndex: _previousIndex,
              focusedDay: _focusedDay,
              sixWeekMonthsEnforced: widget.sixWeekMonthsEnforced,
              dowVisible: widget.dowVisible,
              dowHeight: widget.dowHeight,
              rowHeight: widget.rowHeight,
              dowDecoration: widget.dowDecoration,
              rowDecoration: widget.rowDecoration,
              tableBorder: widget.tableBorder,
              onPageChanged: (index, focusedMonth) {
                if (!_pageCallbackDisabled) {
                  if (!isSameDay(_focusedDay, focusedMonth)) {
                    _focusedDay = focusedMonth;
                  }

                  if (_format == CalendarFormat.month &&
                      !widget.sixWeekMonthsEnforced &&
                      !constraints.hasBoundedHeight) {
                    final rowCount = _getRowCount(
                      _format,
                      focusedMonth,
                    );
                    _pageHeight.value = _getPageHeight(rowCount);
                  }

                  _previousIndex = index;
                  widget.onPageChanged?.call(focusedMonth);
                }

                _pageCallbackDisabled = false;
              },
              dowBuilder: widget.dowBuilder,
              dayBuilder: widget.dayBuilder,
            ),
          ),
        );
      },
    );
  }

  double _getPageHeight(int rowCount) {
    final dowHeight = widget.dowVisible ? widget.dowHeight! : 0.0;
    return dowHeight + rowCount * widget.rowHeight;
  }

  int _calculateFocusedPage(CalendarFormat format, DateTime startDay, DateTime focusedDay) {
    switch (format) {
      case CalendarFormat.month:
        return _getMonthCount(startDay, focusedDay);
      case CalendarFormat.twoWeeks:
        return _getTwoWeekCount(startDay, focusedDay);
      case CalendarFormat.week:
        return _getWeekCount(startDay, focusedDay);
      default:
        return _getMonthCount(startDay, focusedDay);
    }
  }

  int _getMonthCount(DateTime first, DateTime last) {
    final yearDif = last.year - first.year;
    final monthDif = last.month - first.month;

    return yearDif * 12 + monthDif;
  }

  int _getWeekCount(DateTime first, DateTime last) {
    return last.difference(_firstDayOfWeek(first)).inDays ~/ 7;
  }

  int _getTwoWeekCount(DateTime first, DateTime last) {
    return last.difference(_firstDayOfWeek(first)).inDays ~/ 14;
  }

  int _getRowCount(CalendarFormat format, DateTime focusedDay) {
    if (format == CalendarFormat.twoWeeks) {
      return 2;
    } else if (format == CalendarFormat.week) {
      return 1;
    } else if (widget.sixWeekMonthsEnforced) {
      return 6;
    }

    final first = _firstDayOfMonth(focusedDay);
    final daysBefore = _getDaysBefore(first);
    final firstToDisplay = first.subtract(Duration(days: daysBefore));

    final last = _lastDayOfMonth(focusedDay);
    final daysAfter = _getDaysAfter(last);
    final lastToDisplay = last.add(Duration(days: daysAfter));

    return (lastToDisplay.difference(firstToDisplay).inDays + 1) ~/ 7;
  }

  int _getDaysBefore(DateTime firstDay) {
    return (firstDay.weekday + 7 - getWeekdayNumber(widget.startingDayOfWeek)) % 7;
  }

  int _getDaysAfter(DateTime lastDay) {
    int invertedStartingWeekday = 8 - getWeekdayNumber(widget.startingDayOfWeek);

    int daysAfter = 7 - ((lastDay.weekday + invertedStartingWeekday) % 7);
    if (daysAfter == 7) {
      daysAfter = 0;
    }

    return daysAfter;
  }

  DateTime _firstDayOfWeek(DateTime week) {
    final daysBefore = _getDaysBefore(week);
    return week.subtract(Duration(days: daysBefore));
  }

  DateTime _firstDayOfMonth(DateTime month) {
    return DateTime.utc(month.year, month.month, 1);
  }

  DateTime _lastDayOfMonth(DateTime month) {
    final date = month.month < 12 ? DateTime.utc(month.year, month.month + 1, 1) : DateTime.utc(month.year + 1, 1, 1);
    return date.subtract(const Duration(days: 1));
  }
}
