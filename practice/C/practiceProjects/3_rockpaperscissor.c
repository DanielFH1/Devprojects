#include <stdio.h>
#include <stdlib.h>
#include <time.h>

int getComputerChoice();
int getUserChoice();
void checkWinner(int userChoice, int computerChoice);

int main(){
    srand(time(NULL));

    int computerChoice = getComputerChoice();
    int userChoice = getUserChoice();

    switch(userChoice){
        case 1:
            printf("You chose ROCK!\n");
            break;
        case 2:
            printf("You chose PAPER!\n");
            break;
        case 3:
            printf("You chose SCISSORS!\n");
            break;
    }

    switch(computerChoice){
        case 1:
            printf("Computer chose ROCK!\n");
            break;
        case 2:
            printf("Computer chose PAPER!\n");
            break;
        case 3:
            printf("Computer chose SCISSORS!\n");
            break;
    }

    checkWinner(userChoice,computerChoice);

    return 0;
}

int getComputerChoice(){
    /*int min = 1;
    int max = 3;
    srand(time(NULL));
    int compChoice = (rand() %(max-min+1)) + 1;

    return compChoice; */
    
    return (rand()%3)+1;
}

int getUserChoice(){
    int choice;

    do{
        printf("Choose an option\n");
        printf("1. ROCK\n");
        printf("2. PAPER\n");
        printf("3. SCISSOR\n");
        printf("Enter your choice between 1~3: ");
        scanf("%d",&choice);
    }while(choice<1 || choice>3);

    return choice;
}

void checkWinner(int userChoice, int computerChoice){
    if(userChoice==computerChoice){
        printf("It's a tie!!");
    }
    else if(userChoice ==1 && computerChoice==3){
        printf("You win!!");
    }
    else if(userChoice==2 && computerChoice==1){
        printf("You win!!");
    }
    else if(userChoice==3&& computerChoice==2){
        printf("You win!!");
    }
    else{
        printf("You lose :( Maybe next time");
    }
}