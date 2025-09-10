#include <stdio.h>

int main(){ //4153번 직각삼각형
    int a,b,c;
    while(1){
        scanf("%d %d %d",&a,&b,&c);
        if(a==0 && b==0 && c==0) break;

        int max,x,y; //새로운 변수
        if(a>=b && a>=c){
            max = a; x=b; y=c;
        }
        else if(b>=a && b>=c){
            max = b; x=a; y=c;
        }
        else{
            max = c; x=b; y=a;
        }

        if(max * max == (x *x + y*y)) printf("right\n");
        else printf("wrong\n");
    }
    return 0;
}