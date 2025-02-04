#!/bin/bash

# Enable tab completion for file paths
shopt -s progcomp

# Prompt the user
read -e -p "enter the filepath for the Keeper CSV export: " csv_file
if [[ ! -f "$csv_file" ]]; then
    echo "File does not exist. Exiting..."
    exit 2
fi

# Initialize a counter to keep track of lines (for skipping the header if needed)
line_counter=0
# Get the base name of the file (without extension) and append '_conditioned'
output_file="${csv_file%.*}_conditioned.csv"

# Read the CSV file line by line
while IFS= read -r line; do
    # Split the line by the comma
    first_column=$(echo "$line" | cut -d ',' -f 1)
    rest_of_line=$(echo "$line" | cut -d ',' -f 2-)

    # Replace backslash with forward slash in the first column
    modified_first_column="${first_column//\\//}"

    # Rebuild the modified line
    modified_line="$modified_first_column,$rest_of_line"

    # Write the modified line to the output file
    echo "$modified_line" >> "$output_file"
done < "$csv_file"