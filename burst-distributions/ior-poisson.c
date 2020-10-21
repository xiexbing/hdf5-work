#include <stdio.h>              
#include <stdlib.h>            
#include <math.h>  
#include <time.h>


int    poisson(double x);       
int *  poisson_array(int n, double mean, double diff);
double expon(double x);         
double rand_val(int seed);
int     evaluate_diff(int * burst_sizes, int n);
double  evaluate_mean(int * burst_sizes, int n);



int main(void)
{
    /*
    input parameters:
        n:    the number of processes
        mean: the mean burst size

    output file:    
        poisson_bursts.data
    */


    int n = 42;
    double mean = 1048576*9;
    double diff = 100;

    //the array of burst sizes 
    int *burst_sizes;

    //the output file for poisson bursts
    FILE *f;
    
    //loop counter for burst in burst_sizes;
    int i;
    
    /* set the seed */
    srand( (unsigned)time( NULL ) );
    
    burst_sizes = calloc(n, sizeof(int) );
    burst_sizes = poisson_array(n, mean, diff);
    
    f = fopen("poisson_bursts.data", "w");
    
    if(f) {
        for (i = 0; i <n; i++) {
            fprintf(f, "%d \n", burst_sizes[i]);
        }
    }

    fclose(f);
    free(burst_sizes);

    return 0;

}


int * poisson_array(int n, double mean, double diff) {
    int *burst_sizes = malloc (sizeof (int) * n);
    double curr_diff = diff + 1;
    int i;

    for (i = 0; i < n; i++) {
        burst_sizes[i] = poisson(1.0 / mean);
        printf("ith burst: %d %d \n", i, burst_sizes[i]);
    }

    curr_diff = evaluate_diff(burst_sizes, n);

    double curr_mean = evaluate_mean(burst_sizes, n);

    printf("input mean curr mean: %lf %lf \n", mean, curr_mean);
    printf("input diff curr diff: %lf %lf \n", diff, curr_diff);

    return burst_sizes;
}


int poisson(double x) {
    int    poi_value;             // Computed Poisson value to be returned
    double t_sum;                 // Time sum value

    // Loop to generate Poisson values using exponential distribution
    poi_value = 0;
    t_sum = 0.0;

    while(1){
        t_sum = t_sum + expon(x);
        if (t_sum >= 1.0) break;
        poi_value++;
    }
  
    return poi_value;
}

double expon(double x) {
    double z;                     // Uniform random number (0 < z < 1)
    double exp_value;             // Computed exponential value to be returned

    // Pull a uniform random number (0 < z < 1)
    do
    {
        z = rand_val(0);
    }
    while ((z == 0) || (z == 1));
  
        // Compute exponential random variable using inversion method
        exp_value = -x * log(z);
  
    return(exp_value);
}

double rand_val(int seed)
{
    const long  a =      16807;  // Multiplier
    const long  m = 2147483647;  // Modulus
    const long  q =     127773;  // m div a
    const long  r =       2836;  // m mod a
    long x;               // Random int value
    long        x_div_q;         // x divided by q
    long        x_mod_q;         // x modulo q
    long        x_new;           // New x value

    // Set the seed if argument is non-zero and then return zero
    if (seed > 0) {
        x = seed;
        return(0.0);
    }
  
    // RNG using integer arithmetic
    x = rand();
    x_div_q = x / q;
    x_mod_q = x % q;
    x_new = (a * x_mod_q) - (r * x_div_q);
    if (x_new > 0)
        x = x_new;
    else
        x = x_new + m;
  
    // Return a random value between 0.0 and 1.0
    return((double) x / m);
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

