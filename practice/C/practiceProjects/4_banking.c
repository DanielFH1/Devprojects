#include <stdio.h>

void checkBalance(float balance); //잔금확인
float deposit(); //예금
float withdraw(float balance); //출금

int main(){

    int choice = 0;
    float balance = 0.0f;
    printf("*****Welcome to the bank! ******");
    do{
        printf("\nSelect an option:\n");
        printf("\n1. Check Balance\n");
        printf("2. Deposit Money\n");
        printf("3. Withdraw Money\n");
        printf("4. Exit\n");
        printf("\nEnter your choice: ");
        scanf("%d",&choice);

        switch(choice){
            case 1: //잔금 확인
                checkBalance(balance);
                break;
            case 2: //입금
                balance += deposit();
                break;
            case 3: //출금
                balance -= withdraw(balance);
                break;
            case 4:
                printf("\nThank u for using the bank!\n");
                break;
            default:
                printf("\nInvalid choice! Please select 1~4");
        }

    }while(choice != 4);
    return 0;
}

void checkBalance(float balance){
    printf("Your current balance is : %.2f\n",balance);
}

float deposit(){
    float amount = 0.0f;
    printf("\nEnter amount to deposit: $");
    scanf("%f",&amount);

    if(amount < 0){
        printf("Invalid amount\n");
        return 0.0f;
    }
    else{
        printf("Successfully deposited $%.2f\n",amount);
        return amount;
    }
    return 0.0f;
}

float withdraw(float balance){
    float amount = 0.0f;
    printf("\nEnter amount to withdraw: $");
    scanf("%f",&amount);

    if(amount<0){
        printf("Invalid amount\n");
        return 0.0f;
    }
    else if(amount >balance){
        printf("Insufficient funds! Your balance is $%.2f\n",balance);
        return 0.0f;
    }
    else{
        printf("Successfully withdrew $%.2f\n",amount);
        return amount;
    }
    return 0.0f;
}