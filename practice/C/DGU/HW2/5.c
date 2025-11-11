#include <stdio.h>

int make_abs(int n){
    if(n<0){
        return -n;
    }
    return n;
}

int abs_compare(int a,int b){
    int abs_a = make_abs(a);
    int abs_b = make_abs(b);

    if (abs_a >= abs_b){
        return a;
    }
    else{
        return b;
    }
}

int main(void){
    int a,b,result;
    printf("두 정수를 입력하세요: ");
    scanf("%d %d",&a,&b);

    result = abs_compare(a,b);
    printf("절댓값이 더 큰 수는 %d입니다.\n",result);

    return 0;
}