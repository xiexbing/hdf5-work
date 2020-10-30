rm ior-uniform *.data
gcc -Wall -lm -o ior-uniform ior-uniform.c

rm ior-poisson controlled-poisson 
gcc -Wall -lm -o ior-poisson ior-poisson.c
gcc -Wall -lm -o controlled-poisson controlled-poisson.c

