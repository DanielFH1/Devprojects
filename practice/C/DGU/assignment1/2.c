#include <stdio.h>

int main(){
    int num;

    printf("Enter the number: ");
    scanf("%d",&num);

    printf("%d\n",num);
    printf("%c\n",num); //숫자에 해당하는 ascii출력
    printf("%o\n",num);
    printf("%x\n",num);
    return 0;
}