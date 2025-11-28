#!/usr/bin/perl
#
# Description: find duplicated files
# Usage: dd.pl <root path to scan>
#
# Comments:
# 	findfiles --> build fingerprint --> handle dup -> compare files -> print dup.
# 	findfiles() : one function to recursively enumerate files
# 	comparefiles() : one function to compare content of files
# 	build_fingerprint() : one function to generate fingerprint based on file attributes: some hash function based on file content plus size like hash(content) w/ size.
# 	handle_dup() : one function to identify true/false dup.
# 	print_dup() : one function to show the dup files.
#
# Author: ywang19
#
# PRESUME DD ARRAY: the array list for potential conflicted files
# ACTUAL_DD_ARRY: the array list which stores actual conflicted files.
#


#use strict;
use Time::Local;
use File::Find;
use File::Compare;
use Digest::MD5 qw(md5 md5_hex md5_base64);

my $name;
my %ARRAY;
my $idx = 0;
my @dirs;
local %PRESUME_DD_ARRAY; # {KEY ==> d1::d2...)}
local %ACTUAL_DD_ARRAY; # {KEY ==> d1::d2...)}
local $count = 0;

$ts0=time;

dbmopen(%ARRAY, "dlib", undef);

push(@dirs, $ARGV[0]);

find(\&handle_dup, @dirs);

# while (($key, $value) = each (%ARRAY)) {
	# print ("$key --> $value\n");
# }

print ("\nTotal items are $count\n");
print ("\n\nConflicts....\n\n");

while (($key, $value) = each (%PRESUME_DD_ARRAY)) {
	print ("$key --> $value\n");
}

&cmp_file();

# while (($key, $value) = each (%ACTUAL_DD_ARRAY)) {
	# print ("$key --> $value\n");
# }

&print_dup(%PRESUME_DD_ARRAY);
&print_dup(%ACTUAL_DD_ARRAY);

$pre_count = keys(%PRESUME_DD_ARRAY);
$act_count = keys(%ACTUAL_DD_ARRAY);
print ("Presumable dd items are $pre_count, Actual dd items are $act_count\n");


dbmclose(%ARRAY);


$ts1 = time();

print ("Elapsed Time: ", $ts1-$ts0,"\n");


# ===============
sub build_fingerprint {
	print $_;
	open(INFILE, $_) or die "Can't open the file $_, $!\n";
	$digest = Digest::MD5->new;
	$digest->addfile($INFILE);
	
	($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat($_);
	
	return $digest->hexdigest . "::" . $size;
	
}

sub handle_dup {
#	print ("Dir: $File::Find::dir\tFileName: $_\t$File::Find::name\n");
	$count++;
	
	$size = (stat($_))[7]; # file size
	$fingerprint = $_ . "::" . $size;
#	print File::Find::name;
#	$fingerprint = &build_fingerprint($_);
	
	if (exists ($ARRAY{$fingerprint})) {
		$existed_filename = $ARRAY{$fingerprint};
		
		if (! exists ($PRESUME_DD_ARRAY{$fingerprint})) { # new conflicts
			@con = ($existed_filename, $File::Find::name);
			$str = join("::", @con);
			$PRESUME_DD_ARRAY{$fingerprint} = $str;
		} else {
			@con = $PRESUME_DD_ARRAY{$fingerprint};
			push(@con, $File::Find::name);
			$str = join("::", @con);
			$PRESUME_DD_ARRAY{$fingerprint} = $str;
		}
	} else {
		$ARRAY{$fingerprint} = $File::Find::name;
	}
#	open(INFILE, $_) or die "Can't open the file $_, $!\n");
}

sub cmp_file {
	my @files;
	my $str;
	my $dd_count=0;
	
	# {KEY ==> d1::d2...)} --> {KEY ==> d1::d2|d3::d4::d5...} 
	while (($key, $value) = each (%PRESUME_DD_ARRAY)) {
		@files = split ("::", $value);
		
		while (@files) {
			$dd_count = 0;
			$str = $files[0];
#			$str = $str . $files[0];
			for ($i=1; $i<@files; $i++) {
				if(compare($files[0], $files[$i]) == 0) { # dup'd
					$dd_count++;
					$str = $str . "::" . $files[$i];
					splice(@files,$i,1);
				}
			}
			
			if($dd_count) {
				$ACTUAL_DD_ARRAY{$key . "@" . $files[0]} = $str;
			}
			
			splice(@files,0,1);
		}
		
	}
		
}

sub print_dup {
	my (%ARRAY) = @_;
	my @files;
	my $dd_count=0;
	
	while (($key, $value) = each (%ARRAY)) {
		print ("$key\n");
		@files = split ("::", $value);
		
		for($i=0; $i<@files; $i++) {
			print ("\t\t--> $files[$i]\n");
		}
	}

}
