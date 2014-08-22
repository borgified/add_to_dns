#!/usr/bin/env perl

use warnings;
use strict;


sub main {

	my $newips = &newips; #hash of new ips from __DATA__
	#&print_hash($newips); #check to see if newips got read correctly
	#print $$newips{'10.11.13.66'}; #this is how to use %newips

	#assumes one ip per hostname. i know it is possible to have 
	#different hostnames with same ip. fix this bug later.
	#right now it only affects the following ips:
	#173.201.145.1,10.11.33.20,10.11.33.21,10.11.10.79


	my %hash_of_updated_files;
	my @processed_ips;

	#clean up any temp files from prev runs
	system("rm -rf /tmp/db.*");

	foreach my $ip (@ARGV) {

		print "------------------\n";

		if(&check_typo($ip)){ #makes sure input ip is correct	format
			#true means it is ok
		}else{
			next;
		}

		#check that it exists in our database
		if(!exists($$newips{$ip})){
			print "unknown $ip, update __DATA__ section to include this entry\n";
			next; #skip this ip, go to the next ip
		}
		my $hostname = $$newips{$ip};
		print "adding: $ip $hostname\n";
		push(@processed_ips, $ip);

		#add corresponding PTR entry
		&add_reversedns_entry($ip,$hostname);

		#updates db.paraccel.com with new ip
		&add_forwarddns_entry($ip,$hostname);

		my @octet = split(/\./,$ip);
		my $file_to_open = "db.$octet[-2].$octet[-3].$octet[-4]";

		$hash_of_updated_files{$file_to_open}=0;

	}

	if(scalar @processed_ips > 0){

		print "==================\n";

		#db.paraccel.com is always updated so we add this entry
		$hash_of_updated_files{'db.paraccel.com'}=0;

		#run setserial on updated db.* files
		foreach my $file (sort keys %hash_of_updated_files){

			#do a diff of the changes and check with user before overwriting
			my $command = "diff /tmp/$file /etc/bind/zones/$file";
			print "running $command\n";
			my $rv = system($command);

			if($rv != 0){
			print "Accept changes? (y/n) ";
			my $answer=<STDIN>;
			chomp($answer);
			if($answer eq 'y'){
				print "overwriting $file\n";
				system("mv /tmp/$file /etc/bind/zones/$file");
				system("chmod a+x /etc/bind/zones/$file");

				print "running setserial $file\n";
				system("setserial $file");
			}
			}else{
				next;
			}
		}


		#run service bind9 reload
		print "running service bind9 reload\n";
		system("service bind9 reload");


		#do a ping test on each new ip
		foreach my $ip (@processed_ips){
			my $hostname = $$newips{$ip};
			$hostname =~ s/\.paraccel\.com//;
			print "ping -c1 -w1 $hostname\n";
			system("ping -c1 -w1 $hostname");
		}
	}

}
&main;

sub add_forwarddns_entry{
	#doesnt actually add entry since the entry should exist
	#we just need to modify the existing entry and update the
	#old ip with the new ip

	my $ip = shift;
	my $fqdn = shift;

	my $file_contents;

	#need to give preference to the file in /tmp as this will
	#have the latest changes
	if(-e "/tmp/db.paraccel.com"){
		$file_contents = &slurp("/tmp/db.paraccel.com");
	}else{
		$file_contents = &slurp("./db.paraccel.com");
	}
	my @file_contents = split(/\n/,$file_contents);

	$fqdn =~ /(.*)\.paraccel\.com/;
	my $hostname = $1;

	my $line_number=0;
	foreach my $line (@file_contents){
		if($line =~ /^$hostname\s/){
			#print "found:\n$line\n";
			$line =~ s/\d+\.\d+\.\d+\.\d+/$ip/;
			$file_contents[$line_number] = $line;

			#print "updated to:\n$file_contents[$line_number]\n";

		}
		$line_number++;
	}

	#ready to output @file_contents back into a file
	#print "-----------------\n";
	open(OUTPUT,'>',"/tmp/db.paraccel.com") or die $!;

	foreach my $line (@file_contents){
		print OUTPUT "$line\n";
	}
	close(OUTPUT);

}


sub add_reversedns_entry{
	my $ip = shift;
	my $hostname = shift;
	my @octet = split(/\./,$ip);
	my $file_to_open = "db.$octet[-2].$octet[-3].$octet[-4]";
	#print "$file_to_open\n"; #check to see if the filename is setup correctly

	my $file_contents;

	#need to give preference to the file in /tmp as this will
	#have the latest changes
	if(-e "/tmp/$file_to_open"){
		$file_contents = &slurp("/tmp/$file_to_open");
	}else{
		$file_contents = &slurp("./$file_to_open");
	}
	my @file_contents = split(/\n/,$file_contents);
	my $line_number=0;
	my $doitonce=1;
	my $splice_here;

	foreach my $line (@file_contents){
		if($line =~ /^(\d+)/){
			if($1 == $octet[-1]){
				#print "$line_number: entry already exists!: $line\n";
				print "entry already exists!: $line\n";
				if(! -e "/tmp/$file_to_open"){
					system("cp /etc/bind/zones/$file_to_open /tmp");
				}
				return;
			}elsif(($1 > $octet[-1]) && $doitonce){
				#print "$line_number: $line\n";
				#print "put it before this line: $line_number\n";
				$splice_here=$line_number;
				$doitonce=0;
			}elsif($1 < $octet[-1]){
				#print "$line_number: $line\n";
			}else{
				#print "$line_number: $line\n";
			}
		}
		$line_number++;
	}

	if($doitonce == 1){
		#if db.* file has no PTR entries, just append entry to the header
		#we can tell it has no PTR entries because $doitonce was never set to 0
		$splice_here = $line_number;
	}

	splice @file_contents, $splice_here, 0, "$octet[-1]\t\tPTR\t$hostname.";

	#ready to output @file_contents back into a file
	#print "-----------------\n";
	#print "creating /tmp/$file_to_open\n";
	open(OUTPUT,'>',"/tmp/$file_to_open") or die $!;
	foreach my $line (@file_contents){
		print OUTPUT "$line\n";
	}
	close(OUTPUT);

}


sub check_typo{
	my $ip = shift @_;
	if($ip !~ /10\.11\.(10|11|13|30|31|32|33|250)\.\d+$/){
		print "typo detected: $ip\n";
		print "ips need to start with 10.11.{10|11|13|30|31|32|33|250}.xxx\n";
		print "example: add.pl 10.11.30.14\n";
		return 0;
	}else{
		return 1;
	}
}
sub print_hash {
	my $hash=shift @_;
	foreach my $key (keys %$hash){
		print "$key : $$hash{$key}\n";
	}
}



sub slurp {
	#http://perlmaven.com/slurp
	my $file = shift;
	open my $fh, '<', $file or die $!;
	local $/ = undef;
	my $cont = <$fh>;
	close $fh;
	return $cont;
}

sub newips{
	#returns a hash of the csv contained in __DATA__
	#with $hash{ip}=hostname
	my %newips;

	my $newips;
	{
		local $/ = undef;
		$newips = <DATA>;
	}
	my @newips = split(/\n/,$newips);

	foreach my $item (@newips){
		my($hostname,$ip)=split(/,/,$item);
		if(!exists($newips{$ip})){
			$newips{$ip}=$hostname;
		}else{
			#print "$ip already exists for $newips{$ip}\n";
			#print "if you are adding this ip, doublecheck that it is done correctly\n";
		}
	}

	#&print_hash(\%newips);

	return \%newips;
}
__DATA__
some.host.com,10.10.0.10
