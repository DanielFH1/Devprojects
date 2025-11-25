#include <stdio.h>

int main(){
    int a,b,c;
    int *pa= &a, *pb=&b,*pc=&c;
    int *max_ptr = pa;

    scanf("%d %d %d",&a,&b,&c);

    if(*pb > *max_ptr){
        max_ptr = pb;
    }
    if(*pc > *max_ptr){
        max_ptr = pc;
    }

    printf("최댓값: %d\n", *max_ptr);
    printf("주소: %d\n", max_ptr);
    return 0;
}