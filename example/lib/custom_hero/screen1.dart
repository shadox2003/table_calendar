import 'package:flutter/material.dart';
import 'package:table_calendar_example/custom_hero/screen2.dart';

final TextStyle kStyle = TextStyle(
  fontSize: 16,
  color: Colors.white,
  decoration: TextDecoration.none,
);

class Screen1 extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Container(
          child: _buildBuyTicketButton(),
        ),
      ),
    );
  }

  _buildBuyTicketButton() {
    return Container(
      alignment: Alignment.bottomCenter,
      margin: EdgeInsets.all(8),
      child: BuyButton(),
    );
  }
}

class BuyButton extends StatefulWidget {
  @override
  _BuyButtonState createState() => _BuyButtonState();
}

class _BuyButtonState extends State<BuyButton> with TickerProviderStateMixin {
  String _buttonText = 'BUY TICKET';

  late AnimationController _controller;
  late Animation _roundnessAnimation;
  late Animation _widthAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: Duration(
        milliseconds: 500,
      ),
    )..addListener(() {
        setState(() {});
      });

    _roundnessAnimation = Tween(begin: 10.0, end: 25.0).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.linear,
    ));

    _widthAnimation = Tween(begin: 250.0, end: 40.0).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.linear,
    ));

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) {
            return Screen2();
          }),
        );
        _controller.reset();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _buttonText = '';
            //Starts animation
            _controller.forward();
          });
        },
        child: Hero(
          tag: "blackBox",
          flightShuttleBuilder: (
            BuildContext flightContext,
            Animation<double> animation,
            HeroFlightDirection flightDirection,
            BuildContext fromHeroContext,
            BuildContext toHeroContext,
          ) {
            final Widget toHero = toHeroContext.widget;
            return FlipcardTransition(
              flipAnim: animation,
              child: toHero,
            );
          },
          child: Container(
            width: _widthAnimation.value,
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(_roundnessAnimation.value),
            ),
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text(
              _buttonText,
              textAlign: TextAlign.center,
              style: kStyle,
            ),
          ),
        ),
      ),
    );
  }
}
