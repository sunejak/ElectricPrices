#!/bin/bash
# Check if a filename is provided as an argument
if [ $# -eq 0 ]; then
    echo "Usage: $0 <filename>"
    exit 1
fi
filename=$1
# Check if the file exists
if [ ! -f "$filename" ]; then
    echo "Error: File not found: $filename"
    exit 1
fi
# Read JSON file into a Bash arrays using jq
hours=($(jq -r '.sortedHour[]' "$filename"))
if [ $? -ne 0 ]; then
  echo "Not a valid JSON array (sortedHour)"
  exit 1
fi
values=($(jq -r '.price[]' "$filename"))
if [ $? -ne 0 ]; then
  echo "Not a valid JSON array (price)"
  exit 1
fi
# most expensive hour first
palett=(7 9 9 9 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 6 6 6 2)
colors=(0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0)
# 2 green, 6 blue, 7 red, 8 purple

for (( j = 0; j < 24; j++ )); do
	index=${hours["$j"]}
  colors["$index"]=${palett["$j"]}
done

# output the values for gnuplot
for (( i = 0; i < 24; i++ )); do
	echo "$i".5  ${values["$i"]}  ${colors["$i"]}
done
