#!/bin/bash
file=$(find . | grep "imagebuilder-.*x86_64.tar.xz" | head -n 1)
cp $file ./IMAGEBUILDER/imagebuilder.tar.xz
cd IMAGEBUILDER
tar -xvf imagebuilder.tar.xz
mv $(basename $file .tar.xz) imagebuilder
rm -rf imagebuilder.tar.xz