#include <stdio.h> 

int main(){ // calculator
    float num1 = 0.0f;
    float num2 = 0.0f;
    char opeartor = '\0';
    float total = 0.0f;

    printf("Enter first num: ");
    scanf("%f",&num1);
    printf("Enter the operator(+ - x /): ");
    scanf(" %c",&opeartor); // whitespace remains in ur input buffer when u use scanf -> " %c" means ignore this
    printf("Enter second num: ");
    scanf("%f",&num2);

    switch(opeartor){
        case '+':
            total = num1 + num2;
            printf("The result of %.2f + %.2f is %.2f",num1, num2, total);
            break;
        case '-':
            total = num1 - num2;
            printf("The result of %.2f - %.2f is %.2f",num1, num2, total);
            break;
        case 'x':
            total = num1 * num2;
            printf("The result of %.2f x %.2f is %.2f",num1, num2, total);
            break;
        case '/':
            total = num1 / num2;
            printf("The result of %.2f / %.2f is %.2f",num1, num2, total);
            break;
        default:
            printf("Please type the right input between +,-,*,/");
            break;
    }
    return 0;
}