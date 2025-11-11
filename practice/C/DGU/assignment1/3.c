#include <stdio.h>

int main(){
    float radius,Area,Length;
    const float PI = 3.1415;

    printf("Enter the radius: ");
    scanf("%f",&radius);

    Area = PI * radius * radius;
    Length = 2 * PI * radius;

    printf("With given radius: %.2f,\nArea: %.2f\nLength: %.2f",radius, Area,Length);

    return 0;

}