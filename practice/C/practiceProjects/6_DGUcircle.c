#include <stdio.h>

int main(){
    const float pi = 3.141592;
    float r;

    printf("Please type the radius of circle: ");
    scanf("%f",&r);

    float area = pi * r *r;
    float cf = 2 * pi *r;


    printf("Radius : %.2f\n", r);
    printf("Area : %.2f\n",area);
    printf("CF : %.2f\n", cf);

    return 0;
}