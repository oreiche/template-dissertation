#!/bin/sh

# dummy script, creating measurement data for plots

set -e

cat << EOF
Name      Single  Util    FPS
NDRange        n  43.5   31.0
CU2            n  43.0  116.5
CU4            n  69.0  152.0
SIMD2          n  49.0   93.0
SIMD4          n  70.0  106.0
CU2-SIMD2      n  80.0  127.0
Single         y  37.8   33.5
LB             y  18.0  529.0
EOF
