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

	foreach my $ip (@ARGV) {

		&check_typo($ip); #makes sure input ip is correct	format
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

		#db.paraccel.com is always updated so we add this entry
		$hash_of_updated_files{'db.paraccel.com'}=0;

		#run setserial on updated db.* files
		foreach my $file (keys %hash_of_updated_files){

			#do a diff of the changes and check with user before overwriting
			my $command = "diff /tmp/$file /etc/bind/zones/$file";
			print "running $command\n";
			system($command);

			print "Accept changes? (y/n) ";
			my $answer=<STDIN>;
			chomp($answer);
			if($answer eq 'y'){
				print "overwriting $file\n";
				system("mv /tmp/$file /etc/bind/zones/$file");

				print "running setserial $file\n";
				system("setserial $file");
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
			print "ping -c 1 $hostname\n";
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

	my $file_contents = &slurp("./db.paraccel.com");
	my @file_contents = split(/\n/,$file_contents);

	$fqdn =~ /(.*)\.paraccel\.com/;
	my $hostname = $1;

	my $line_number=0;
	foreach my $line (@file_contents){
		if($line =~ /^$hostname\s/){
			print "found:\n$line\n";
			$line =~ s/\d+\.\d+\.\d+\.\d+/$ip/;
			$file_contents[$line_number] = $line;

			print "updated to:\n$file_contents[$line_number]\n";

		}
		$line_number++;
	}

	#ready to output @file_contents back into a file
	print "-----------------\n";
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

	my $file_contents = &slurp("./$file_to_open");
	my @file_contents = split(/\n/,$file_contents);
	my $line_number=0;
	my $doitonce=1;
	my $splice_here;

	foreach my $line (@file_contents){
		if($line =~ /^(\d+)/){
			if($1 == $octet[-1]){
				print "$line_number: entry already exists!: $line\n";
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
	print "-----------------\n";
	open(OUTPUT,'>',"/tmp/$file_to_open") or die $!;
	foreach my $line (@file_contents){
		print OUTPUT "$line\n";
	}
	close(OUTPUT);

}


sub check_typo{
	my $ip = shift @_;
	if($ip !~ /10\.11\.(10|11|13|30|31|32|33|250)\.\d+$/){
		die "typo detected: $ip\n";
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
tintri1-10g.paraccel.com,10.10.0.10
itvm11-10g.paraccel.com,10.10.0.11
itvm8-10g.paraccel.com,10.10.0.12
itvm12-10g.paraccel.com,10.10.0.13
itvm14-10g.paraccel.com,10.10.0.14
itvm15-10g.paraccel.com,10.10.0.15
itvm16-10g.paraccel.com,10.10.0.16
backup-ipmp0.paraccel.com,10.10.0.28
nexsan1-nx0.paraccel.com,10.10.0.31
nexsan1-nx0-ctrl1.paraccel.com,10.10.0.32
nexsan1-nx0-ctrl2.paraccel.com,10.10.0.33
nexsan1-nx0-rg1.paraccel.com,10.10.0.34
nexsan1-nx0-rg2.paraccel.com,10.10.0.35
potato-bond0.paraccel.com,10.10.0.36
lemon-bond0.paraccel.com,10.10.0.37
itvm10-10g.paraccel.com,10.10.0.8
itvm13-10g.paraccel.com,10.10.0.9
xencom226.paraccel.com,10.11.10.10
xencom230.paraccel.com,10.11.10.11
xencom231.paraccel.com,10.11.10.12
xencom232.paraccel.com,10.11.10.13
xencom233.paraccel.com,10.11.10.14
xencom235.paraccel.com,10.11.10.15
xencom236.paraccel.com,10.11.10.16
xencom237.paraccel.com,10.11.10.17
burner.paraccel.com,10.11.10.18
disty.paraccel.com,10.11.10.19
puppet.paraccel.com,10.11.10.20
dash-ilom.paraccel.com,10.11.10.79
ws-rnascimento.paraccel.com,10.11.11.10
ws-ttsuei.paraccel.com,10.11.11.11
ws-grost.paraccel.com,10.11.11.12
ws-czhang.paraccel.com,10.11.11.13
ws-vmarkman2.paraccel.com,10.11.11.14
pshiner.paraccel.com,10.11.11.15
ws-bmckenna2.paraccel.com,10.11.11.16
ws-mgeorge.paraccel.com,10.11.11.17
ws-grost2.paraccel.com,10.11.11.18
ws-grost3.paraccel.com,10.11.11.19
ws-czhang2.paraccel.com,10.11.11.20
qadashboard.paraccel.com,10.11.11.21
ws-trandell2.paraccel.com,10.11.11.22
usldc-netflow01.paraccel.com,10.11.11.23
ws-sguruswamy.paraccel.com,10.11.11.24
bsoft3-dev.paraccel.com,10.11.11.25
ws-dliang.paraccel.com,10.11.11.26
ws-dclay.paraccel.com,10.11.11.27
ws-rgeorge.paraccel.com,10.11.11.28
ws-jyates2.paraccel.com,10.11.11.29
collabapp-vm.paraccel.com,10.11.11.30
ws-partha.paraccel.com,10.11.11.31
ws-tpho.paraccel.com,10.11.11.32
ws-hjakobsson.paraccel.com,10.11.11.33
ws-ssajip.paraccel.com,10.11.11.34
ws-rprakash.paraccel.com,10.11.11.35
kerberos-dev.paraccel.com,10.11.11.36
ws-ssajip2.paraccel.com,10.11.11.37
qa-build4.paraccel.com,10.11.11.38
sparql-ipv6.paraccel.com,10.11.11.39
ws-vdaga.paraccel.com,10.11.11.40
usldc-git01.paraccel.com,10.11.11.41
ws-rsingh.paraccel.com,10.11.11.43
ws-jmoore3.paraccel.com,10.11.11.44
ws-sdesantis.paraccel.com,10.11.11.45
ws-nbacon.paraccel.com,10.11.11.46
ussd-devops01.paraccel.com,10.11.11.49
ws-bmarquez.paraccel.com,10.11.11.50
anthill2.paraccel.com,10.11.11.51
ws-hnandanan.paraccel.com,10.11.11.52
ws-hjakobsson2.paraccel.com,10.11.11.54
usldc-nagios01.paraccel.com,10.11.11.9
cognos-support.paraccel.com,10.11.250.167
portal.paraccel.com,10.11.250.171
cognos-support2.paraccel.com,10.11.250.174
entry.paraccel.com,10.11.251.164
bsoft1-dev.paraccel.com,10.11.251.63
ws-igarish.paraccel.com,10.11.251.65
bsoft4-dev.paraccel.com,10.11.251.66
qa38.paraccel.com,10.4.10.105
qa39.paraccel.com,10.4.10.107
qa40.paraccel.com,10.4.10.108
qa41.paraccel.com,10.4.10.109
qa44.paraccel.com,10.4.10.111
qa45.paraccel.com,10.4.10.113
qa42.paraccel.com,10.4.10.135
ftp.paraccel.com,64.64.30.197
paraccel.com..paraccel.com,173.201.145.1
www.paraccel.com,173.201.145.1
metroid.paraccel.com,10.11.30.133
diablo.paraccel.com,10.11.30.47
ldc-b2.paraccel.com,10.11.30.97
ldc-psw3.paraccel.com,10.11.30.104
para-san1.paraccel.com,10.11.30.137
para-san1-spa.paraccel.com,10.11.30.138
para-san1-spb.paraccel.com,10.11.30.139
ldc-fsw1.paraccel.com,10.11.30.102
ldc-clstr-sw1.paraccel.com,10.11.30.98
ldc-clstr-sw3.paraccel.com,10.11.30.100
ldc-clstr-sw5.paraccel.com,10.11.30.101
ldc-clstr-sw2.paraccel.com,10.11.30.99
ldc-a5.paraccel.com,10.11.30.95
ldc-a7.paraccel.com,10.11.30.96
ldc-psw1.paraccel.com,10.11.30.103
qa-drone13.paraccel.com,10.11.30.207
qa-drone14.paraccel.com,10.11.30.208
parasql53.paraccel.com,10.11.30.140
ldc-cs1.paraccel.com,10.11.10.175
monitor.paraccel.com,10.11.10.186
ns1.paraccel.com,10.11.10.192
sparqlrepo.paraccel.com,10.11.13.49
ticket.paraccel.com,10.11.13.52
ps1.paraccel.com,10.11.10.204
ps2.paraccel.com,10.11.10.205
ps3.paraccel.com,10.11.10.206
ps4.paraccel.com,10.11.10.207
ldc-clstr-sw21.paraccel.com,10.11.10.174
ldc-clstr-sw16.paraccel.com,10.11.10.169
ldc-clstr-sw17.paraccel.com,10.11.10.170
ldc-clstr-sw18.paraccel.com,10.11.10.171
ldc-clstr-sw11.paraccel.com,10.11.10.166
remote1.paraccel.com,10.11.13.43
ldc-clstr-sw19.paraccel.com,10.11.10.172
qavm1.paraccel.com,10.11.13.41
itvm2-ilom.paraccel.com,10.11.10.127
itvm2.paraccel.com,10.11.10.126
ldc-clstr-sw20.paraccel.com,10.11.10.173
ldc-ps7.paraccel.com,10.11.10.182
veeam-proxy1.paraccel.com,10.11.13.74
ts-hadoop2.paraccel.com,10.11.13.56
ts-hadoop3.paraccel.com,10.11.13.57
ts-hadoop1.paraccel.com,10.11.13.55
sparqlbugs.paraccel.com,10.11.13.50
collabesxsrv-ilom.paraccel.com,10.11.10.76
sfsync.paraccel.com,10.11.13.47
nexsan1.paraccel.com,10.11.10.187
nexsan1a.paraccel.com,10.11.10.188
nexsan1b.paraccel.com,10.11.10.189
itvm16.paraccel.com,10.11.10.154
itvm16-ilom.paraccel.com,10.11.10.155
nexsan1a-ilom.paraccel.com,10.11.10.190
cloud64.paraccel.com,10.11.10.52
cloud64-ilom.paraccel.com,10.11.10.53
nexsan1b-ilom.paraccel.com,10.11.10.191
collabesxsrv.paraccel.com,10.11.10.75
ldc-psw9.paraccel.com,10.11.10.183
potato.paraccel.com,10.11.10.202
lemon.paraccel.com,10.11.10.184
informatica-win1.paraccel.com,10.11.10.121
cloud63.paraccel.com,10.11.10.50
cloud63-ilom.paraccel.com,10.11.10.51
ldc-fsw3.paraccel.com,10.11.10.179
ldc-fsw2.paraccel.com,10.11.10.178
collabdb-vm.paraccel.com,10.11.10.74
infocenter.paraccel.com,10.11.10.120
ldc-clstr-sw15.paraccel.com,10.11.10.168
salesvm0.paraccel.com,10.11.13.45
tintri.paraccel.com,10.11.13.53
tintri1.paraccel.com,10.11.13.54
anthill.paraccel.com,10.11.10.30
reportdb.paraccel.com,10.11.13.44
itvm0.paraccel.com,10.11.10.122
itvm1.paraccel.com,10.11.10.124
backup.paraccel.com,10.11.10.31
ldc-clstr-sw9.paraccel.com,10.11.10.164
ldc-clstr-sw10.paraccel.com,10.11.10.165
ldc-clstr-sw7.paraccel.com,10.11.10.163
cognos51.paraccel.com,10.11.10.73
cacti.paraccel.com,10.11.10.33
dash.paraccel.com,10.11.10.77
qa.paraccel.com,10.11.10.208
xenbuild.paraccel.com,10.11.13.83
paconsole-demo.paraccel.com,10.11.10.193
winit-ilom.paraccel.com,10.11.13.78
qavm0.paraccel.com,10.11.13.39
qavm0-ilom.paraccel.com,10.11.13.40
qa-shortdrone4.paraccel.com,10.11.13.31
qa-shortdrone5.paraccel.com,10.11.13.32
qa-mediumdrone3.paraccel.com,10.11.13.33
qa-mediumdrone4.paraccel.com,10.11.13.34
qa-mediumdrone5.paraccel.com,10.11.13.37
qa-mediumdrone6.paraccel.com,10.11.13.38
itvm3.paraccel.com,10.11.10.128
qa-ilom.paraccel.com,10.11.10.211
itvm4-ilom.paraccel.com,10.11.10.131
itvm4.paraccel.com,10.11.10.130
ws-rparmar.paraccel.com,10.11.13.80
ldc-clstr-sw14.paraccel.com,10.11.10.167
ws-sdixit.paraccel.com,10.11.13.81
itvm5-ilom.paraccel.com,10.11.10.132
itvm5.paraccel.com,10.11.10.133
vm-stig2.paraccel.com,10.11.13.75
qa-stig1.paraccel.com,10.11.13.76
itvm6-ilom.paraccel.com,10.11.10.134
itvm6.paraccel.com,10.11.10.135
ws-sperfilov.paraccel.com,10.11.13.82
itvm7-ilom.paraccel.com,10.11.10.136
hr.paraccel.com,10.11.10.119
doc1.paraccel.com,10.11.10.80
itvm7.paraccel.com,10.11.10.137
winit.paraccel.com,10.11.13.77
syslog.paraccel.com,10.11.13.51
smtprelay.paraccel.com,10.11.13.48
itvm8-ilom.paraccel.com,10.11.10.138
itvm8.paraccel.com,10.11.10.139
ws-bmckenna.paraccel.com,10.11.13.79
itvm14-ilom.paraccel.com,10.11.10.150
itvm9-ilom.paraccel.com,10.11.10.140
itvm9.paraccel.com,10.11.10.141
itvm10-ilom.paraccel.com,10.11.10.142
itvm10.paraccel.com,10.11.10.143
itvm14.paraccel.com,10.11.10.151
itvm11-ilom.paraccel.com,10.11.10.144
itvm11.paraccel.com,10.11.10.145
itvm15-ilom.paraccel.com,10.11.10.152
para-san2.paraccel.com,10.11.10.197
para-san2-spa.paraccel.com,10.11.10.198
para-san2-spb.paraccel.com,10.11.10.199
itvm12-ilom.paraccel.com,10.11.10.146
itvm12.paraccel.com,10.11.10.147
itvm15.paraccel.com,10.11.10.153
itvm13-ilom.paraccel.com,10.11.10.148
itvm13.paraccel.com,10.11.10.149
qa-build1.paraccel.com,10.11.10.209
qa-build2.paraccel.com,10.11.10.210
persistent-windows.paraccel.com,10.11.30.147
se-jmeter.paraccel.com,10.11.31.12
cloud24.paraccel.com,10.11.30.20
cloud20.paraccel.com,10.11.30.17
cloud21.paraccel.com,10.11.30.18
cloud23.paraccel.com,10.11.30.19
cloud110.paraccel.com,10.11.30.38
cloud89.paraccel.com,10.11.30.32
cloud106.paraccel.com,10.11.30.34
cloud107.paraccel.com,10.11.30.35
cloud108.paraccel.com,10.11.30.36
pfc10.paraccel.com,10.11.30.150
cloud109.paraccel.com,10.11.30.37
cloud62.paraccel.com,10.11.30.27
cloud113.paraccel.com,10.11.30.41
cloud112.paraccel.com,10.11.30.40
cloud111.paraccel.com,10.11.30.39
cloud90.paraccel.com,10.11.30.33
cloud88.paraccel.com,10.11.30.31
cloud87.paraccel.com,10.11.30.30
cloud114.paraccel.com,10.11.30.42
cloud65.paraccel.com,10.11.30.28
cloud66.paraccel.com,10.11.30.29
cloud126.paraccel.com,10.11.30.43
partner2.paraccel.com,10.11.30.144
cloud127.paraccel.com,10.11.30.44
cloud128.paraccel.com,10.11.30.45
cloud129.paraccel.com,10.11.30.46
cloud33.paraccel.com,10.11.30.26
pfc11.paraccel.com,10.11.30.152
se-sqlserver2012.paraccel.com,10.11.31.13
pfc4.paraccel.com,10.11.33.20
ussdr620-01.paraccel.com,10.11.33.20
pfc15.paraccel.com,10.11.33.21
ussdr720-10.paraccel.com,10.11.33.21
pfc10-vip.paraccel.com,10.11.30.151
cdh-trn1.paraccel.com,10.11.30.11
smtprelay7.paraccel.com,10.11.31.14
sales-nas2.paraccel.com,10.11.31.10
sales-nas1.paraccel.com,10.11.30.219
sales01.paraccel.com,10.11.30.218
fuzzylogix-dev.paraccel.com,10.11.30.89
cloud6.paraccel.com,10.11.30.15
cloud7.paraccel.com,10.11.30.16
partner-cluster.paraccel.com,10.11.30.141
partner1.paraccel.com,10.11.30.142
cloud2.paraccel.com,10.11.30.12
partner1ha.paraccel.com,10.11.30.143
cloud3.paraccel.com,10.11.30.13
persistent-padb5.paraccel.com,10.11.30.145
cloud4.paraccel.com,10.11.30.14
se-informatica.paraccel.com,10.11.31.11
looker.paraccel.com,10.11.30.130
fuzzylogix-dev2.paraccel.com,10.11.30.90
persistent-snap.paraccel.com,10.11.30.146
persistent-el5.paraccel.com,10.11.30.148
qahost32-ilom.paraccel.com,10.11.10.212
qahost33-ilom.paraccel.com,10.11.10.213
qahost34-ilom.paraccel.com,10.11.10.214
qahost35-ilom.paraccel.com,10.11.10.215
qahost36-ilom.paraccel.com,10.11.10.216
qahost37-ilom.paraccel.com,10.11.10.217
qahost38-ilom.paraccel.com,10.11.10.218
qahost39-ilom.paraccel.com,10.11.10.219
qahost40-ilom.paraccel.com,10.11.13.10
qahost41-ilom.paraccel.com,10.11.13.11
qahost42-ilom.paraccel.com,10.11.13.12
qahost43-ilom.paraccel.com,10.11.13.13
qahost48-ilom.paraccel.com,10.11.13.14
qahost49-ilom.paraccel.com,10.11.13.15
qahost50-ilom.paraccel.com,10.11.13.16
qahost51-ilom.paraccel.com,10.11.13.17
qahost52-ilom.paraccel.com,10.11.13.18
qahost53-ilom.paraccel.com,10.11.13.19
qahost54-ilom.paraccel.com,10.11.13.20
qahost55-ilom.paraccel.com,10.11.13.21
qahost56-ilom.paraccel.com,10.11.13.22
qahost57-ilom.paraccel.com,10.11.13.23
qahost58-ilom.paraccel.com,10.11.13.24
itvm3-ilom.paraccel.com,10.11.10.129
xencom129-ilom.paraccel.com,10.11.13.84
itvm1-ilom.paraccel.com,10.11.10.125
xencom131-ilom.paraccel.com,10.11.32.21
xencom132-ilom.paraccel.com,10.11.13.85
xencom133-ilom.paraccel.com,10.11.13.86
xencom134-ilom.paraccel.com,10.11.13.87
xencom135-ilom.paraccel.com,10.11.13.88
xencom136-ilom.paraccel.com,10.11.13.89
xencom137-ilom.paraccel.com,10.11.13.90
xencom138-ilom.paraccel.com,10.11.13.91
xencom139-ilom.paraccel.com,10.11.32.23
backup-ilom.paraccel.com,10.11.10.32
xencom140-ilom.paraccel.com,10.11.32.24
xencom141-ilom.paraccel.com,10.11.32.26
xencom142-ilom.paraccel.com,10.11.32.27
xencom144-ilom.paraccel.com,10.11.32.28
xencom145-ilom.paraccel.com,10.11.32.29
ucs1-ilom.paraccel.com,10.11.13.58
xencom192-ilom.paraccel.com,10.11.13.92
xencom193-ilom.paraccel.com,10.11.13.93
xencom194-ilom.paraccel.com,10.11.13.94
xencom195-ilom.paraccel.com,10.11.13.95
xencom196-ilom.paraccel.com,10.11.13.96
xencom197-ilom.paraccel.com,10.11.13.97
xencom198-ilom.paraccel.com,10.11.13.98
xencom199-ilom.paraccel.com,10.11.13.99
diablo-ilom.paraccel.com,10.11.10.79
xencom200-ilom.paraccel.com,10.11.13.100
xencom201-ilom.paraccel.com,10.11.13.101
xencom202-ilom.paraccel.com,10.11.13.102
xencom203-ilom.paraccel.com,10.11.13.103
cloud7-ilom.paraccel.com,10.11.10.38
cloud6-ilom.paraccel.com,10.11.10.37
xencom226-ilom.paraccel.com,10.11.13.104
cloud4-ilom.paraccel.com,10.11.10.36
cloud3-ilom.paraccel.com,10.11.10.35
cloud2-ilom.paraccel.com,10.11.10.34
xencom230-ilom.paraccel.com,10.11.13.105
xencom231-ilom.paraccel.com,10.11.13.106
xencom232-ilom.paraccel.com,10.11.13.107
xencom233-ilom.paraccel.com,10.11.13.108
xencom235-ilom.paraccel.com,10.11.13.109
xencom236-ilom.paraccel.com,10.11.13.110
xencom237-ilom.paraccel.com,10.11.13.111
xencom238-ilom.paraccel.com,10.11.13.112
xencom239-ilom.paraccel.com,10.11.13.113
xencom240-ilom.paraccel.com,10.11.13.114
cloud29-ilom.paraccel.com,10.11.10.47
xencom241-ilom.paraccel.com,10.11.13.115
cloud28-ilom.paraccel.com,10.11.10.46
xencom242-ilom.paraccel.com,10.11.13.116
cloud27-ilom.paraccel.com,10.11.10.45
xencom243-ilom.paraccel.com,10.11.13.117
cloud26-ilom.paraccel.com,10.11.10.44
xencom244-ilom.paraccel.com,10.11.13.118
cloud25-ilom.paraccel.com,10.11.10.43
xencom245-ilom.paraccel.com,10.11.13.119
xencom248-ilom.paraccel.com,10.11.13.120
xencom35-ilom.paraccel.com,10.11.13.121
xencom36-ilom.paraccel.com,10.11.13.122
xencom37-ilom.paraccel.com,10.11.13.123
xencom38-ilom.paraccel.com,10.11.13.124
xencom39-ilom.paraccel.com,10.11.13.125
itvm0-ilom.paraccel.com,10.11.10.123
xencom66-ilom.paraccel.com,10.11.13.126
xencom68-ilom.paraccel.com,10.11.13.127
xencom69-ilom.paraccel.com,10.11.13.128
xencom80-ilom.paraccel.com,10.11.13.129
xencom81-ilom.paraccel.com,10.11.13.130
xencom82-ilom.paraccel.com,10.11.13.131
xencom83-ilom.paraccel.com,10.11.13.132
xencom84-ilom.paraccel.com,10.11.13.133
xencom87-ilom.paraccel.com,10.11.13.134
cloud90-ilom.paraccel.com,10.11.10.59
cloud89-ilom.paraccel.com,10.11.10.58
cloud129-ilom.paraccel.com,10.11.10.72
cloud128-ilom.paraccel.com,10.11.10.71
cloud127-ilom.paraccel.com,10.11.10.70
cloud126-ilom.paraccel.com,10.11.10.69
ussdr620-01-ilom.paraccel.com,10.11.33.30
ussdr720-01-ilom.paraccel.com,10.11.33.31
ussdr720-02-ilom.paraccel.com,10.11.33.32
ussdr720-03-ilom.paraccel.com,10.11.33.33
ussdr720-04-ilom.paraccel.com,10.11.33.34
ussdr720-05-ilom.paraccel.com,10.11.33.35
ussdr720-06-ilom.paraccel.com,10.11.33.36
ussdr720-07-ilom.paraccel.com,10.11.33.37
ussdr720-08-ilom.paraccel.com,10.11.33.38
ussdr720-09-ilom.paraccel.com,10.11.33.39
ussdr720-10-ilom.paraccel.com,10.11.33.40
ussdr720-11-ilom.paraccel.com,10.11.33.41
ussdr720-12-ilom.paraccel.com,10.11.33.42
ussdr720-13-ilom.paraccel.com,10.11.33.43
ussdr720-14-ilom.paraccel.com,10.11.33.44
qa-clstr21-ilom.paraccel.com,10.11.13.25
qa-clstr22-ilom.paraccel.com,10.11.13.26
qa-clstr23-ilom.paraccel.com,10.11.13.27
qa-clstr24-ilom.paraccel.com,10.11.13.28
qa-clstr25-ilom.paraccel.com,10.11.13.29
qa-clstr26-ilom.paraccel.com,10.11.13.30
qavm1-ilom.paraccel.com,10.11.13.42
cloud33-ilom.paraccel.com,10.11.10.48
cloud24-ilom.paraccel.com,10.11.10.42
cloud23-ilom.paraccel.com,10.11.10.41
cloud21-ilom.paraccel.com,10.11.10.40
cloud20-ilom.paraccel.com,10.11.10.39
cloud66-ilom.paraccel.com,10.11.10.55
cloud65-ilom.paraccel.com,10.11.10.54
cloud62-ilom.paraccel.com,10.11.10.49
cloud110-ilom.paraccel.com,10.11.10.64
cloud109-ilom.paraccel.com,10.11.10.63
cloud108-ilom.paraccel.com,10.11.10.62
cloud107-ilom.paraccel.com,10.11.10.61
cloud106-ilom.paraccel.com,10.11.10.60
cloud111-ilom.paraccel.com,10.11.10.65
cloud112-ilom.paraccel.com,10.11.10.66
cloud113-ilom.paraccel.com,10.11.10.67
cloud88-ilom.paraccel.com,10.11.10.57
salesvm0-ilom.paraccel.com,10.11.13.46
cloud87-ilom.paraccel.com,10.11.10.56
cloud114-ilom.paraccel.com,10.11.10.68
xencom35ha.paraccel.com,10.11.31.59
xencom141ha.paraccel.com,10.11.31.32
xencom198ha.paraccel.com,10.11.31.43
xencom131.paraccel.com,10.11.32.20
xencom132.paraccel.com,10.11.31.24
xencom133.paraccel.com,10.11.31.25
xencom134.paraccel.com,10.11.31.26
xencom135.paraccel.com,10.11.31.27
xencom136.paraccel.com,10.11.32.22
xencom137.paraccel.com,10.11.31.28
xencom138.paraccel.com,10.11.31.29
xencom139.paraccel.com,10.11.31.30
xencom140.paraccel.com,10.11.31.31
xencom141.paraccel.com,10.11.32.25
xencom142.paraccel.com,10.11.31.33
xencom144.paraccel.com,10.11.31.34
xencom145.paraccel.com,10.11.31.35
xencom192.paraccel.com,10.11.31.36
xencom193.paraccel.com,10.11.31.37
xencom194.paraccel.com,10.11.31.38
xencom195.paraccel.com,10.11.31.39
xencom196.paraccel.com,10.11.31.40
xencom197.paraccel.com,10.11.31.41
xencom198.paraccel.com,10.11.31.42
xencom199.paraccel.com,10.11.31.44
xencom200.paraccel.com,10.11.31.45
xencom201.paraccel.com,10.11.31.46
xencom202.paraccel.com,10.11.31.47
xencom203.paraccel.com,10.11.31.48
xencom238.paraccel.com,10.11.31.49
xencom239.paraccel.com,10.11.31.50
xencom240.paraccel.com,10.11.31.51
cloud29.paraccel.com,10.11.30.25
xencom241.paraccel.com,10.11.31.52
cloud28.paraccel.com,10.11.30.24
xencom242.paraccel.com,10.11.31.53
cloud27.paraccel.com,10.11.30.23
xencom243.paraccel.com,10.11.31.54
cloud26.paraccel.com,10.11.30.22
xencom244.paraccel.com,10.11.31.55
cloud25.paraccel.com,10.11.30.21
xencom245.paraccel.com,10.11.31.56
xencom248.paraccel.com,10.11.31.57
xencom35.paraccel.com,10.11.31.58
xencom39.paraccel.com,10.11.31.60
xencom66.paraccel.com,10.11.31.61
xencom68.paraccel.com,10.11.31.62
xencom69.paraccel.com,10.11.31.63
kickstart.paraccel.com,10.11.30.94
xencom80.paraccel.com,10.11.31.64
xencom81.paraccel.com,10.11.31.66
xencom82.paraccel.com,10.11.31.67
xencom83.paraccel.com,10.11.31.68
xencom84.paraccel.com,10.11.31.69
xencom87.paraccel.com,10.11.31.70
xencom80ha.paraccel.com,10.11.31.65
bsoft2-dev.paraccel.com,10.11.30.10
info54.paraccel.com,10.11.30.93
qa-mapr1.paraccel.com,10.11.30.157
qa-mapr2.paraccel.com,10.11.30.158
linuxha-rhel64-1.paraccel.com,10.11.30.125
linuxha-rhel64-2.paraccel.com,10.11.30.126
linuxha-rhel64-3.paraccel.com,10.11.30.127
linuxha-rhel64-4.paraccel.com,10.11.30.128
linuxha-centos64-1.paraccel.com,10.11.30.113
linuxha-centos64-2.paraccel.com,10.11.30.114
linuxha-centos64-3.paraccel.com,10.11.30.115
linuxha-centos64-4.paraccel.com,10.11.30.116
mapr-dev1.paraccel.com,10.11.30.131
mapr-dev2.paraccel.com,10.11.30.132
linuxha-centos58-1.paraccel.com,10.11.30.105
linuxha-centos58-2.paraccel.com,10.11.30.106
linuxha-centos58-3.paraccel.com,10.11.30.107
linuxha-centos58-4.paraccel.com,10.11.30.108
linuxha-centos62-1.paraccel.com,10.11.30.109
linuxha-centos62-2.paraccel.com,10.11.30.110
linuxha-centos62-3.paraccel.com,10.11.30.111
qa-windows1.paraccel.com,10.11.30.164
linuxha-centos62-4.paraccel.com,10.11.30.112
winbuild1.paraccel.com,10.11.30.167
qa-mstr1.paraccel.com,10.11.30.159
qacognos3.paraccel.com,10.11.32.16
qa-reportdb.paraccel.com,10.11.30.161
qa-td14.paraccel.com,10.11.30.163
qa-td13.paraccel.com,10.11.30.162
qa-teradata1.paraccel.com,10.11.32.14
qa-teradata2.paraccel.com,10.11.32.15
ucs1.paraccel.com,10.11.31.21
linuxha-rhel62-1.paraccel.com,10.11.30.121
linuxha-rhel62-2.paraccel.com,10.11.30.122
linuxha-rhel62-3.paraccel.com,10.11.30.123
linuxha-rhel62-4.paraccel.com,10.11.30.124
linuxha-rhel58-1.paraccel.com,10.11.30.117
linuxha-rhel58-2.paraccel.com,10.11.30.118
linuxha-rhel58-3.paraccel.com,10.11.30.119
linuxha-rhel58-4.paraccel.com,10.11.30.120
qa-clstr21.paraccel.com,10.11.30.200
linuxha-vip.paraccel.com,10.11.30.129
qa-mediumdrone1.paraccel.com,10.11.30.215
qa-remotedrone-el6.paraccel.com,10.11.30.160
qa-remotedrone-win7.paraccel.com,10.11.32.13
qa-shortdrone6.paraccel.com,10.11.30.209
qa-mediumdrone7.paraccel.com,10.11.30.210
qa-clstr22.paraccel.com,10.11.30.201
qa-drone42.paraccel.com,10.11.30.211
qa-shortdrone7.paraccel.com,10.11.30.212
qa-mediumdrone8.paraccel.com,10.11.30.213
qa-drone45.paraccel.com,10.11.30.214
qa-mediumdrone2.paraccel.com,10.11.30.216
qa-hadoop1.paraccel.com,10.11.30.154
qa-hadoop2.paraccel.com,10.11.30.155
qa-hadoop3.paraccel.com,10.11.30.156
ts-win2k8.paraccel.com,10.11.31.20
qa-clstr23.paraccel.com,10.11.30.203
hdp-dev1.paraccel.com,10.11.30.91
hdp-dev2.paraccel.com,10.11.30.92
winbuild2.paraccel.com,10.11.30.166
qa-shortdrone9.paraccel.com,10.11.32.18
qa-shortdrone8.paraccel.com,10.11.32.17
qa-build3.paraccel.com,10.11.32.12
cdh-dev1.paraccel.com,10.11.32.10
cdh-dev2.paraccel.com,10.11.32.11
qa-mediumdrone9.paraccel.com,10.11.30.217
qa-clstr24.paraccel.com,10.11.30.204
qa-mediumdrone10.paraccel.com,10.11.32.19
qa-clstr25.paraccel.com,10.11.30.205
qa-clstr26.paraccel.com,10.11.30.206
qa-windows2.paraccel.com,10.11.30.165
qahost32.paraccel.com,10.11.30.177
qahost33.paraccel.com,10.11.30.178
qahost34.paraccel.com,10.11.30.179
qahost35.paraccel.com,10.11.30.180
qahost36.paraccel.com,10.11.30.181
qahost37.paraccel.com,10.11.30.182
qahost38.paraccel.com,10.11.30.183
qahost39.paraccel.com,10.11.30.184
qahost40.paraccel.com,10.11.30.185
qahost41.paraccel.com,10.11.30.186
qahost42.paraccel.com,10.11.30.187
qahost48.paraccel.com,10.11.30.189
qahost49.paraccel.com,10.11.30.190
qahost50.paraccel.com,10.11.30.191
qahost51.paraccel.com,10.11.30.192
qahost52.paraccel.com,10.11.30.193
qahost53.paraccel.com,10.11.30.194
qahost54.paraccel.com,10.11.30.195
qahost55.paraccel.com,10.11.30.196
qahost56.paraccel.com,10.11.30.197
qahost57.paraccel.com,10.11.30.198
qahost58.paraccel.com,10.11.30.199
qacognos2.paraccel.com,10.11.30.168
qahost43.paraccel.com,10.11.30.188
ts-failover1.paraccel.com,10.11.31.15
ts-failover5.paraccel.com,10.11.31.19
ts-failover2.paraccel.com,10.11.31.16
ts-failover3.paraccel.com,10.11.31.17
ts-failover4.paraccel.com,10.11.31.18
qa-clstr22ha.paraccel.com,10.11.30.202
qa72.paraccel.com,10.11.30.169
qa73.paraccel.com,10.11.30.170
qa74.paraccel.com,10.11.30.171
qa75.paraccel.com,10.11.30.172
qa76.paraccel.com,10.11.30.173
qa77.paraccel.com,10.11.30.174
qa78.paraccel.com,10.11.30.175
qa79.paraccel.com,10.11.30.176
eng11-ilom.paraccel.com,10.11.10.81
eng12-ilom.paraccel.com,10.11.10.82
eng13-ilom.paraccel.com,10.11.10.83
eng14-ilom.paraccel.com,10.11.10.84
eng15-ilom.paraccel.com,10.11.10.85
eng16-ilom.paraccel.com,10.11.10.86
eng17-ilom.paraccel.com,10.11.10.87
eng18-ilom.paraccel.com,10.11.10.88
eng19-ilom.paraccel.com,10.11.10.89
eng20-ilom.paraccel.com,10.11.10.90
eng21-ilom.paraccel.com,10.11.10.91
eng22-ilom.paraccel.com,10.11.10.92
eng23-ilom.paraccel.com,10.11.10.93
eng24-ilom.paraccel.com,10.11.10.94
eng25-ilom.paraccel.com,10.11.10.95
eng26-ilom.paraccel.com,10.11.10.96
eng27-ilom.paraccel.com,10.11.10.97
eng28-ilom.paraccel.com,10.11.10.98
eng29-ilom.paraccel.com,10.11.10.99
eng30-ilom.paraccel.com,10.11.10.100
eng31-ilom.paraccel.com,10.11.10.101
eng32-ilom.paraccel.com,10.11.10.102
eng33-ilom.paraccel.com,10.11.10.103
eng34-ilom.paraccel.com,10.11.10.104
eng35-ilom.paraccel.com,10.11.10.105
eng36-ilom.paraccel.com,10.11.10.106
eng37-ilom.paraccel.com,10.11.10.107
eng38-ilom.paraccel.com,10.11.10.108
eng39-ilom.paraccel.com,10.11.10.109
eng40-ilom.paraccel.com,10.11.10.110
eng41-ilom.paraccel.com,10.11.10.111
eng42-ilom.paraccel.com,10.11.10.112
eng43-ilom.paraccel.com,10.11.10.113
eng44-ilom.paraccel.com,10.11.10.114
eng45-ilom.paraccel.com,10.11.10.115
eng46-ilom.paraccel.com,10.11.10.116
eng47-ilom.paraccel.com,10.11.10.117
potato-ilom.paraccel.com,10.11.10.203
eng49-ilom.paraccel.com,10.11.10.118
eng39-standby.paraccel.com,10.11.30.77
eng11.paraccel.com,10.11.30.48
eng12.paraccel.com,10.11.30.49
eng13.paraccel.com,10.11.30.50
eng14.paraccel.com,10.11.30.51
eng15.paraccel.com,10.11.30.52
eng16.paraccel.com,10.11.30.53
eng17.paraccel.com,10.11.30.54
eng18.paraccel.com,10.11.30.55
eng19.paraccel.com,10.11.30.56
eng20.paraccel.com,10.11.30.57
paconnect-lead.paraccel.com,10.11.30.134
paconnect-comp3.paraccel.com,10.11.30.135
paconnect-comp2.paraccel.com,10.11.30.136
eng21.paraccel.com,10.11.30.58
eng22.paraccel.com,10.11.30.59
eng23.paraccel.com,10.11.30.60
eng24.paraccel.com,10.11.30.61
eng25.paraccel.com,10.11.30.62
eng26.paraccel.com,10.11.30.63
eng27.paraccel.com,10.11.30.64
eng28.paraccel.com,10.11.30.65
eng29.paraccel.com,10.11.30.66
eng30.paraccel.com,10.11.30.67
eng31.paraccel.com,10.11.30.68
eng32.paraccel.com,10.11.30.69
eng33.paraccel.com,10.11.30.70
eng34.paraccel.com,10.11.30.71
eng35.paraccel.com,10.11.30.72
eng36.paraccel.com,10.11.30.73
eng37.paraccel.com,10.11.30.74
eng38.paraccel.com,10.11.30.75
eng39.paraccel.com,10.11.30.78
eng40.paraccel.com,10.11.30.79
eng41.paraccel.com,10.11.30.80
eng42.paraccel.com,10.11.30.81
eng43.paraccel.com,10.11.30.82
eng44.paraccel.com,10.11.30.83
eng45.paraccel.com,10.11.30.84
eng46.paraccel.com,10.11.30.85
eng47.paraccel.com,10.11.30.86
eng48.paraccel.com,10.11.30.87
eng49.paraccel.com,10.11.30.88
eng39-primary.paraccel.com,10.11.30.76
eng33-vm1.paraccel.com,10.11.11.69
eng33-vm2.paraccel.com,10.11.11.70
eng33-vm3.paraccel.com,10.11.11.71
eng33-vm4.paraccel.com,10.11.11.72
eng33-vm5.paraccel.com,10.11.11.73
eng33-vm6.paraccel.com,10.11.11.74
eng42-vm1.paraccel.com,10.11.11.84
eng42-vm2.paraccel.com,10.11.11.85
eng42-vm3.paraccel.com,10.11.11.86
eng42-vm4.paraccel.com,10.11.11.87
eng41-vm1.paraccel.com,10.11.11.80
eng41-vm2.paraccel.com,10.11.11.81
eng41-vm3.paraccel.com,10.11.11.82
eng41-vm4.paraccel.com,10.11.11.83
eng40-vm1.paraccel.com,10.11.11.75
eng40-vm2.paraccel.com,10.11.11.76
eng40-vm3.paraccel.com,10.11.11.77
eng40-vm4.paraccel.com,10.11.11.78
eng40-vm5.paraccel.com,10.11.11.79
ts-mindspark.paraccel.com,10.11.11.123
qa54-linuxha.paraccel.com,10.11.11.105
qa32.paraccel.com,10.11.11.98
qa34.paraccel.com,10.11.11.99
qa35.paraccel.com,10.11.11.100
qa36.paraccel.com,10.11.11.101
qa37.paraccel.com,10.11.11.102
qa43.paraccel.com,10.11.11.103
qa54.paraccel.com,10.11.11.104
qa55.paraccel.com,10.11.11.106
qa56.paraccel.com,10.11.11.107
qa57.paraccel.com,10.11.11.108
qa58.paraccel.com,10.11.11.109
qa59.paraccel.com,10.11.11.110
qa-cloudera1.paraccel.com,10.11.11.94
qa-cloudera2.paraccel.com,10.11.11.95
qa-cloudera3.paraccel.com,10.11.11.96
qa68.paraccel.com,10.11.11.111
qa69.paraccel.com,10.11.11.112
qa70.paraccel.com,10.11.11.113
qa71.paraccel.com,10.11.11.114
qa25.paraccel.com,10.11.11.97
ws-emartin.paraccel.com,10.11.11.145
ws-gszedenits.paraccel.com,10.11.11.146
ws-rprakash2.paraccel.com,10.11.11.162
ws-brumsby.paraccel.com,10.11.11.136
ws-asinha.paraccel.com,10.11.11.128
ws-akeen.paraccel.com,10.11.11.126
ws-senglert.paraccel.com,10.11.11.164
ws-rcole.paraccel.com,10.11.11.159
ws-rdyskant.paraccel.com,10.11.11.160
ws-senglert2.paraccel.com,10.11.11.165
ws-jrangavajhula.paraccel.com,10.11.11.152
ws-jyates.paraccel.com,10.11.11.153
ts-training.paraccel.com,10.11.11.121
ws-igarish1.paraccel.com,10.11.11.147
ws-schen.paraccel.com,10.11.11.163
ws-boaz3.paraccel.com,10.11.11.132
bdesantis5.paraccel.com,10.11.11.60
bdesantis6.paraccel.com,10.11.11.61
ws-joechen.paraccel.com,10.11.11.150
diablo2.paraccel.com,10.11.11.66
ws-crogers.paraccel.com,10.11.11.140
diablo3.paraccel.com,10.11.11.67
diablo4.paraccel.com,10.11.11.68
ws-lhoward.paraccel.com,10.11.11.156
ws-btammisetti.paraccel.com,10.11.11.137
ws-sfrolich.paraccel.com,10.11.11.166
ws-anayak.paraccel.com,10.11.11.127
ts-rdp.paraccel.com,10.11.11.120
ws-jpowers2.paraccel.com,10.11.11.151
plannervm1.paraccel.com,10.11.11.93
ws-delson2.paraccel.com,10.11.11.143
ws-dsteinhoff2.paraccel.com,10.11.11.144
ws-vradanovic3.paraccel.com,10.11.11.167
ws-riwanik.paraccel.com,10.11.11.161
ws-boaz.paraccel.com,10.11.11.130
para-ad.paraccel.com,10.11.11.124
ws-bchu2.paraccel.com,10.11.11.133
ws-bzane2.paraccel.com,10.11.11.138
ws-boaz2.paraccel.com,10.11.11.131
ws-mpimpale.paraccel.com,10.11.11.157
win8-dev.paraccel.com,10.11.11.125
ts-win7.paraccel.com,10.11.11.122
ws-bchu3.paraccel.com,10.11.11.134
ws-bzane3.paraccel.com,10.11.11.139
ws-prane.paraccel.com,10.11.11.158
ws-jmoore2.paraccel.com,10.11.11.149
bsoft6-dev.paraccel.com,10.11.11.62
ws-bchu4.paraccel.com,10.11.11.135
bsoft7-dev.paraccel.com,10.11.11.63
ws-azane.paraccel.com,10.11.11.129
ws-dtracy.paraccel.com,10.11.11.141
ws-dtracy2.paraccel.com,10.11.11.142
ws-jballard.paraccel.com,10.11.11.148
ws-kpatel.paraccel.com,10.11.11.154
ws-kpatel2.paraccel.com,10.11.11.155
sc-emartin1.paraccel.com,10.11.11.115
sc-bzane1.paraccel.com,10.11.11.116
sc-bchu1.paraccel.com,10.11.11.117
sc-jyates1.paraccel.com,10.11.11.118
bsoft8-dev.paraccel.com,10.11.11.64
bsoft9-dev.paraccel.com,10.11.11.65
grost2.paraccel.com,10.11.11.89
grost3.paraccel.com,10.11.11.90
grost4.paraccel.com,10.11.11.91
grost5.paraccel.com,10.11.11.92
grost1.paraccel.com,10.11.11.88
sc-smurthy.paraccel.com,10.11.11.119
ldc-ds3-rtr.paraccel.com,10.11.10.176
para-fw1.paraccel.com,10.11.10.200
