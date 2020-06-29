CC = gcc
LD = gcc

SOURCES = SSD1306_OLED_Library/SSD1306_OLED.c Example_Code/Main.c Example_Code/example_app.c I2C_Library/I2C.c
OBJS := $(SOURCES:.c=.o)
CPPFLAGS := -I SSD1306_OLED_Library -I I2C_Library
CFLAGS := -g

ssd: $(OBJS)
	$(CC) $^ -o $@

clean:
	rm -rf ssd $(OBJS)
