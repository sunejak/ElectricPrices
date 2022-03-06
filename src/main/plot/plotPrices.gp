#!/usr/local/bin/gnuplot --persist

# set print "-"
# print "script name        : ", ARG0
# print "first argument     : ", ARG1
# print "second argument    : ", ARG2
# print "third argument     : ", ARG3
# print "fourth argument    : ", ARG4
# print "fifth argument     : ", ARG5
# print "number of arguments: ", ARGC

TITLE = "Prices from Entsoe for ".ARG2
UNITS = "Price in ".ARG3."/".ARG4
FILE = ARG5

set timefmt "%H"
set xtics format "%H"
set title TITLE
set ylabel UNITS
set xlabel "Hour"
set xrange[0:24]
set grid
set boxwidth 0.85 relative
set style fill solid 0.7
set terminal png size 500,400
set output FILE

plot ARG1 using 1:2:3 with boxes lc variable title ""
quit

