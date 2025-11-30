#include <stdio.h>
void main() {
    double a[2], *b, *c;
    b = a;
    c = b+1;

    int d = c-b;
    int e = (int)c - (int)b;

    printf("b is %d, c(b+1) is %d",b,c);
}