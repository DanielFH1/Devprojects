#include <stdio.h>

int main(){
    int arr[3][2] = {{1,2},{5,6},{9,10}};
    int (*ptr)[2] = arr; // int 4개 묶음으로 보는 ptr

    printf("%d %d",*(*(ptr+1)+3), sizeof(ptr+1));
    return 0;
}   