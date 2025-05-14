import pyautogui
import time

pyautogui.PAUSE = 1

# 메모장 실행 (Windows 기준)
pyautogui.hotkey('win', 'r')   # 실행 창 열기
pyautogui.write('notepad')
pyautogui.press('enter')

time.sleep(1)
pyautogui.write('I am future yourself. you dont have to worry. eventually you will make your dream.', interval=0.2)
