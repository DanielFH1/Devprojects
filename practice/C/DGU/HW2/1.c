#include <stdio.h>
#include <stdlib.h>

int main(void) {
    int i,j;
    int n=7;
    int mid = n/2;

    for (i=0;i<n;i++){
        for(j=0 ; j<n ; j++){
            if(abs(i - mid) + abs(j - mid) == mid){
                printf("*");
            }
            else{
                printf(" ");
            }
        }
        printf("\n");
    }

    return 0;
}
