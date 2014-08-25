#!/usr/bin/perl
#ELF construction based on reversing done by Ange Albertini from corkami.com (great infographic)
#http://man7.org/linux/man-pages/man5/elf.5.html also has very useful info
use warnings;
use strict;
use Getopt::Long;

my ($in, $binary, $hex, $code);
my $out = "out";
my $temp_data;
my $memory_size = 64;

GetOptions('in=s' => \$in,
'out=s' => \$out,
'binary' => \$binary);

#--------------------------Code/Strings/Sections------------------------------------
if ($in) {
	
	$/ = undef;
	open IN, "$in" or die "Couldn't open $in, $!\n";
	$code = <IN>;
	$/ = "\n";

	if ($binary) {
	} else {
		convert();
	}
} else {
	$code = "\x90\x90\x90\x90\x90\x90\xb8\x01\x00\x00\x00\xcd\x80";
}

#Fix padding of code
$code .= "\x00" x (16 - (length($code) % 16)) if ((length($code) % 16) != 0);

#Section Names
my $shstrtab_name = "\x00\x2e\x73\x68\x73\x74\x72\x74\x61\x62\x00";
my $text_name = "\x2e\x74\x65\x78\x74\x00";
my $bss_name = '';
my $section_names = '';
if ($memory_size > 0) {								#If allocating memory
	$bss_name = "\x2e\x62\x73\x73\x00";
	$section_names = $shstrtab_name . $text_name . $bss_name . ("\x00" x 10);
} else {		#Otherwise, build without .bss
	$section_names = $shstrtab_name . $text_name . ("\x00" x 15);
}



my $null = "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00";
my $text = "\x0b\x00\x00\x00\x01\x00\x00\x00\x06\x00\x00\x00\x60\x00\x00\x08\x60\x00\x00\x00";
if ($memory_size > 0) {
	$text = "\x0b\x00\x00\x00\x01\x00\x00\x00\x06\x00\x00\x00\x80\x00\x00\x08\x80\x00\x00\x00";
}
my $offset = printhex_32(length($code));
$text .= $offset . "\x00\x00\x00\x00\x00\x00\x00\x00\x10\x00\x00\x00\x00\x00\x00\x00";	

my $shrtrtab = '';
my $bss_header = '';
my $sections = '';
if ($memory_size > 0) {
	$bss_header = "\x11\x00\x00\x00" . "\x08\x00\x00\x00" . "\x03\x00\x00\x00";
	$offset = printhex_32(100663296);
	$bss_header .= $offset;
	$offset = printhex_32(4096);
	$bss_header .= $offset;
	$offset = printhex_32($memory_size);
	$bss_header .= $offset . "\x00\x00\x00\x00\x00\x00\x00\x00\x04\x00\x00\x00\x00\x00\x00\x00";

	$shrtrtab = "\x01\x00\x00\x00\x03\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00";
	$offset = printhex_32(128 + length($code));
	$shrtrtab .= $offset . "\x19\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x01\x00\x00\x00\x00\x00\x00\x00";

	$sections = $null . $text . $bss_header . $shrtrtab;
} else {
	$shrtrtab = "\x01\x00\x00\x00\x03\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\xa0\x00\x00\x00\x19\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x01\x00\x00\x00\x00\x00\x00\x00";

	$sections = $null . $text . $shrtrtab;
}


#--------------------------Program Header Table setup------------------------------
my $p_type = "\x01\x00\x00\x00";				#The segment should be loaded into memory
my $p_offset = "\x00\x00\x00\x00";				#Offset where it should be read
my $p_addr = "\x00\x00\x00\x08";				#Virtual address where it should be loaded
my $p_paddr = "\x00\x00\x00\x08"; 				#Physical address where it should be loaded
my $p_filesz = "\x00\x00\x00\x00"; 				#Size on File
my $p_memsz = "\x00\x00\x00\x00"; 				#Size in memory
my $p_flags = "\x05\x00\x00\x00"; 				#Readable and eXecutable

#Give
$p_filesz = printhex_32(length($code) + 160);
$p_memsz = $p_filesz;

my $program_header_table = $p_type . $p_offset . $p_addr . $p_paddr . $p_filesz . $p_memsz . $p_flags . "\x00\x10\x00\x00";

