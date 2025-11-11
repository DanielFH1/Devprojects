#include <stdio.h>

int main(){
    float korean, english, math;
    float mean = 0.0f;

    printf("Please type korean, english, math score: ");
    scanf("%f %f %f",&korean, &english, &math);

    mean = (korean+english+math)/3;

    printf("==== Results ====\n");
    printf("Korean: %.f, English: %.f, Math: %.f\n", korean, english, math);
    printf("Total sum : %.f\n", korean+english+math);
    printf("Mean value: %.2f\n",mean);

    return 0;
}