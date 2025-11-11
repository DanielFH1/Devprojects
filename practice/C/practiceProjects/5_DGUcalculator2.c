#include <stdio.h>

int main(){
    int a,b;
    printf("Please type two integers: ");
    scanf("%d %d", &a,&b);

    printf("==== The results ====\n");
    printf("%d + %d = %d\n",a,b,a+b);
    printf("%d - %d = %d\n",a,b,a-b);
    printf("%d * %d = %d\n",a,b,a*b);
    printf("%d / %d = %d\n",a,b,a/b);
    printf("%d %% %d = %d\n",a,b,a%b);
    return 0;
}