if ($memory_size > 0) {	
	$program_header_table .= "\x01\x00\x00\x00\x00\x00\x00\x00\x00\x10\x00\x06\x00\x10\x00\x06";
	$program_header_table .= printhex_32($memory_size) . printhex_32($memory_size);
	$program_header_table .= "\x06\x00\x00\x00\x00\x10\x00\x00";
}	

#--------------------------ELF Header setup---------------------------------------

my $e_ident_EI_MAG = "\x7f\x45\x4c\x46";		#constant signature (ELF)
my $e_ident_EI_CLASS_DATA = "\x01\x01";			#32 bits, Little-Endian
my $e_ident_EI_VERSION = "\x01\x00\x00\x00";	#Always 1
my $e_type = "\x02\x00"; 						#Executable
my $e_machine = "\x03\x00";						#Intel 386 (and later)
my $e_version = "\x01\x00\x00\x00"; 			#Always 1
my $e_entry = "\x60\x00\x00\x08";
my $e_phoff = "\x40\x00\x00\x00";				#Program Headers' offset
my $e_shoff = "\x00\x00\x00\x00";				#Section Header's offset, 0'd out for now, calculated later
my $e_ehsize = "\x34\x00";						#ELF header's size
my $e_phentsize = "\x20\x00";					#Size of a single Program Header
my $e_phnum = "\x01\x00";						#Count of Program Headers
my $e_shentsize = "\x28\x00";					#Size of a single Section Header (probably static)
my $e_shnum = "\x03\x00";						#Count of Section Headers
my $e_shstrndx = "\x02\x00";					#Index of the names' section in the table
if ($memory_size > 0) {
	$e_shnum = "\x04\x00";
	$e_shstrndx = "\x03\x00";
	$e_phnum = "\x02\x00";
	$e_entry = "\x80\x00\x00\x08";	
}

#Calculate e_shoff size
$e_shoff = length($code . $section_names) + 96;
if ($memory_size > 0) {
	$e_shoff += 32;
}
$e_shoff = printhex_32($e_shoff);

#Build ELF Header
my $ELF_header = $e_ident_EI_MAG . $e_ident_EI_CLASS_DATA . $e_ident_EI_VERSION . ("\x00" x 6) . $e_type . $e_machine . $e_version . 
$e_entry . $e_phoff . $e_shoff . ("\x00" x 4) . $e_ehsize . $e_phentsize . $e_phnum . $e_shentsize . $e_shnum . $e_shstrndx . ("\x00" x 12);

#-------------------------combine everything--------------------------------------
my $output = $ELF_header . $program_header_table . $code . $section_names . $sections;

open FILE, ">$out" or die "Couldn't open $out, $!\n";
print FILE $output;		#send it out
close FILE;

#This sub takes an integer and converts it into it's 32-bit intel-endian form
sub printhex_32 {
	my $value = shift;	#get the value passed to it
	my $return;	#make a return variable
	$value = sprintf("%.8X\n", $value);	#get an "ASCII HEX" version of the value
	if ($value =~ /(.)(.)(.)(.)(.)(.)(.)(.)/) {	#parse out each character
		$return = pack("C*", map { $_ ? hex($_) :() } $7.$8) . pack("C*", map { $_ ? hex($_) :() } $5.$6) .
		pack("C*", map { $_ ? hex($_) :() } $3.$4) . pack("C*", map { $_ ? hex($_) :() } $1.$2);	#unpack it
	}
	return $return;	#return the hex data
}

sub convert {
	my $temp_code = '';
	$code =~ s/(.*)(#|\/\/|'|\-\-).*/$1/g;	#remove comments
	#Find 8-bit binary strings and convert to ascii-hex
	while ($code =~ /[^01]([01]{8})[^01]/) {
		my $replacement = sprintf('%X', oct("0b$1"));
		$code =~ s/([^01])[01]{8}([^01])/$1$replacement$2/;
	}
	$code =~ s/\s//g;						#remove spaces

	#Has pure ascii-hex, convert to binary data
	while ($code =~ /(..)/) { 		#Get the matching hex into $1
		$temp_code .= pack("C*", map { $_ ? hex($_) :() } $1);
		$code =~ s/^..//;
	}
	$code = $temp_code;

}