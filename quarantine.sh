#!/bin/bash

if [ $# -ne 3 ]; then
    echo "Usage: $0 <source_directory> <quarantine_directory> <interval-seconds>"
    exit 1
fi

# Configuration
SOURCE_DIR="$1"
QUARANTINE_DIR="$2"
INTERVAL="$3"
REGEX="\.(exe|vbs|bat|ps1|scr)$"  
FILE_LAST="directory-info.last"
FILE_NEW="directory-info.new"

mkdir -p "$QUARANTINE_DIR"

if [ ! -d "$SOURCE_DIR" ]; then
    echo "Error: Source directory '$SOURCE_DIR' was not found!"
    exit 1
fi

echo "Scanning '$SOURCE_DIR' for malicous files"


infected_count=0

ls -l "$SOURCE_DIR" > "$FILE_LAST"

first_scan=true

while true; do
    ls -l "$SOURCE_DIR" > "$FILE_NEW"
    if [ $first_scan = true ] || ! cmp -s "$FILE_LAST" "$FILE_NEW"; then
        
        if [ $first_scan = true ]; then
            echo "Running initial directory scan..."
            first_scan=false
        fi


        for file in "$SOURCE_DIR"/*; do
            if [[ "$file" =~ $REGEX ]] || grep -qiE "trojan|malware|virus|worm|ransomware" "$file"; then
                echo ""$file" is malicious and it is DELETED"
                mv "$file" "$QUARANTINE_DIR/"       
                ((infected_count++))
            fi      
        done
        echo "Scan complete. Quarantined $infected_count file(s)."
        ((infected_count=0))
        ls -l "$SOURCE_DIR" > "$FILE_LAST"
    else 
        echo "No changes detected in '$SOURCE_DIR'."
    fi
    
    # Wait before the next iteration
    sleep "$INTERVAL"
done
echo "----------------------------------------"
echo "Scan complete."
echo "Quarantined $infected_count threat(s) into '$QUARANTINE_DIR'."