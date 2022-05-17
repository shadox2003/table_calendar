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
  final Function(CalendarController gestureController)? onGestureController;
  final void Function(PageController pageController)? onCalendarCreated;
  final Function(DateTime day)? onTapDay;
  final Function(DateTime day)? onLongTapDay;
  final Function(AnimationStatus status)? onAnimationFinish;
  final bool enableGestureAnimation;

  TableCalendarBase({
    Key? key,
    required this.firstDay,
    required this.lastDay,
    required this.focusedDay,
    this.calendarFormat = CalendarFormat.month,
    this.dowBuilder,
    this.onTapDay,
    this.onLongTapDay,
    required this.dayBuilder,
    this.dowHeight,
    required this.rowHeight,
    this.sixWeekMonthsEnforced = false,
    this.dowVisible = true,
    this.enableGestureAnimation = true,
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
      CalendarFormat.week: 'Week',
    },
    this.onVerticalSwipe,
    this.onPageChanged,
    this.onCalendarCreated,
    this.onGestureController,
    this.onAnimationFinish,
  })  : assert(!dowVisible || (dowHeight != null && dowBuilder != null)),
        assert(isSameDay(focusedDay, firstDay) || focusedDay.isAfter(firstDay)),
        assert(isSameDay(focusedDay, lastDay) || focusedDay.isBefore(lastDay)),
        super(key: key);

  @override
  _TableCalendarBaseState createState() => _TableCalendarBaseState();
}

class _TableCalendarBaseState extends State<TableCalendarBase> with SingleTickerProviderStateMixin {
  late double _pageHeight;
  late final PageController _pageController;
  late DateTime _focusedDay;
  late int _previousIndex;
  late bool _pageCallbackDisabled;
  AnimationController? _controller;
  late double _oldHeight;
  Animation? _animation;
  late final ValueNotifier<double> realHeight;
  bool isDrag = false;
  bool dragCancel = false;
  CalendarFormat _format = CalendarFormat.month;
  late SwipeDirection _direction;
  CalendarController? _calendarController;
  // 用户选中的日期
  late DateTime _selectedDay;
  double _offsetY = -1;

