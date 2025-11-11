#include <stdio.h>

int findMin(int a, int b, int c){
    if(a<b && a<c){
        return a;
    }
    else if(b<a && b<c){
        return b;
    }
    else if(c<a && c<b){
        return c;
    }
}

int detectOdd(int num){
    if(num % 2 == 1){
        return 1;
    }
    else{
        return 0;
    }
}

int main(void){
    int a,b,c,min;
    printf("세 개의 정수를 입력하세요: ");
    scanf("%d %d %d",&a,&b,&c);

    min = findMin(a,b,c);
    if(detectOdd(min)){
        printf("가장 작은 수는 %d이고, 홀수입니다.\n",min);
    }
    else{
        printf("가장 작은 수는 %d이고, 짝수입니다.\n",min);
    }

    return 0;
}