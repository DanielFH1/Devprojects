#include <stdio.h>

int main(){ // 학생 수 n(1~100)이랑 점수 각각 입력받아, 총점/평균, 평균이상 학생수,
    // 최고/최저 점수 , 평균 이상인 학생의 인덱스  
    
    // 학생수 몇명인지 -> 점수 각각 입력받고 -> 총점은 sum으로, 평균은 (double)sum/n
    // for 안에 조건문 넣어서 평균이상 학생수 averageAboveNum으로 세기
    // 같은 조건문 안에 인덱스도 loop반복변수(i) 그대로 빈 배열에 넣기

    int n,sum =0,averageAboveNum=0;
    int scores[100];
    int highScores[100];

    printf("How many students are there?(1~100)");
    scanf("%d",&n);

    for (int i=0; i<n; i++){
        scanf("%d",&scores[i]);
    }

    for (int i=0; i<n;i++){
        sum += scores[i];
    }

    double mean = (double)sum/n;

    for (int i=0; i<n; i++){
        if (scores[i] > mean){
            averageAboveNum++;

        }
    }

    return 0;
}