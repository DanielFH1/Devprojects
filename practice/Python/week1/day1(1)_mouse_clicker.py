#마우스 위치를 input으로 받아서 10번 클릭하는 프로그램을 만들어라. 
import pyautogui
import time
import keyboard

x = int(input("x좌표 : "))
y = int(input("y좌표 : "))
count = int(input("몇번 클릭할까요?"))
delay = float(input("몇초간격으로 클릭할까요?"))

print("2초후 클릭시작! 준비하세요. ESC로 중단가능.")
time.sleep(2)

i=0
while True:
    if keyboard.is_pressed("esc"):
        print("ESC!!!!!!!!!!!! shut down!!!!")
        break
    pyautogui.click(x,y)
    i += 1
    print(f"{i}번째 클릭")
    time.sleep(0.5)


# for i in range(count):
#     pyautogui.click(x,y)
#     print(f"{i+1}번째 클릭")
#     time.sleep(delay)