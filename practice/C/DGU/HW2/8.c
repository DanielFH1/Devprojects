#include <stdio.h>

int reverse_number(int n){ //숫자 뒤집기
    int reversed = 0;
    while(n>0){
        reversed = reversed * 10 + n%10;
        n /= 10;
    }
    return reversed;
}

int is_palindrome(int original, int reversed){ // 회문인지 판단
    return original == reversed;
}

int main(void){
    int num,reversed;
    printf("세 자리 정수를 입력하세요: ");
    scanf("%d",&num);

    if(num>=100 && num<=999){
        reversed = reverse_number(num);
        if(is_palindrome(num,reversed)){
            printf("뒤집은 수는 %d입니다.\n",reversed);
            printf("회문입니다.\n");
        }
        else{
            printf("뒤집은 수는 %d입니다.\n",reversed);
            printf("회문이 아닙니다.\n");
        }
    }
    else{
        printf("세 자리 정수가 아닙니다.\n");
    }
    return 0;
}