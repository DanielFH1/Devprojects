class Human {
  final String name;
  Human({required this.name});

  void sayHello() {
    print("Hello Im $name");
  }
}

mixin class Strong {
  // mixin은 그냥 property만 가질 수 있음
  final double strength = 1500.99;
}

mixin class QuickRunner {
  void runQuick() {
    print("Runnnnnn!");
  }
}

mixin class Tall {
  final double height = 180.0;
}

enum Team { red, blue }

/* class Player extends Human {
  // Player(상속하는) : 자식, Human(상속당하는): 부모
  final Team team;

  Player({required this.team, required String name})
    : super(name: name); // super: 부모생성자 호출

  @override // 부모 속 sayHello를 재정의
  void sayHello() {
    super.sayHello(); // 부모의 sayHello 호출
    print("and I play for $team"); // 부모의 sayHello 뒤에 추가
  }
} */

class Player with Strong, QuickRunner, Tall {
  final Team team;

  Player({required this.team});
}

class Horse with Strong, QuickRunner {}

class Kid with QuickRunner {}

void main() {
  //var player = Player(team: Team.red, name: "john");
  //player.sayHello();

  var player = Player(team: Team.red);
  player.runQuick(); // QuickRunner의 runQuick 호출
}
