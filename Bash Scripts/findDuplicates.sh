#!/bin/bash


echo "Enter the CSV file name: "
read file_name


sort -u -t ',' -k 1,999 "$file_name" > "temp.csv"


original_lines=$(wc -l < "$file_name")
new_lines=$(wc -l < "temp.csv")
deleted_lines=$((original_lines - new_lines))


mv "temp.csv" "$file_name"

echo "Deleted $deleted_lines duplicate entries from $file_name."
