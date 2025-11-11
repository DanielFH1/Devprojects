#include <stdio.h>

int main(void){
    int n,sum,step = 0;

    scanf("%d",&n);

    while(n>=10){
        sum = 0;
        while(n>0){
            sum += n%10;
            n /= 10;
        }
        n = sum;
        step++;
    }

    printf("%d %d", step+1, n);
    return 0;
}