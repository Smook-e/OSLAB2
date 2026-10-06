#!/bin/bash

if [ $# -ne 2 ]; then
    echo "Usage: $0 <source_directory> <quarantine_directory>"
    exit 1
fi

# Configuration
SOURCE_DIR="$1"
QUARANTINE_DIR="$2"
INTERVAL="$3"
REGEX="\.(exe|vbs|bat|ps1|scr)$"  
FILE_LAST="$SOURCE_DIR/directory-info.last"
FILE_NEW="$SOURCE_DIR/directory-info.new"

mkdir -p "$QUARANTINE_DIR"

if [ ! -d "$SOURCE_DIR" ]; then
    exit 1
fi

ls -l "$SOURCE_DIR" > "$FILE_NEW"


if [ -f "$FILE_LAST" ] && cmp -s "$FILE_LAST" "$FILE_NEW"; then
    rm -f "$FILE_NEW"
    exit 0
fi

for file in "$SOURCE_DIR"/*; do
    if [[ "$file" == *"directory-info."* ]]; then   
        continue
    fi
    filename=$(basename "$file")
    if [[ "$file" =~ $REGEX ]] || grep -qiE "trojan|malware|virus|worm|ransomware" "$file"; then
        if [ -f "whitelist.txt" ]; then
            if grep -Fxq "$filename" "whitelist.txt"; then
                    continue
            fi
        fi
        mv "$file" "$QUARANTINE_DIR/"       
    fi      
done

ls -l "$SOURCE_DIR" > "$FILE_LAST"
rm -f "$FILE_NEW"
