#include <stdio.h>

int get_median(int a, int b, int c){
    if ((a>b && a<c) || (a>c && a<b)){
        return a;
    }
    else if ((b > a && b < c) || (b < a && b > c))
        return b;
    else
        return c;
}

int main(void){
    int x,y,z;
    printf("세개의 정수를 입력하세요: ");
    scanf("%d %d %d",&x,&y,&z);

    int median = get_median(x,y,z);
    printf("중앙값은 %d입니다.",median);

    return 0;
}