# 화면에서 스크린샷을 찍은 후, 크롬 아이콘을 편집해서 target.png로 저장하라. 그리고, target.png사진을 분석해서 그걸 클릭하는 프로그램을 작성하라
import pyautogui
import time

print("2초후 시작...")
time.sleep(2)

for i in range(9):
    location = pyautogui.locateCenterOnScreen("target.png",confidence=0.8)
    if location:
        pyautogui.click(location)
        print("이 위치를 찾아서 클릭하겠습니다" , location)
        
    else:
        print("이미지를 찾을수없습니다")


#screenshot = pyautogui.screenshot()
#screenshot.save("screenshotByPthon.png")