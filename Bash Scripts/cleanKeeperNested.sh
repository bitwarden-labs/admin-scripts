#!/bin/bash

# Enable tab completion for file paths
shopt -s progcomp

# Prompt the user
read -e -p "Enter the filepath for the Keeper CSV export: " csv_file
if [[ ! -f "$csv_file" ]]; then
    echo "File does not exist. Exiting..."
    exit 2
fi

# Create a temporary duplicate of the CSV file for processing
temp_file=$(mktemp "${csv_file}_temp_XXXXXX")
cp "$csv_file" "$temp_file"

# Temporarily append a newline to the end of the temp file to handle missing last line
echo >> "$temp_file"

# Get the base name of the file (without extension) and append '_conditioned'
output_file="${csv_file%.*}_cleaned.csv"

# Process the temporary file line by line
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
done < "$temp_file"

# Clean up the temporary file by deleting it
rm -f "$temp_file"
