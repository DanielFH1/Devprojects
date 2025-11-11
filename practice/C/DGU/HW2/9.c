#include <stdio.h>

int is_triangle(int a, int b, int c){// 두변의 합이 나머지 하나보다 커야
    if((a+b > c && b+c >a && a+c>b)){
        return 1;
    }
    else{
        return 0;
    }
}

char* triangle_type(int a, int b, int c){//정삼각형, 이등변, 일반
    if(a==b && b==c){
        return "정삼각형";
    }
    else if(a==b || b==c || a==c){
        return "이등변삼각형";
    }
    else{
        return "일반삼각형";
    }
}

int main(void){
    int a,b,c;
    printf("세변의 길이를 입력하세요: ");
    scanf("%d %d %d", &a, &b,&c);

    if(is_triangle(a,b,c)){
        char* type = triangle_type(a,b,c);
        printf("삼각형 가능: %s",type);
    }
    else{
        printf("삼각형을 만들 수 없습니다.");
    }
    return 0;
}