#include <stdio.h>
#include <stdlib.h> //random
#include <time.h> //seed

int main(){
    int guess; 
    int tries=0;
    int min = 1;
    int max = 100;

    printf("*** NUMBER GUESSING GAME ***\n");
    srand(time(NULL));
    int answer = (rand() % (max-min + 1))+ min;

    do{
        printf("Guess a number between %d - %d: ",min,max);
        scanf("%d",&guess);

        tries++;
        if(guess > answer){
            printf("Too High!!\n");
        }
        else if(guess < answer){
            printf("Too low!!\n");
        }
    }while(guess != answer);

    printf("The answer was %d\n",answer);
    printf("It took you %d tries", tries);

    return 0;
}