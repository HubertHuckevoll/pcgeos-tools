#!/usr/bin/perl
use strict;
use warnings;

# -----------------------------------------------------------------------------
# Description:
#
# This script processes an image file to generate a 4-bit / 16 color bitmap
# with custom palette for PC/GEOS in UIC/ESP. PC/GEOS knows how to handle 4-Bit 
# images with custom palette, but none of the tools supports ouputting this very 
# efficient format.
#
# The script performs the following steps:
#
# 1. Validates dependencies (ImageMagick's `convert` utility) and input arguments.
# 2. Reduces the image to a 16-color palette using ImageMagick.
# 3. Extracts image dimensions and creates a palette mapping for 4-bit indexed colors.
# 4. Converts pixel data into 4-bit indexed format, including handling a transparency
#    mask, and applies PackBits compression to optimize memory usage.
# 5. Generates an output file with the compressed bitmap and metadata, formatted for
#    use in PC/GEOS.
#
# Dependencies:
# - ImageMagick (`convert` and `identify`)
# - Perl (obviously)
#
# Usage:
#   perl script.pl <input_file> <variable_name> [asm|goc]
#
# Example:
#   perl script.pl input.png iconVariable goc
#
# -----------------------------------------------------------------------------

#
# Step 0: Subs
#

sub packbits_compress {
    my @data = @_;
    my @compressed;
    my $i = 0;

    while ($i < @data) {
        # Check for runs of identical bytes
        my $run_start = $i;
        while ($i + 1 < @data && $data[$i] == $data[$i + 1] && ($i - $run_start) < 127) {
            $i++;
        }

        if ($i > $run_start) {
            # Found a run of identical bytes
            my $run_length = $i - $run_start + 1;
            push @compressed, -(($run_length - 1) & 0x7f);  # Signed 8-bit negative
            push @compressed, $data[$run_start];
            $i++;
        } else {
            # Handle unique byte sequence
            my $unique_start = $i;
            while (
                $i + 1 < @data &&
                ($data[$i] != $data[$i + 1] || $i == $unique_start) &&
                ($i - $unique_start) < 127
            ) {
                $i++;
            }

            my $unique_length = $i - $unique_start + 1;
            push @compressed, ($unique_length - 1) & 0x7f;  # Unsigned 8-bit positive
            push @compressed, @data[$unique_start .. $i];
            $i++;
        }
    }

    # Ensure all values are 8-bit
    @compressed = map { $_ & 0xff } @compressed;

    return @compressed;
}

sub usage {
    return "Usage: $0 <input_file> <variable_name> [asm|goc]\n";
}

sub count_bytes {
    my ($rows_ref) = @_;
    my $count = 0;
    for my $row_ref (@$rows_ref) {
        $count += scalar(@$row_ref);
    }
    return $count;
}

sub emit_asm {
    my ($output_file, $variable_name, $width, $height, $palette_ref, $rows_ref) = @_;
    open my $out, ">", $output_file or die "Error: Cannot open $output_file: $!\n";

    print $out <<"HEADER";
visMoniker $variable_name = {
    size = standard;
    style = icon;
    aspectRatio = normal;
    color = color8;
    cachedSize = $width, $height;
    gstring {
        GSBeginString
        GSDrawBitmapAtCP <(${variable_name}End - ${variable_name}Start)>
        ${variable_name}Start	label	byte
        CBitmap <<$width, $height, BMC_PACKBITS, BMF_4BIT or mask BMT_MASK or mask BMT_PALETTE or mask BMT_COMPLEX>, 0, $height, 0, 70, 20, 72, 72>
        word    16
HEADER

    for my $entry (@$palette_ref) {
        print $out "        RGBValue < $entry->[0], $entry->[1], $entry->[2] >\n";
    }

    for my $row_ref (@$rows_ref) {
        my $line = join(", ", map { sprintf("0x%02x", $_) } @$row_ref);
        print $out "        db $line\n";
    }

    print $out <<"FOOTER";
        ${variable_name}End    label    byte
        GSEndString
    }
}
FOOTER

    close $out;
}

