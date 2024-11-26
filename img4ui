#!/bin/bash

# Check if ImageMagick is installed
if ! command -v convert &> /dev/null; then
    echo "Error: ImageMagick (convert) is not installed."
    exit 1
fi

# Ensure input file and variable name are provided
if [ $# -lt 2 ]; then
    echo "Usage: $0 <input_file> <variable_name>"
    exit 1
fi

# Input file and variable name setup
INPUT_FILE="$1"
TEMP_FILE="reduced.gif"
VARIABLE_NAME="$2"
OUTPUT_FILE="${VARIABLE_NAME}.ui"
MASKOUT="ff00ff"

#what are we dealing with?
identify -verbose $INPUT_FILE

# Reduce colors to 16 with optimized palette
convert $INPUT_FILE -colors 16 -type palette +dither $TEMP_FILE
identify -verbose $TEMP_FILE

# Extract width and height
WIDTH=$(identify -format "%w" $TEMP_FILE)
HEIGHT=$(identify -format "%h" $TEMP_FILE)

# Begin writing the .ui file
{
    echo "visMoniker ${VARIABLE_NAME} = {"
    echo "    size = standard;"
    echo "    style = icon;"
    echo "    aspectRatio = normal;"
    echo "    color = color4;"
    echo "    cachedSize = $WIDTH, $HEIGHT;"
    echo "    gstring {"
    echo "        GSBeginString"
    echo "        GSDrawBitmapAtCP <(${VARIABLE_NAME}End - ${VARIABLE_NAME}Start)>"
    echo "        ${VARIABLE_NAME}Start	label	byte"
    echo "        CBitmap <<$WIDTH,$HEIGHT,BMC_UNCOMPACTED,BMF_4BIT or mask BMT_MASK or mask BMT_PALETTE or mask BMT_COMPLEX>, 0, $HEIGHT, 0, 70, 20, 72, 72>"
    echo "        word    16"
} > "$OUTPUT_FILE"

# Extract and reorder the palette, ensure reverse mapping
identify -verbose $TEMP_FILE | awk '
/Colormap:/ { 
    in_colormap = 1; 
    next 
}
/^  [ ]*[0-9]+:/ && in_colormap {
    # Extract color index and RGB values from the colormap section
    match($0, /[0-9]+: \([^)]+\) #[0-9A-Fa-f]+/, line)
    split(line[0], fields, ": ")
    idx = fields[1]
    color = substr(fields[2], match(fields[2], /#[0-9A-Fa-f]+/)+1, 6)
    r = substr(color, 1, 2)
    g = substr(color, 3, 2)
    b = substr(color, 5, 2)
    palette[idx] = sprintf("        RGBValue < 0x%s, 0x%s, 0x%s >", tolower(r), tolower(g), tolower(b))
    color_to_index[tolower(color)] = idx # Reverse mapping of color to index
}
END {
    # Output the palette entries, padding with black if less than 16
    for (i = 0; i < 16; i++) {
        if (i in palette) {
            print palette[i]
        } else {
            print "        RGBValue < 0x00, 0x00, 0x00 >"
        }
    }
}' > palette.tmp

# Write the palette data to the .ui file
cat palette.tmp >> "$OUTPUT_FILE"

# Extract pixel data in 4-bit format, perform reverse lookup
convert $TEMP_FILE -depth 8 rgb:- | xxd -p -c "$((WIDTH * 3))" | awk -v width="$WIDTH" -v maskout="$MASKOUT" '
BEGIN {
    valid_count = 0  # Initialize the valid entry counter
    maskout_index = -1  # Placeholder for the transparent color index

    # Load the palette
    while ((getline line < "palette.tmp") > 0) {
        match(line, /[[:space:]]*RGBValue < 0x([0-9a-fA-F]{2}),[[:space:]]*0x([0-9a-fA-F]{2}),[[:space:]]*0x([0-9a-fA-F]{2}) >[[:space:]]*/, matches)
        if (RSTART) {
            red = matches[1]
            green = matches[2]
            blue = matches[3]
            color = tolower(red green blue)

            # Only add unique colors
            if (!(color in palette)) {
                palette[color] = valid_count
                if (color == maskout) {
                    maskout_index = valid_count  # Store the maskout index
                }
                valid_count++
            } else {
                print "Duplicate color skipped -> Color: " color ", Existing Index: " palette[color] > "/dev/stderr"
            }
        } else {
            print "Skipping invalid line: " line > "/dev/stderr"
        }
    }
    close("palette.tmp")

    if (maskout_index == -1) {
        print "ERROR: Maskout color (" maskout ") not found in palette. Exiting." > "/dev/stderr"
        exit 1
    }
}

{
    printf "        db  "
    output_line = ""
    mask_line = ""
    mask = 0
    mask_bit_pos = 7  # Start with MSB (bit 7)
    pixel_pair = ""   # Buffer for assembling pixel pairs

    for (i = 1; i <= length($0); i += 6) {
        # Extract RGB values
        r = substr($0, i, 2)
        g = substr($0, i+2, 2)
        b = substr($0, i+4, 2)
        color = tolower(sprintf("%s%s%s", r, g, b))

        # Determine the index
        if (color in palette) {
            idx = palette[color]
        } else {
            idx = maskout_index  # Default to the transparent color index
            print "DEBUG: No match for pixel color: " color " -> Defaulting to maskout" > "/dev/stderr"
        }

        # Build the mask
        if (idx != maskout_index) {  # Non-transparent pixel
            mask += (2 ^ mask_bit_pos)
        }

        # Handle pixel pairs
        if (mask_bit_pos % 2 == 1) {  # Odd bit position: store high nibble
            pixel_pair = idx * 16  # Shift left by 4 (high nibble)
        } else {  # Even bit position: combine with low nibble and flush
            pixel_pair += idx  # Add the low nibble
            output_line = output_line ((output_line == "" ? "" : ", ") sprintf("0x%02x", pixel_pair))
            pixel_pair = ""  # Reset pixel pair buffer
        }

        # Decrement mask bit position
        mask_bit_pos--
        if (mask_bit_pos < 0) {  # Mask byte complete
            mask_line = mask_line ((mask_line == "" ? "" : ", ") sprintf("0x%02x", mask))
            mask = 0
            mask_bit_pos = 7  # Reset to MSB
        }
    }

    # Handle any remaining mask bits or odd nibble
    if (mask_bit_pos < 7) {
        mask_line = mask_line ((mask_line == "" ? "" : ", ") sprintf("0x%02x", mask))
        if (pixel_pair != "") {  # Handle leftover high nibble
            output_line = output_line ((output_line == "" ? "" : ", ") sprintf("0x%02x", pixel_pair))
        }
    }

    # Print the mask and pixel data
    print mask_line ", " output_line
}' >> "$OUTPUT_FILE"

# Add the variable name end label and close the .ui file
{
    echo "        ${VARIABLE_NAME}End    label    byte"
    echo "        GSEndString"
    echo "    }"
    echo "}"
} >> "$OUTPUT_FILE"

# Clean up intermediate files
#rm $TEMP_FILE palette.tmp

echo "Conversion complete. Output written to $OUTPUT_FILE."
