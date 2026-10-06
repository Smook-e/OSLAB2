#!/bin/bash

if [ $# -ne 2 ]; then
    echo "Error: Incorrect arguments."
    echo "Usage: ./restore.sh <original_dir> <malicious_dir>"
    exit 1
fi

ORIGINAL_DIR="$1"
QUARANTINE_DIR="$2"

if [ ! -d "$QUARANTINE_DIR" ]; then
    echo "Error: Quarantine directory '$QUARANTINE_DIR' does not exist."
    exit 1
fi

while true; do

    files=("$QUARANTINE_DIR"/*)


    if [ ${#files[@]} -eq 0 ]; then
        echo "No files to review."
        exit 0
    fi

    echo "Files currently in $QUARANTINE_DIR:"

    index=0
    for f in "${files[@]}"; do
        echo "  [$index] $(basename "$f")"
        ((index++))
    done

    echo ""
    echo -n "Enter the number of the file you want to review (or 'q' to quit): "
    read choice

    if [[ "$choice" == "q" || "$choice" == "Q" ]]; then
        echo "Exiting review tool."
        exit 0
    fi

    if [ -z "${files[$choice]}" ]; then
        echo "Invalid selection number. Try again."
        continue
    fi

    selected_file="${files[$choice]}"
    filename=$(basename "$selected_file")

    echo ""
    echo "Selected File: $filename"
    echo "  1) Restore this file back into $ORIGINAL_DIR"
    echo "  2) Permanently delete this file from $QUARANTINE_DIR"
    echo "  3) Go back to the list"
    echo -n "Choose an option (1-3): "
    read action

    case "$action" in
        1)
            mkdir -p "$ORIGINAL_DIR"
            mv "$selected_file" "$ORIGINAL_DIR/"
            echo "Restored $filename to $ORIGINAL_DIR."
            ;;
        2)
            rm -f "$selected_file"
            echo "$filename permanently deleted."
            ;;
        3)
            echo "Leaving file as-is."
            ;;
        *)
            echo "Invalid option. Returning to list."
            ;;
    esac
done