sub emit_goc {
    my ($output_file, $variable_name, $width, $height, $palette_ref, $rows_ref) = @_;
    open my $out, ">", $output_file or die "Error: Cannot open $output_file: $!\n";

    my $compressed_bytes = count_bytes($rows_ref);
    my $bitmap_payload_bytes = 14 + 2 + (16 * 3) + $compressed_bytes;
    my $gstring_bytes = 6 + $bitmap_payload_bytes;

    print $out <<"HEADER";
\@visMoniker $variable_name = {
    size = standard;
    style = icon;
    aspectRatio = normal;
    color = color8;
    cachedSize = $width, $height;
    gstring {
		GSDrawBitmapAtCP($gstring_bytes),
		Bitmap ($width,$height,BMC_PACKBITS,(BMF_4BIT | BMT_MASK | BMT_PALETTE | BMT_COMPLEX)),
		0, 0, $height, 0, 0, 0, 70, 0, 20, 0, 72, 0, 72, 0,
		16, 0, /* palette length */
HEADER

    for my $entry (@$palette_ref) {
        print $out "\t\t$entry->[0], $entry->[1], $entry->[2],\n";
    }

    for my $row_ref (@$rows_ref) {
        my $line = join(", ", map { sprintf("0x%02x", $_) } @$row_ref);
        print $out "\t\t$line,\n";
    }

    print $out <<"FOOTER";
		GSEndString()
    }
}
FOOTER

    close $out;
}

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
if (@ARGV < 2 || @ARGV > 3) {
    die usage();
}

# Input file and variables
my $input_file = $ARGV[0];
my $variable_name = $ARGV[1];
my $mode = defined($ARGV[2]) ? lc($ARGV[2]) : "goc";
if ($mode ne "asm" && $mode ne "goc") {
    die "Error: Invalid mode '$mode'. Valid modes: asm, goc.\n" . usage();
}

my $temp_file = "reduced.gif";
my $output_file = ($mode eq "asm") ? "${variable_name}.ui" : "${variable_name}.goh";
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
# Step 3: Extract and Reorder Palette
#

my %palette;
my %color_to_index;

open my $identify, "-|", "identify -verbose $temp_file" or die "Error: Cannot run identify.\n";
while (<$identify>) {
    if (/^\s*(\d+):\s*\(([^)]+)\)\s*#([0-9A-Fa-f]{6})/) {
        my ($index, $hex) = ($1, lc($3));
        my @channels = map { "0x$_" } unpack("(A2)*", $hex);
        $palette{$index} = \@channels;
        $color_to_index{$hex} = $index;
    }
}
close $identify;

my $maskout_index = $color_to_index{$maskout}
    // die "Error: Maskout color ($maskout) not found in palette.\n";

my @palette_entries;
for my $i (0 .. 15) {
    if (exists $palette{$i}) {
        push @palette_entries, $palette{$i};
    } else {
        push @palette_entries, [ "0x00", "0x00", "0x00" ];
    }
}

#
# Step 4: Extract and Compress Pixel Data
#

open my $pixels, "-|", "convert $temp_file -depth 8 rgb:-" or die "Error: Cannot extract pixels.\n";

my $row_count = 0;
my @compressed_rows;
while (read($pixels, my $row, $width * 3)) {
    $row_count++;

    my @pixels = unpack("(A6)*", unpack("H*", $row));

    my $mask = 0;
    my $mask_bit_pos = 7;
    my $pixel_pair = "";
    my @pixel_data;
    my @mask_data;

    for my $color (@pixels) {
        $color = lc($color);
        my $index = exists $color_to_index{$color} ? $color_to_index{$color} : $maskout_index;

        if ($index != $maskout_index) {
            $mask |= (1 << $mask_bit_pos);
        }

        if ($mask_bit_pos % 2 == 1) {
            $pixel_pair = $index << 4;
        } else {
            $pixel_pair |= $index;
            push @pixel_data, $pixel_pair;
            $pixel_pair = "";
        }

        $mask_bit_pos--;
        if ($mask_bit_pos < 0) {
            push @mask_data, $mask;
            $mask = 0;
            $mask_bit_pos = 7;
        }
    }

    if ($mask_bit_pos < 7) {
        push @mask_data, $mask;
    }
    if ($pixel_pair ne "") {
        push @pixel_data, $pixel_pair;
    }

    my @line_data = (@mask_data, @pixel_data);
    my @compressed_data = packbits_compress(@line_data);
    push @compressed_rows, \@compressed_data;
}

close $pixels;

if ($row_count != $height) {
    die "Error: Number of rows processed ($row_count) does not match image height ($height).\n";
}

#
# Step 5: Emit requested output format
#

if ($mode eq "asm") {
    emit_asm($output_file, $variable_name, $width, $height, \@palette_entries, \@compressed_rows);
} else {
    emit_goc($output_file, $variable_name, $width, $height, \@palette_entries, \@compressed_rows);
}

#unlink $temp_file;
print "Conversion complete. Output written to $output_file.\n";
