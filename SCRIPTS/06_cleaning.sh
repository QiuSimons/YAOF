#!/bin/bash

rm -rf `ls | grep -v "squashfs"`
gzip -d *.gz
gzip *.img

exit 0