  @override
  void initState() {
    super.initState();
    _focusedDay = widget.focusedDay;
    _selectedDay = widget.focusedDay;
    _format = widget.calendarFormat;
    final rowCount = _getRowCount(_format, _focusedDay);
    _pageHeight = _getPageHeight(rowCount);
    _oldHeight = _pageHeight;
    realHeight = ValueNotifier(_pageHeight);

    final initialPage = _calculateFocusedPage(_format, widget.firstDay, _focusedDay);

    _pageController = PageController(initialPage: initialPage);
    widget.onCalendarCreated?.call(_pageController);

    _previousIndex = initialPage;
    _pageCallbackDisabled = false;
    _controller = AnimationController(vsync: this, duration: widget.formatAnimationDuration);
    _controller!.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _animation = null;
        _controller!.reset();
        if (_isSameMonth(_focusedDay, _selectedDay) && _format == CalendarFormat.month) {
          _focusedDay = _selectedDay;
          widget.onPageChanged?.call(_focusedDay);
        }
        _oldHeight = realHeight.value;
        isDrag = false;
        // print("offset: $_offsetY, isDrag: $isDrag, $_format, focuseDay=$_focusedDay, _selectedDay = $_selectedDay");
      }
      if (widget.onAnimationFinish != null) widget.onAnimationFinish!(status);
    });
    _controller!.addListener(() {
      if (_animation != null) {
        realHeight.value = _animation!.value;
      }
    });

    if (widget.onGestureController != null) {
      _calendarController = CalendarController(
        onVerticalDragDown: _onDragDown,
        onVerticalDragUpdate: _onDragUpdate,
        onVerticalDragEnd: _onDragEnd,
        updateSelectedDay: (day) {
          _selectedDay = DateTime.utc(day.year, day.month, day.day); // 防止和日历日期不一致
          _offsetY = _getOffsetY();
        },
      );
      widget.onGestureController!(_calendarController!);
    }
    _offsetY = _getOffsetY();
  }

  @override
  void didUpdateWidget(TableCalendarBase oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (_focusedDay != widget.focusedDay ||
        widget.calendarFormat != oldWidget.calendarFormat ||
        widget.startingDayOfWeek != oldWidget.startingDayOfWeek) {
      bool shouldAnimate = _focusedDay != widget.focusedDay;
      _focusedDay = widget.focusedDay;
      _format = widget.calendarFormat;
      _updatePage(shouldAnimate: shouldAnimate);
    }

    if (widget.rowHeight != oldWidget.rowHeight ||
        widget.dowHeight != oldWidget.dowHeight ||
        widget.dowVisible != oldWidget.dowVisible ||
        widget.sixWeekMonthsEnforced != oldWidget.sixWeekMonthsEnforced) {
      final rowCount = _getRowCount(_format, _focusedDay);
      _pageHeight = _getPageHeight(rowCount);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _controller?.dispose();
    super.dispose();
  }

  bool _isSameMonth(DateTime d1, DateTime d2) {
    return d1.month == d2.month && d1.year == d2.year;
  }

  bool get _canScrollHorizontally =>
      widget.availableGestures == AvailableGestures.all ||
      widget.availableGestures == AvailableGestures.horizontalSwipe;

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
    _pageHeight = _getPageHeight(rowCount);
    if (_animation == null && isDrag == false) {
      _startAnimation(_oldHeight, _pageHeight);
      _oldHeight = _pageHeight;
    } else {
      isDrag = false;
    }
    _pageCallbackDisabled = false;
  }

  void _onDragDown() {
    isDrag = true;
    _offsetY = _getOffsetY();
  }

  void _onDragUpdate(double offsetY, double direction) {
    final double _monthHeight = _getPageHeight(_getRowCount(CalendarFormat.month, _focusedDay));
    final double _week = _getPageHeight(_getRowCount(CalendarFormat.week, _focusedDay));
    _direction = direction > 0 ? SwipeDirection.down : SwipeDirection.up;
    if (_format == CalendarFormat.week) {
      // 如果是周视图往上滑动不做任何操作
      if (_direction == SwipeDirection.up) {
        dragCancel = true;
        return;
      }
      setState(() {
        /// 周视图下拉更新显示
        _format = CalendarFormat.month;
        _offsetY = _getOffsetY();
      });
      _updatePage();
    }
    final double _temp = realHeight.value + offsetY;
    if (_temp >= _monthHeight || _temp <= _week) {
      return;
    }
    realHeight.value = _temp;
    _oldHeight = _temp;
  }

  void _startAnimation(double from, double to) {
    _animation = Tween<double>(
      begin: from,
      end: to,
    ).animate(_controller!);
    _controller?.forward();
  }

  void _onDragEnd() {
    if (dragCancel) {
      dragCancel = false;
      return;
    }
    bool cross = false;
    final double _monthHeight = _getPageHeight(_getRowCount(CalendarFormat.month, _focusedDay));
    final double _twoWeek = _getPageHeight(2);
    final double _week = _getPageHeight(_getRowCount(CalendarFormat.week, _focusedDay));
    if (widget.calendarFormat == CalendarFormat.week && _oldHeight > _week * 1.5) {
      cross = true;
    } else if (widget.calendarFormat == CalendarFormat.month && _oldHeight < _twoWeek && _oldHeight > _week * 1.5) {
      cross = true;
    } else {
      if (widget.calendarFormat == CalendarFormat.week && _direction == SwipeDirection.up) {
        setState(() {
          _format = CalendarFormat.week;
        });
        _updatePage();
        _startAnimation(_oldHeight, _week);
        return;
      } else if (widget.calendarFormat == CalendarFormat.month && _direction == SwipeDirection.down) {
        _startAnimation(_oldHeight, _monthHeight);
        return;
      }
    }
    if (widget.onVerticalSwipe != null) {
      widget.onVerticalSwipe!(_direction, cross);
    }
    isDrag = false;
  }

  DateTime _getBaseDay(CalendarFormat format, int pageIndex) {
    DateTime day = DateTime.utc(widget.firstDay.year, widget.firstDay.month + pageIndex);

    if (day.isBefore(widget.firstDay)) {
      day = widget.firstDay;
    } else if (day.isAfter(widget.lastDay)) {
      day = widget.lastDay;
    }

    return day;
  }

  List<DateTime> _daysInRange(DateTime first, DateTime last) {
    final dayCount = last.difference(first).inDays + 1;
    return List.generate(
      dayCount,
      (index) => DateTime.utc(first.year, first.month, first.day + index),
    );
  }

  DateTimeRange _daysInMonth(DateTime focusedDay) {
    final first = _firstDayOfMonth(focusedDay);
    final daysBefore = _getDaysBefore(first);
    final firstToDisplay = first.subtract(Duration(days: daysBefore));

    if (widget.sixWeekMonthsEnforced) {
      final end = firstToDisplay.add(const Duration(days: 42));
      return DateTimeRange(start: firstToDisplay, end: end);
    }

    final last = _lastDayOfMonth(focusedDay);
    final daysAfter = _getDaysAfter(last);
    final lastToDisplay = last.add(Duration(days: daysAfter));

    return DateTimeRange(start: firstToDisplay, end: lastToDisplay);
  }

  double _getOffsetY() {
    DateTime _temp = _focusedDay;
    if (_format == CalendarFormat.month) {
      if (_isSameMonth(_focusedDay, _selectedDay)) _temp = _selectedDay;
    }
    final currentIndex = _calculateFocusedPage(CalendarFormat.month, widget.firstDay, _temp);
    final baseDay = _getBaseDay(CalendarFormat.month, currentIndex);
    final visibleRange = _daysInMonth(baseDay);
    final visibleDays = _daysInRange(visibleRange.start, visibleRange.end);
    int numbers = visibleDays.indexOf(_temp);

    double offsetY = 0;

    final List<double> row = [-1, -0.5, 0, 0.5, 1];
    final List<double> row2 = [-1, -0.6, -0.2, 0.2, 0.6, 1];
    if (numbers % 7 == 0) numbers += 1;
    int line = numbers ~/ 7;
    if (numbers % 7 > 0) {
      line++;
    }

    final rowAmount = visibleDays.length ~/ 7;

    if (rowAmount == 6) {
      offsetY = row2[line - 1];
    } else {
      if (line - 1 < 0) {
        return row.first;
      }
      offsetY = row[line - 1];
    }
    return offsetY;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double _monthHeight = _getPageHeight(_getRowCount(CalendarFormat.month, _focusedDay));
        final double _week = _getPageHeight(_getRowCount(CalendarFormat.week, _focusedDay));
        double overflowBoxHeight = _format == CalendarFormat.week ? _week : _monthHeight;
        //print("offset: $_offsetY, isDrag: $isDrag $overflowBoxHeight, $_format, focuseDay=$_focusedDay, _selectedDay = $_selectedDay");
        return GestureDetector(
          onVerticalDragUpdate: (detail) {
            if (widget.enableGestureAnimation) _onDragUpdate(detail.delta.dy, detail.delta.direction);
          },
          onVerticalDragEnd: (detail) {
            if (widget.enableGestureAnimation) _onDragEnd();
          },
          onVerticalDragStart: (detail) {
            if (widget.enableGestureAnimation) _onDragDown();
          },
          onVerticalDragCancel: () {
            if (widget.enableGestureAnimation) isDrag = false;
          },
          child: ValueListenableBuilder<double>(
            valueListenable: realHeight,
            builder: (context, value, child) {
              return ClipRect(
                clipper: _Clipper(value),
                child: Container(
                  height: value,
                  child: child,
                ),
              );
            },
            child: OverflowBox(
              minHeight: _week,
              maxHeight: overflowBoxHeight,
              alignment: Alignment(0, _offsetY),
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
                    DateTime temp = focusedMonth;
                    if (!isSameDay(_focusedDay, focusedMonth)) {
                      _focusedDay = focusedMonth;
                      if (_isSameMonth(_focusedDay, _selectedDay) && _format == CalendarFormat.month) {
                        _focusedDay = _selectedDay;
                        temp = _selectedDay;
                        _offsetY = _getOffsetY();
                      }
                    }

                    if (_format == CalendarFormat.month &&
                        !widget.sixWeekMonthsEnforced &&
                        !constraints.hasBoundedHeight) {
                      final rowCount = _getRowCount(
                        _format,
                        focusedMonth,
                      );
                      final double tempHeight = _getPageHeight(rowCount);
                      if (tempHeight != _pageHeight) {
                        _pageHeight = tempHeight;
                        realHeight.value = _pageHeight;
                        _oldHeight = _pageHeight;
                      }
                    }

                    _previousIndex = index;
                    widget.onPageChanged?.call(temp);
                  }

                  _pageCallbackDisabled = false;
                },
                dowBuilder: widget.dowBuilder,
                dayBuilder: (context, day, focusedMonth) {
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      _selectedDay = day;
                      _offsetY = _getOffsetY();
                      if (widget.onTapDay != null) widget.onTapDay!(day);
                    },
                    onLongPress: () {
                      _selectedDay = day;
                      _offsetY = _getOffsetY();
                      if (widget.onLongTapDay != null) widget.onLongTapDay!(day);
                    },
                    child: widget.dayBuilder(context, day, focusedMonth),
                  );
                },
              ),
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

  int _getRowCount(CalendarFormat format, DateTime focusedDay) {
    if (format == CalendarFormat.week) {
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

class _Clipper extends CustomClipper<Rect> {
  final double height;

  _Clipper(this.height);

  @override
  Rect getClip(Size size) {
    return Rect.fromLTWH(0, 0, size.width, height);
  }

  @override
  bool shouldReclip(covariant _Clipper oldClipper) {
    return height != oldClipper.height;
  }
}

class CalendarController {
  final Function()? onVerticalDragDown;
  final Function(double offsetY, double direction)? onVerticalDragUpdate;
  final Function()? onVerticalDragEnd;
  final Function(DateTime selectedDay)? updateSelectedDay;

  CalendarController({
    this.onVerticalDragDown,
    this.onVerticalDragUpdate,
    this.onVerticalDragEnd,
    this.updateSelectedDay,
  });
}
