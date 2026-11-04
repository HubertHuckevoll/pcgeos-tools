#!/usr/bin/env perl
# Check half-rate PCM against filtered full-rate synthesis, then test aliases.
use strict;
use warnings;
use Cwd qw(abs_path);
use File::Basename qw(dirname basename);
use File::Temp qw(tempdir);
use File::Path qw(make_path);
use JSON::PP qw(decode_json);

my $lib = abs_path(dirname(__FILE__).'/..');
my $repo = abs_path("$lib/../../../..");
my $corpus = abs_path(shift // die "usage: $0 corpus [extra.mp3]\n");
my @extra = map { abs_path($_) } @ARGV;
my $tmp = tempdir('mp3half-XXXXXX', TMPDIR=>1, CLEANUP=>!$ENV{KEEP_TESTS});
sub run { system(@_) == 0 or die "failed: @_\n"; }
sub read_file { open my $f,'<:raw',$_[0] or die $!; local $/; return <$f>; }
sub write_file { open my $f,'>:raw',$_[0] or die $!; print $f $_[1]; close $f or die $!; }
make_path("$tmp/include");
write_file("$tmp/include/geos.h", "#include \"$lib/Tests/host.h\"\n");
write_file("$tmp/include/file.h", "#include <geos.h>\ntypedef word FileHandle;\n#define FILE_POS_START 0\nword FileRead(FileHandle,void *,word,word);\ndword FilePos(FileHandle,dword,word);\n");
my @core = map { "$lib/$_.c" } qw(mp3frame mp3huff mp3imdct mp3synth mp3quant mp3ster);
my @flags = qw(-std=c89 -Werror=declaration-after-statement -O2 -fwrapv);
run('gcc', @flags, '-I', "$tmp/include", '-I', $lib, '-I', "$repo/CInclude",
    '-DMP3_HOST_TEST', '-x', 'c', "$lib/Tests/pull.c", "$lib/mp3reader.goc",
    "$lib/mp3api.c", @core, '-o', "$tmp/pull");

# The reference retains all PCM output positions after the same low-pass.
# Only the temporary core copy changes. No target decoder is patched here.
make_path("$tmp/core");
symlink("$lib/mp3fxp.h", "$tmp/mp3fxp.h") or die $!;
for my $file (glob("$lib/core/*")) {
    next unless -f $file;
    symlink($file, "$tmp/core/".basename($file)) or die $!;
}
unlink "$tmp/core/pvmp3_framedecoder.inc" or die $!;
my $source = read_file("$lib/core/pvmp3_framedecoder.inc");
$source =~ s/if \(halfRate && pChVars\[ch\]->used_freq_lines > 13\)/if (info->version_x == MPEG_1 \&\& pChVars[ch]->used_freq_lines > 13)/
    or die 'missing low-pass limit';
write_file("$tmp/core/pvmp3_framedecoder.inc", $source);
write_file("$tmp/mp3frame.c", read_file("$lib/mp3frame.c"));
my @reference = ("$tmp/mp3frame.c", @core[1..$#core]);
run('gcc', @flags, '-I', "$tmp/core", '-I', $lib, "$lib/Tests/corecheck.c",
    @reference, '-o', "$tmp/reference");

my @inputs = (glob("$corpus/tests/data/*.mp3"), @extra);
die 'no test inputs' unless @inputs;
# A low tone in L checks pitch and channel order. A tone above the new
# Nyquist limit in R must be removed, not folded into a lower frequency.
for my $rate (32000, 44100, 48000) {
  for my $edge (0, 1) {
    my $high = $rate * ($edge ? 0.251 : 0.26);
    my $path = "$tmp/tone$rate".($edge ? '-edge' : '').'.mp3';
    run('ffmpeg', '-v', 'error', '-f', 'lavfi', '-i',
        "aevalsrc=0.2*sin(2*PI*1000*t)|0.2*sin(2*PI*$high*t):s=$rate:d=1",
        '-c:a', 'libmp3lame', '-b:a', '192k', '-joint_stereo', '0', $path);
    push @inputs, $path;
  }
}
for my $input (@inputs) {
    open my $probe, '-|', 'ffprobe', '-v', 'error', '-show_entries',
        'stream=sample_rate,channels', '-of', 'json', $input or die $!;
    my $info = decode_json(do { local $/; <$probe> })->{streams}[0];
    close $probe or die 'ffprobe failed';
    my ($rate, $channels) = @{$info}{qw(sample_rate channels)};
    run("$tmp/reference", $input, "$tmp/reference.pcm");
    my $full = read_file("$tmp/reference.pcm");
    my $frame = $channels * 2;
    my $expected = $full;
    if ($rate >= 32000) {
        $expected = '';
        for (my $at=0; $at<length($full); $at+=2*$frame) {
            $expected .= substr($full, $at, $frame);
        }
    }
    for my $chunk (1, 127, 2048) {
        run("$tmp/pull", $input, "$tmp/half.pcm", $chunk, 'half');
        die "half PCM differs: $input" unless read_file("$tmp/half.pcm") eq $expected;
    }
    if ($input =~ /tone\d+(?:-edge)?\.mp3$/) {
        run("$tmp/pull", $input, "$tmp/normal.pcm", 2048);
        my @normal = unpack('s<*', read_file("$tmp/normal.pcm"));
        my $normalRight = 0;
        for (my $i=int($rate/4)*2+1; $i<int($rate*3/4)*2; $i+=2) {
            $normalRight += $normal[$i] ** 2;
        }
        die 'encoder already removed the high tone' unless $normalRight > ($rate/2) * (32768 * 0.05) ** 2;
        my @samples = unpack('s<*', $expected);
        my ($left, $right, $count, $crossings) = (0, 0, 0, 0);
        my $outRate = $rate / 2;
        for (my $i=int($outRate/4)*2; $i<int($outRate*3/4)*2; $i+=2) {
            $left += $samples[$i] ** 2;
            $right += $samples[$i+1] ** 2;
            $crossings++ if $samples[$i] <= 0 && $samples[$i+2] > 0;
            $count++;
        }
        my $gain = sqrt($left/$count) / (32768 * 0.2 / sqrt(2));
        my $alias = 10 * log(($right + 1)/$left) / log(10);
        die "low tone level changed: $gain" unless $gain > 0.85 && $gain < 1.05;
        die "alias not suppressed: $alias dB" unless $alias < -50;
        die 'low-tone pitch changed' unless abs($crossings * $outRate / $count - 1000) < 10;
        printf "rate %u: low-tone gain %.3f, alias %.1f dB\n", $rate, $gain, $alias;
    }
    print basename($input), ": exact half-rate PCM, format, partial reads, EOF, independent contexts: PASS\n";
}
# A 48 kHz half-rate stream and a 24 kHz normal stream have the same output
# rate. The reader must still reject the change in the encoded source rate.
run('ffmpeg', '-v', 'error', '-f', 'lavfi', '-i',
    'aevalsrc=0.2*sin(2*PI*1000*t)|0.2*sin(2*PI*2000*t):s=24000:d=1',
    '-c:a', 'libmp3lame', '-b:a', '64k', "$tmp/low.mp3");
write_file("$tmp/changed.mp3", read_file("$tmp/tone48000.mp3").read_file("$tmp/low.mp3"));
run("$tmp/pull", "$tmp/changed.mp3", "$tmp/changed.pcm", 127, 'half-error');
my $complete = read_file("$tmp/tone44100.mp3");
write_file("$tmp/truncated.mp3", substr($complete, 0, length($complete)-1));
run("$tmp/pull", "$tmp/truncated.mp3", "$tmp/truncated.pcm", 127, 'half-error');
print "Half-rate checks passed: $tmp\n";
