#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <time.h>

int     uniform_distribution(int rangeLow, int rangeHigh);
int *   uniform_array(int n, int mean, double diff);
int     evaluate_diff(int * burst_sizes, int n);
double  evaluate_mean(int * burst_sizes, int n);


int main(int argc, char* argv[]) {
    /*
    input parameters:
        n:    the number of processes
        mean: the mean burst size
        diff: size difference between min and max bursts, unit:kb

    output file:
        uniform_bursts.data
    */

    printf("\n----Input Three Parameters for Uniform Distribution----\n"); 
    printf("\n----int n: the number of MPI ranks----\n"); 
    printf("\n----int mean: the mean of burst size of the n ranks, unit:KB----\n"); 
    printf("\n----int diff: (max - min) burst size of the n ranks, unit:KB----\n"); 


    int n, mean, diff;

    if (argc == 4) {
        printf("\n----the parameters n, mean, and diff are taken in order----\n");
        n = (int) atoi(argv[1]);
        mean = (int) atoi(argv[2]);
        diff = (int) atoi(argv[3]); 
    }
    else {
        printf("\n----ERROR:request three parameters for n, mean, and diff!!!----\n");
        printf("\n----ERROR:you input %d----\n", argc);
        exit(1); 
    }


    //the array of burst sizes 
    int *burst_sizes;
  
    //the output file for uniform bursts
    FILE *f;

    //loop counter for burst in burst_sizes;
    int i;

    /* set the seed */
    srand( (unsigned)time( NULL ) );
 
    burst_sizes = calloc(n, sizeof(int) );  
    burst_sizes = uniform_array(n, mean, diff);

    f = fopen("uniform_bursts.data", "w");

    if(f) {
        for (i = 0; i <n; i++) {
            fprintf(f, "%d \n", burst_sizes[i]);
        }
    }
 
    fclose(f);
    free(burst_sizes);

    return 0;

}


int uniform_distribution(int rangeLow, int rangeHigh) {
    int range = rangeHigh - rangeLow + 1; 
    int copies=RAND_MAX/range; 
    int limit=range*copies;    
    int myRand=-1;
    int rand_burst; 

    while( myRand<0 || myRand>=limit){
        myRand=rand();   
    }

    rand_burst = myRand/copies+rangeLow;

//    printf("array i: %d \n", rand_burst);
 
    return rand_burst;
}


int  evaluate_diff(int * burst_sizes, int n) {
    int min, max;
    int i;

    min = max = burst_sizes[0];

    for (i = 1; i < n; i++) {
        if (min > burst_sizes[i]) {
            min = burst_sizes[i];
        }
        if (max < burst_sizes[i]) {
            max = burst_sizes[i];
        }

    }

    int curr_diff = max - min;
    printf("n min max: %d %d %d \n", n, min, max);
  
    return curr_diff; 
}


double  evaluate_mean(int * burst_sizes, int n) {
    double sum = 0;
    int i;
    for (i = 0; i < n; i++) {
        sum = sum + burst_sizes[i];
    }

    double curr_mean = sum/n;

    return curr_mean; 
}


/* 
 * the mean value of per burst size, unit:KB
 * the relative std is std/mean
 */
int * uniform_array(int n, int mean, double diff) {
    int *burst_sizes = malloc (sizeof (int) * n);

    int intLow = (int) abs(mean - diff/2);
    int intHigh = (int) mean + diff/2;
    printf("uniform range low to high: %d %d \n", intLow, intHigh);
    
    int curr_diff = diff + 1;
    while (curr_diff > diff) {

        int i;
        for (i = 0; i < n; i++) { 

            burst_sizes[i] = uniform_distribution(intLow, intHigh);
        }

        curr_diff = evaluate_diff(burst_sizes, n);
    }

    double curr_mean = evaluate_mean(burst_sizes, n);

    printf("expected mean curr mean: %d %lf \n", mean, curr_mean);
    printf("expected diff curr diff: %lf %d \n", diff, curr_diff);
 
    
    return burst_sizes; 
}
