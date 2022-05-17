// Copyright 2019 Aleksander Woźniak
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:sm_table_calendar/table_calendar.dart';

import '../utils.dart';

class TableBasicsExample extends StatefulWidget {
  @override
  _TableBasicsExampleState createState() => _TableBasicsExampleState();
}

class _TableBasicsExampleState extends State<TableBasicsExample> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarController? calendarController;
  double y = 0;
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('TableCalendar - Basics'),
      ),
      body: Column(
        children: [
          TableCalendar(
            firstDay: kFirstDay,
            lastDay: kLastDay,
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            enableGestureAnimation: false,
            onGestureController: (sender) {
              calendarController = sender;
            },
            selectedDayPredicate: (day) {
              // Use `selectedDayPredicate` to determine which day is currently selected.
              // If this returns true, then `day` will be marked as selected.

              // Using `isSameDay` is recommended to disregard
              // the time-part of compared DateTime objects.
              return isSameDay(_selectedDay, day);
            },
            onDaySelected: (selectedDay, focusedDay) {
              if (!isSameDay(_selectedDay, selectedDay)) {
                // Call `setState()` when updating the selected day
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              }
            },
            onFormatChanged: (format) {
              if (_calendarFormat != format) {
                // Call `setState()` when updating calendar format
                setState(() {
                  _calendarFormat = format;
                });
              }
            },
            onPageChanged: (focusedDay) {
              // No need to call `setState()` here
              _focusedDay = focusedDay;
            },
          ),
          Expanded(
            child: Listener(
              behavior: HitTestBehavior.translucent,
              //手指按下时会触发此回调
              onPointerDown: (PointerDownEvent e) {
                y = e.position.dy;
                // print("用户手指按下：${e.position.dy}");
              },
              onPointerUp: (e) {
                // 手势滑动 触发 日历的周月视图 切换
                if (_calendarFormat == CalendarFormat.month) {
                  // 展开状态
                  if (e.position.dy - y < 0) {
                    setState(() {
                      _calendarFormat = CalendarFormat.week;
                    });
                  }
                } else {
                  if (e.position.dy - y > 0) {
                    setState(() {
                      _calendarFormat = CalendarFormat.month;
                    });
                  }
                }
              },
              child: IgnorePointer(
                ignoring: true,
                child: ListView.builder(
                  itemCount: 100,
                  itemBuilder: (conte, index) => Text(index.toString()),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}
