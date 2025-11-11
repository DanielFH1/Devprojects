#include <stdio.h>

int main(){
    double korean, english, math; //배점이 소수값도 있는 학교라 가정하여 double로 정의
    double total, mean;

    printf("Enter your korean, english, math score: ");
    scanf("%lf %lf %lf",&korean, &english, &math);

    total = korean + english + math;
    mean = total/3;

    printf("Total: %.1lf\nMean: %.1lf",total, mean); //가시성을 위해 소수점 1자리만
    return 0;
}