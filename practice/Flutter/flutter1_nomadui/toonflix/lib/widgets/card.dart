import 'package:flutter/material.dart';

class CurrencyCard extends StatelessWidget {
  final String name, code, amount;
  final IconData icon;
  final bool isInverted;

  final blackColor = const Color(0xFF1f2123);

  const CurrencyCard({
    super.key,
    required this.name,
    required this.code,
    required this.amount,
    required this.icon,
    required this.isInverted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      // 첫번째 카드
      clipBehavior: Clip.hardEdge, //overflow된 부분 숨겨주게
      decoration: BoxDecoration(
        color: isInverted ? Colors.white : blackColor,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                      color: isInverted ? blackColor : Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w600),
                ),
                SizedBox(
                  height: 10,
                ),
                Row(
                  children: [
                    Text(amount,
                        style: TextStyle(
                          color: isInverted ? blackColor : Colors.white,
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        )),
                    SizedBox(
                      width: 10,
                    ),
                    Text(
                      code,
                      style: TextStyle(
                        color: isInverted
                            ? blackColor
                            : Colors.white.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    )
                  ],
                )
              ],
            ),
            Transform.scale(
                //카드는 놔두고 아이콘 크기만 변경하려고
                scale: 2, //아이콘 크기 몇배로?
                child: Transform.translate(
                  offset: Offset(-5, 10), //아이콘 x,y 좌표만큼 움직이기
                  child: Icon(
                    icon,
                    color: isInverted ? blackColor : Colors.white,
                    size: 80,
                  ),
                ))
          ],
        ),
      ),
    );
  }
}
