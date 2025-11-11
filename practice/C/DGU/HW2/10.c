#include <stdio.h>

int is_leap_year(int year){ //윤년 여부 판단 
    if((year%4==0 && year% 100 != 0) || (year%400 ==0)){
        return 1;
    }
    else{
        return 0;
    }
}

int is_valid_date(int year, int month, int day){
    //기본 데이터 체크
    if(year<=0 || month <1 || month>12 || day <1 || day >31){
        return 0;
    }

    int days_in_month[] = {0,31,28,31,30,31,30,31,31,30,31,30,31}; // 편의를 위해 인덱스 0은 비우기

    if (month == 2 && is_leap_year(year)){//윤년이고 2월이면 -> 29일까지 
        days_in_month[2] = 29;
    }
    if(day> days_in_month[month]){
        return 0;
    }
    return 1;
}

int main(void){
    int y,m,d;
    printf("연도를 입력하세요: ");
    scanf("%d",&y);
    printf("월을 입력하세요: ");
    scanf("%d",&m);
    printf("일을 입력하세요: ");
    scanf("%d",&d);

    if(is_valid_date(y,m,d)){
        printf("유효한 날짜입니다.\n");
    }
    else{
        printf("유효하지 않은 날짜입니다.\n");
    }
    
    return 0;
}