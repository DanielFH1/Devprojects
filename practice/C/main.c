#include <stdio.h>

int main(){
    int n;
    int a[50];
    printf("How many numbers? ");
    scanf("%d",&n);

    printf("Please type %n numbers: ",n);
    for(int i=0; i<n;i++) scanf("%d ", &a[i]);

    return 0;

}