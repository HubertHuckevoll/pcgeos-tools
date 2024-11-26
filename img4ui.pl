#!/usr/bin/perl
use strict;
use warnings;

#
# Step 1: Dependencies and Input Validation
#

# Check if ImageMagick's convert is installed
my $convert_path = `which convert`;
chomp($convert_path);
if (!$convert_path) {
    die "Error: ImageMagick (convert) is not installed.\n";
}

# Check for input arguments
if (@ARGV < 2) {
    die "Usage: $0 <input_file> <variable_name>\n";
}

# Input file and variables
my $input_file = $ARGV[0];
my $variable_name = $ARGV[1];
my $temp_file = "reduced.gif";
my $output_file = "${variable_name}.ui";
my $maskout = "ff00ff";

# Identify the input file
system("identify -verbose $input_file") == 0
    or die "Error: Failed to identify $input_file.\n";

#
# Step 2: Reduce Colors and Extract Dimensions
#

# Reduce colors to 16
system("convert $input_file -colors 16 -type palette +dither $temp_file") == 0
    or die "Error: Failed to reduce colors in $input_file.\n";

# Identify the reduced image
system("identify -verbose $temp_file") == 0
    or die "Error: Failed to identify reduced image $temp_file.\n";

# Extract dimensions
chomp(my $width = `identify -format "%w" $temp_file`);
chomp(my $height = `identify -format "%h" $temp_file`);
die "Error: Unable to determine dimensions.\n" unless $width && $height;

#
# Step 3: Start Writing the Output File
#

# Open output file
open my $out, '>', $output_file or die "Error: Cannot open $output_file: $!\n";

print $out <<"HEADER";
visMoniker $variable_name = {
    size = standard;
    style = icon;
    aspectRatio = normal;
    color = color4;
    cachedSize = $width, $height;
    gstring {
        GSBeginString
        GSDrawBitmapAtCP <(${variable_name}End - ${variable_name}Start)>
        ${variable_name}Start	label	byte
        CBitmap <<$width,$height,BMC_UNCOMPACTED,BMF_4BIT or mask BMT_MASK or mask BMT_PALETTE or mask BMT_COMPLEX>, 0, $height, 0, 70, 20, 72, 72>
        word    16
HEADER

#
# Step 4: Extract and Reorder Palette in Perl
#

# Declare variables at the top of the file where possible
my $maskout_index;

# Parse the colormap using identify output
open my $palette_tmp, '>', "palette.tmp" or die "Error: Cannot open palette.tmp: $!\n";
my %palette;
my %color_to_index;

# Process colormap from identify output
open my $identify, "-|", "identify -verbose $temp_file" or die "Error: Cannot run identify.\n";
while (<$identify>) {
    if (/^\s*(\d+):\s*\(([^)]+)\)\s*#([0-9A-Fa-f]{6})/) {
        my ($index, $rgb, $hex) = ($1, $2, lc($3));
        my ($r, $g, $b) = map { "0x$_" } unpack("(A2)*", $hex);
        $palette{$index} = sprintf("        RGBValue < %s, %s, %s >", $r, $g, $b);
        $color_to_index{$hex} = $index;
    }
}
close $identify;

# Assign maskout_index based on $maskout color
$maskout_index = $color_to_index{$maskout} // die "Error: Maskout color ($maskout) not found in palette.\n";


# Write the palette to file
for my $i (0 .. 15) {
    if (exists $palette{$i}) {
        print $palette_tmp "$palette{$i}\n";
    } else {
        print $palette_tmp "        RGBValue < 0x00, 0x00, 0x00 >\n";
    }
}
close $palette_tmp;

# Append palette to the output file
open my $palette_in, '<', "palette.tmp" or die "Error: Cannot read palette.tmp: $!\n";
print $out $_ while <$palette_in>;
close $palette_in;


#
# Step 5: Extract Pixel Data
#

# Extract pixel data in 4-bit format, perform reverse lookup
open my $pixels, "-|", "convert $temp_file -depth 8 rgb:-" or die "Error: Cannot extract pixels.\n";

my $row_count = 0;  # Track number of rows processed
while (read($pixels, my $row, $width * 3)) {
    $row_count++;  # Increment row count for each row read

    # Break the row into 6-character (RGB) segments
    my @pixels = unpack("(A6)*", unpack("H*", $row));

    my $mask = 0;
    my $mask_bit_pos = 7;  # Start with MSB
    my $pixel_pair = "";   # Buffer for combining nibbles
    my @pixel_data;        # Store 4-bit pixel pairs
    my @mask_data;         # Store mask bytes

    foreach my $color (@pixels) {
        $color = lc($color);  # Normalize color to lowercase
        my $index = exists $color_to_index{$color} ? $color_to_index{$color} : $maskout_index;

        # Update mask byte for non-transparent pixels
        if ($index != $maskout_index) {
            $mask |= (1 << $mask_bit_pos);
        }

        # Handle 4-bit pixel pairing
        if ($mask_bit_pos % 2 == 1) {  # High nibble
            $pixel_pair = $index << 4;
        } else {  # Low nibble, combine and flush
            $pixel_pair |= $index;
            push @pixel_data, $pixel_pair;  # Store full byte
            $pixel_pair = "";  # Reset buffer
        }

        $mask_bit_pos--;
        if ($mask_bit_pos < 0) {  # Flush mask byte
            push @mask_data, $mask;
            $mask = 0;
            $mask_bit_pos = 7;
        }
    }

    # Handle leftovers at the end of the row
    if ($mask_bit_pos < 7) {
        push @mask_data, $mask;  # Flush the last mask byte
    }
    if ($pixel_pair ne "") {  # Flush the last pixel nibble
        push @pixel_data, $pixel_pair;
    }

    # Combine mask and pixel data into a single line
    my @line_data = (@mask_data, @pixel_data);

    # Calculate expected bytes
    my $expected_mask_bytes = int(($width + 7) / 8);   # 1 mask byte per 8 pixels
    my $expected_pixel_bytes = int(($width + 1) / 2);  # 4-bit pixels => 2 pixels per byte
    my $expected_total_bytes = $expected_mask_bytes + $expected_pixel_bytes;

    # Validate the number of bytes matches the expected width in pixels
    if (scalar(@line_data) != $expected_total_bytes) {
        die "Error: Row $row_count has unexpected byte count: " . scalar(@line_data) .
            " instead of $expected_total_bytes (mask: $expected_mask_bytes, pixels: $expected_pixel_bytes).\n";
    }

    # Format line data for output
    my $line = join(", ", map { sprintf("0x%02x", $_) } @line_data);

    # Remove trailing comma from the last line
    $line =~ s/, $//;

    # Print the completed row
    print $out "        db $line\n";
}

close $pixels;

# Validate the row count matches the image height
if ($row_count != $height) {
    die "Error: Number of rows processed ($row_count) does not match image height ($height).\n";
}

#
# Step 6: Finalize and Cleanup
#
print $out <<"FOOTER";
        ${variable_name}End    label    byte
        GSEndString
    }
}
FOOTER

close $out;
unlink $temp_file, "palette.tmp";
print "Conversion complete. Output written to $output_file.\n";
