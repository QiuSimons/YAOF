#!/bin/sh
echo "1" > /proc/irq/14/smp_affinity
echo "2" > /proc/irq/28/smp_affinity
echo "4" > /proc/irq/27/smp_affinity
echo "8" > /proc/irq/166/smp_affinity
exit 0
