#include <stdio.h>

int main(){
    int numbers[5] = {0};

    for(int i=0;i<5;i++){
        printf("Enter a score: ");
        scanf("%d", &numbers[i]);
    }

    for(int i=0;i<5;i++){
        printf("%d ",numbers[i]);
    }
    return 0; 
}