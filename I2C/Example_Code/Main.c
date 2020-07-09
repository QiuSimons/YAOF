/*
 * Main.c
 *
 *  Created on  : Sep 6, 2017
 *  Author      : Vinay Divakar
 *  Description : Example usage of the SSD1306 Driver API's
 *  Website     : www.deeplyembedded.org
 */

/* Lib Includes */
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <signal.h>

/* Header Files */
#include "I2C.h"
#include "SSD1306_OLED.h"
#include "example_app.h"

/* Oh Compiler-Please leave me as is */
volatile unsigned char flag = 0;

/* Alarm Signal Handler */
void ALARMhandler(int sig)
{
    /* Set flag */
    flag = 5;
}

void BreakDeal(int sig)
{
    clearDisplay();
    usleep(1000000);    
    Display();
    exit(0);
}
int main()
{
    /* Initialize I2C bus and connect to the I2C Device */
    if(init_i2c_dev(I2C_DEV0_PATH, SSD1306_OLED_ADDR) == 0)
    {
        printf("(Main)i2c-2: Bus Connected to SSD1306\r\n");
    }
    else
    {
        printf("(Main)i2c-2: OOPS! Something Went Wrong\r\n");
        exit(1);
    }

    /* Register the Alarm Handler */
    signal(SIGALRM, ALARMhandler);
    signal(SIGINT, BreakDeal);
    signal(SIGTERM, BreakDeal);    
/* Run SDD1306 Initialization Sequence */
    display_Init_seq();

    /* Clear display */
    clearDisplay();

    // draw a single pixel
//    drawPixel(0, 1, WHITE);
//    Display();
//    usleep(1000000);
//    clearDisplay();

    // draw many lines
//    testdrawline();
//    usleep(1000000);
//    clearDisplay();

    // draw rectangles
//    testdrawrect();
//    usleep(1000000);
//    clearDisplay();
/*
    // draw multiple rectangles
    testfillrect();
    usleep(1000000);
    clearDisplay();

    // draw mulitple circles
    testdrawcircle();
    usleep(1000000);
    clearDisplay();

    // draw a white circle, 10 pixel radius
    fillCircle(SSD1306_LCDWIDTH/2, SSD1306_LCDHEIGHT/2, 10, WHITE);
    Display();
    usleep(1000000);
    clearDisplay();

    // draw a white circle, 10 pixel radius
    testdrawroundrect();
    usleep(1000000);
    clearDisplay();

    // Fill the round rectangle
    testfillroundrect();
    usleep(1000000);
    clearDisplay();

    // Draw triangles
    testdrawtriangle();
    usleep(1000000);
    clearDisplay();

    // Fill triangles
    testfilltriangle();
    usleep(1000000);
    clearDisplay();

    // draw the first ~12 characters in the font
    testdrawchar();
    usleep(1000000);
    clearDisplay();

    // Display "scroll" and scroll around
    testscrolltext();
    usleep(1000000);
    clearDisplay();

    // Display Texts and Numbers
    display_texts();
    Display();
    usleep(1000000);
    clearDisplay();

    // Display miniature bitmap
    display_bitmap();
    Display();
    usleep(1000000);

    // Display Inverted image and normalize it back
    display_invert_normal();
    clearDisplay();
    usleep(1000000);
    Display();

    // Generate Signal after 20 Seconds
    alarm(20);

    // draw a bitmap icon and 'animate' movement
    testdrawbitmap_eg();
    clearDisplay();
    usleep(1000000);
    Display();

    // Good bye fellas :)
    deeplyembedded_credits();
    Display();
*/
    while(1){

	testdrawroundrect();
	usleep(1000000);
	clearDisplay();
	
	for(int i=1;i<60;i++){
        	testprintinfo();
        	Display();
        	usleep(1000000);
        	clearDisplay();
	}
	usleep(3000000);
    }

}
