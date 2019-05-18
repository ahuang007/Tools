#include <time.h>
#include <iostream>

using namespace std;
 
unsigned int getMorningTime() 
{  
    time_t t = time(NULL); 
    struct tm * tm= localtime(&t);  
    tm->tm_hour = 0;  
    tm->tm_min = 0;  
    tm->tm_sec = 0;  
    return  mktime(tm);  
}  

double getCurrentTime() {
    struct timeval tv;
    gettimeofday(&tv,NULL);
    return tv.tv_sec + tv.tv_usec*1.0/1000000;
}
 
int main()
{
	cout << getMorningTime() << endl;
	return 0;
}
