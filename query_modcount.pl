#!/usr/local/bin/perl

use strict;
use Getopt::Long qw(GetOptions);
use Time::Piece;
use Time::Seconds;
use lib "/usr/local/sge/scv/nodes";
use SCC_SGE_Data;
use Cwd qw(getcwd);

my %mc_data = ();

# set command line options:

my $before_date = ""; # date range start date
my $after_date = ""; # date range end date
my $sortby=""; # default sort by module count in decreasing order, other possible choices can be sorted by project, or by user
my $line_limit=10;
my $verbose=0;

my %opts=();
my $VERSION='20240123';
my $EARLIEST='2017-09-01'; # the earliest date start collecting modcount stats.
my $LATEST=localtime->strftime('%Y-%m-%d');


########################################################
# USAGE
#
my $USAGE =<<USAGE;

     Usage:

         query_modcount 
            [ --before_date|-b before_date ]
            [ --after_date|-a after_date ]
            [ --sortby|-s module|proj|user ]
            [ --line_limit|-n total_lines_to_show ]
            [ --verbose|-v ] 
            [ --version|-V ]
            [ --help|-h]

         where:

             before_date: yyyy-mm-dd; end date of the date range, if not present, or the date given is beyond current date, it will be the set to current date
             after_date: yyyy-mm-dd; start date of the date range, 1) if not present, will be one month earlier than before_date;2) the earliest date is 2017-09-01
             sortby: the field we will use to sort the count, by default, using a decreasing order. 
                 module: sort module usage count according to module, from the most used module to the least 
                 proj: sort by module usage count according to project, from the most used project to least
                 user: sort by module usage count according to user, from the most frequent user to the least
             line_limit: total lines to display in the result, 
                 default is 10
                 -1 means show all
             verbose: if verbose is true, print out all the detailed count data at the individula module/project/user level. All the numbers in the parentheses are the number of usage count associated. Otherwise, print only the top level numbers. 
             version: show the version of the tool
             help:  Prints out this help message

    Examples:
        query_modcount
        query_modcount -a 2023-10-01 -b 2023-12-31 -s proj
        query_modcount --after_date 2023-10-01 --before_date 2023-12-31 --sortby proj
        query_modcount -a 2023-10-01 -b 2023-12-31 -s user -n 20
        query_modcount -a 2023-10-01 -b 2023-12-31 -s user -n -1
        query_modcount -V
        query_modcount -h

USAGE
#
######################################################

GetOptions(
    "help|h" => \$opts{help},
    "after_date|a=s" => \$opts{after_date},
    "before_date|b=s" => \$opts{before_date},
    "sortby|s=s" => \$opts{sortby},
    "line_limit|n=i" => \$opts{line},
    "version|V" => \$opts{version},
    "verbose|v" => \$opts{verbose},
    );

if($opts{help}) {
    print "$USAGE";
    exit;
}

if($opts{version}) {
    print "query_modcount -- query the statistics of module usage on SCC.\n";
    print "Version: $VERSION\n";
    exit;
}    
    
# get the actual before and after date from commandline: 
if ( defined($opts{after_date}) ) {
    $after_date=$opts{after_date};
    # if end date is not provided, then use 1 month default range
    if( !defined($opts{before_date}) ) {
	$before_date=Time::Piece->strptime($after_date, '%Y-%m-%d')->add_months(1) -> strftime('%Y-%m-%d');
    }
    else {
	$before_date=$opts{before_date};
    }
}
elsif ( defined($opts{before_date}) ) {
    $before_date=$opts{before_date};
    # since after_date not defined, we set the 1 month range default:
    $after_date=Time::Piece->strptime($before_date, '%Y-%m-%d')->add_months(-1) -> strftime('%Y-%m-%d');
}
else {
    # both start/end dates are not defined, set one month default from current date:
    $before_date=$LATEST; # set today's date
    $after_date=Time::Piece->strptime($before_date, '%Y-%m-%d')->add_months(-1) -> strftime('%Y-%m-%d');
}

# check date boundary:
die "start date can not be earlier than $EARLIEST\n" if($after_date lt $EARLIEST);
if( $before_date gt $LATEST) {
    $before_date=$LATEST;
    print "\n**********************\n";
    print "WARNING: end date provided is beyond the current date. Reset to today's date, $LATEST";
    print "\n**********************\n";

}

if( defined($opts{sortby})) {
    if( $opts{sortby} eq "module"
     || $opts{sortby} eq "proj"
     || $opts{sortby} eq "user"
	) {
	$sortby=$opts{sortby};
    }
    else {
	print "Unknown sortby field, please check.\n";
        exit;
    }
}
else {
    $sortby = "module"; # set sortby module as default
}

if( defined($opts{line})) {
    $line_limit = $opts{line};
}
else {
    $line_limit = 10; # set default line limit = 10
}

if( defined($opts{verbose})) {
    $verbose = $opts{verbose};
}
else {
    $verbose = 0; # set default to output only briefs at the top level
}


# read in all the modcount data
get_csv_data($after_date, $before_date, $sortby, \%mc_data);

#print "DONE with reading data\n";

output_result($sortby, \%mc_data, $line_limit, $verbose);


#print "\n\nDone!\n";


######################
sub get_csv_data() {
    my ($after, $before, $sortby, $mc_data) = @_;
    my $data_dir='/projectnb/rcsmetrics/modcounter/data/daily/';
    my $tmp_csv='/scratch/mc_all.csv';
 
    # get the start month:
    my $starty=substr($after, 2, 2);
    my $startm=substr($after,5,2);

    # get the end month: 
    my $endy=substr($before, 2, 2);
    my $endm=substr($before,5,2);

    # get the list of csv file:
    my @csv_list=();
    my ($ms, $me);
    
    for my $y ($starty..$endy) {
	if ($y>$starty) {
	    $ms=1;
	}
	else {
	    $ms=$startm;
	}
	if($y < $endy) {
	    $me=12;
	}
	else {
	    $me=$endm;
	}

	for my $m ($ms..$me) {
    #	    push @csv_list, sprintf("%s/%02d%02d\.csv", $data_dir, $y,$m);
    	    push @csv_list, sprintf("%02d%02d\.csv", $y,$m);
	}
    }
    my $work_dir=getcwd();
    chdir($data_dir);
    system("cat " . join(" ", @csv_list) . " > $tmp_csv");
    chdir($work_dir);

    # simple code:
#    system("cat $data_dir/*.csv > $tmp_csv");    

    # now get the data from the range of dates:
    # file format:
    # mod_method can be 'load', 'switch', maybe 'purge' too. But so far we haven't encounter a single one. So for now, let's put off the filtering
    # project='none' means the module was loaded on login nodes.
# date,app,version,project,user,mod_method,n
# 2024-01-01,R,3.5.1,none,jma03,load,2
# 2024-01-01,R,3.5.1,none,jy1004,load,2
# 2024-01-01,R,3.5.1,none,kzarada,load,1
# 2024-01-01,R,3.6.0,none,kelley27,load,1
# 2024-01-01,R,3.6.0,none,mpyatkov,load,7

    open IN, "<$tmp_csv";
    # now store data according to the output need:
    if($sortby eq "module") {
	while(my $line=<IN>) {
	    my @cols = split(',', $line);
	    next if $line=~/^date/;
	    next if $cols[0] lt $after;
	    last if $cols[0] gt $before;
	    # here we including everything
	    $mc_data->{$cols[1]}{ver_list}{$cols[2]}{proj_list}{$cols[3]}+=$cols[6];
	    $mc_data->{$cols[1]}{ver_list}{$cols[2]}{user_list}{$cols[4]}+=$cols[6];
	    $mc_data->{$cols[1]}{ver_list}{$cols[2]}{total_count}+=$cols[6];
	    $mc_data->{$cols[1]}{total_count}+=$cols[6];	    
	}
	close IN;
    }
    elsif($sortby eq "proj") {
	while(my $line=<IN>) {
	    my @cols = split(',', $line);
	    next if $line=~/^date/;
	    next if $cols[0] lt $after;
	    last if $cols[0] gt $before;
	    # here we including everything
	    $mc_data->{$cols[3]}{mod_list}{$cols[1] . "/" . $cols[2]}+=$cols[6];
	    $mc_data->{$cols[3]}{user_list}{$cols[4]}+=$cols[6];
	    $mc_data->{$cols[3]}{total_count}+=$cols[6];
	}
	close IN;
    }
    else {# #($sortby eq "user") {
	while(my $line=<IN>) {
	    my @cols = split(',', $line);
	    next if $line=~/^date/;
	    next if $cols[0] lt $after;
	    last if $cols[0] gt $before;
	    # here we including everything
	    $mc_data->{$cols[4]}{mod_list}{$cols[1] . "/" . $cols[2]}+=$cols[6];
	    $mc_data->{$cols[4]}{proj_list}{$cols[3]}+=$cols[6];
	    $mc_data->{$cols[4]}{total_count}+=$cols[6];
	}
	close IN;
    }

    # clean up:
    system("rm -f $tmp_csv");
}

#####################
sub output_result {
    my ($sortby, $mc_data, $line_number, $verbose) = @_;

    if ($sortby eq "module") { #sort by module
	if($verbose) {
	    if($line_limit != -1) {
		print_verbose_by_module($sortby, $mc_data, $line_limit);
	    }
	    else {
		printall_verbose_by_module($sortby, $mc_data);
	    }
	} # print verbose
	else {
	    if($line_limit != -1) {
		print_by_module($sortby, $mc_data, $line_limit);
	    }
	    else {
		printall_by_module($sortby, $mc_data);
	    }  
	} # print brief
    } # end of sort by module name
    elsif ($sortby eq "proj") {
	if($verbose) {
	    if($line_limit != -1) {
		print_verbose_by_proj($sortby, $mc_data, $line_limit);
	    }
	    else {
		printall_verbose_by_proj($sortby, $mc_data);
	    }
	} # print verbose
	else {
	    if($line_limit != -1) {
		print_by_proj($sortby, $mc_data, $line_limit);
	    }
	    else {
		printall_by_proj($sortby, $mc_data);
	    }
	}
    } # end of sort by project
    else { #if ($sortby eq "user") {
	if($verbose) {
	    if($line_limit != -1) {
		print_verbose_by_user($sortby, $mc_data, $line_limit);
	    }
	    else {
		printall_verbose_by_user($sortby, $mc_data);
	    }
	} # print verbose
	else {
	    if($line_limit != -1) {
		print_by_user($sortby, $mc_data, $line_limit);
	    }
	    else {
		printall_by_user($sortby, $mc_data);
	    }
	}
    } # end of sort by user

} 

sub print_by_module {
    my ($sortby, $mc_data, $line_limit) = @_;
    my $lc=0;
    my $header="SCC Usage sort by $sortby count from $after_date to $before_date:";
    print "=" x length($header);
    print "\n";
    print $header; 
    print "\n";
    print "=" x length($header);
    print "\n\n";
    
	foreach my $m (sort{ $mc_data{$b}{total_count} <=> $mc_data{$a}{total_count} } keys %{$mc_data}) { #sort by total count of all versions of a module
	    $lc++;
	    print "$m ($mc_data->{$m}{total_count})";
	    print "\n";
	    foreach my $v (sort {$mc_data->{$m}{ver_list}{$b}{total_count} <=> $mc_data->{$m}{ver_list}{$a}{total_count}} keys %{$mc_data->{$m}{ver_list}}) {
		print "$m/$v (" . $mc_data->{$m}{ver_list}{$v}{total_count} . ")";
		print "\n";
		
	    }
	    print "-"x20;
	    print "\n";
	    last if $lc==$line_limit; 
	}

} # end print_by_module()


sub printall_by_module {
    my ($sortby, $mc_data, $line_limit) = @_;
    my $header="SCC Usage sort by $sortby count from $after_date to $before_date:";
    print "=" x length($header);
    print "\n";
    print $header; 
    print "\n";
    print "=" x length($header);
    print "\n\n";
    
	foreach my $m (sort{ $mc_data{$b}{total_count} <=> $mc_data{$a}{total_count} } keys %{$mc_data}) { #sort by total count of all versions of a module
	    print "$m ($mc_data->{$m}{total_count})";
	    print "\n";
	    foreach my $v (sort {$mc_data->{$m}{ver_list}{$b}{total_count} <=> $mc_data->{$m}{ver_list}{$a}{total_count}} keys %{$mc_data->{$m}{ver_list}}) {
		print "$m/$v (" . $mc_data->{$m}{ver_list}{$v}{total_count} . ")";
		print "\n";
		
	    }
	    print "-"x20;
	    print "\n";
	}

} # end printall_by_module()


sub print_verbose_by_module {
    my ($sortby, $mc_data, $line_limit) = @_;
    my $lc=0;
    my $header="SCC Usage sort by $sortby count from $after_date to $before_date:";
    print "=" x length($header);
    print "\n";
    print $header; 
    print "\n";
    print "=" x length($header);
    print "\n\n";
    
	foreach my $m (sort{ $mc_data{$b}{total_count} <=> $mc_data{$a}{total_count} } keys %{$mc_data}) { #sort by total count of all versions of a module
	    $lc++;
	    print "$m ($mc_data->{$m}{total_count})";
	    print "\n";
	    foreach my $v (sort {$mc_data->{$m}{ver_list}{$b}{total_count} <=> $mc_data->{$m}{ver_list}{$a}{total_count}} keys %{$mc_data->{$m}{ver_list}}) {
		print "$m/$v (" . $mc_data->{$m}{ver_list}{$v}{total_count} . ")";
		print "\n";
	        print "\t Project_list: ( ";
		print "$_($mc_data->{$m}{ver_list}{$v}{proj_list}{$_})," for (sort {$mc_data->{$m}{ver_list}{$v}{proj_list}{$b}<=>$mc_data->{$m}{ver_list}{$v}{proj_list}{$a}} keys %{$mc_data->{$m}{ver_list}{$v}{proj_list}});
		print " )\n";
	        print "\t User_list: ( ";
		print "$_($mc_data->{$m}{ver_list}{$v}{user_list}{$_})," for (sort {$mc_data->{$m}{ver_list}{$v}{user_list}{$b}<=>$mc_data->{$m}{ver_list}{$v}{user_list}{$a}} keys %{$mc_data->{$m}{ver_list}{$v}{user_list}});
		print " )\n\n";
		
	    }
	    print "-"x20;
	    print "\n";
	    last if $lc==$line_limit; 
	}

} # end print_verbose_by_module() 

sub printall_verbose_by_module {
    my ($sortby, $mc_data) = @_;
    my $header="SCC Usage sort by $sortby count from $after_date to $before_date:";
    print "=" x length($header);
    print "\n";
    print $header; 
    print "\n";
    print "=" x length($header);
    print "\n\n";
    
	foreach my $m (sort{ $mc_data{$b}{total_count} <=> $mc_data{$a}{total_count} } keys %{$mc_data}) { #sort by total count of all versions of a module
	    print "$m ($mc_data->{$m}{total_count})";
	    print "\n";
	    foreach my $v (sort {$mc_data->{$m}{ver_list}{$b}{total_count} <=> $mc_data->{$m}{ver_list}{$a}{total_count}} keys %{$mc_data->{$m}{ver_list}}) {
		print "$m/$v (" . $mc_data->{$m}{ver_list}{$v}{total_count} . ")";
		print "\n";
	        print "\t Project_list: ( ";
		print "$_($mc_data->{$m}{ver_list}{$v}{proj_list}{$_})," for (sort {$mc_data->{$m}{ver_list}{$v}{proj_list}{$b}<=>$mc_data->{$m}{ver_list}{$v}{proj_list}{$a}} keys %{$mc_data->{$m}{ver_list}{$v}{proj_list}});
		print " )\n";
	        print "\t User_list: ( ";
		print "$_($mc_data->{$m}{ver_list}{$v}{user_list}{$_})," for (sort {$mc_data->{$m}{ver_list}{$v}{user_list}{$b}<=>$mc_data->{$m}{ver_list}{$v}{user_list}{$a}} keys %{$mc_data->{$m}{ver_list}{$v}{user_list}});
		print " )\n\n";
		
	    }
	    print "-"x20;
	    print "\n";
	}

} # end printall_verbose_by_module()



sub print_by_proj {
    my ($sortby, $mc_data, $line_limit) = @_;
    my $lc=0;
    my $header="SCC Usage sort by $sortby count from $after_date to $before_date:";
    print "=" x length($header);
    print "\n";
    print $header; 
    print "\n";
    print "=" x length($header);
    print "\n\n";

    foreach my $p (sort{ $mc_data{$b}{total_count} <=> $mc_data{$a}{total_count} } keys %{$mc_data}) { #sort by total count of all projects on SCC that ever used a module
	    $lc++;
	    print "$p ($mc_data->{$p}{total_count})";
	    print "\n";
	    last if $lc==$line_limit; 
    }

} # end print_by_proj() 

sub printall_by_proj {
    my ($sortby, $mc_data) = @_;
    my $header="SCC Usage sort by $sortby count from $after_date to $before_date:";
    print "=" x length($header);
    print "\n";
    print $header; 
    print "\n";
    print "=" x length($header);
    print "\n\n";

    foreach my $p (sort{ $mc_data{$b}{total_count} <=> $mc_data{$a}{total_count} } keys %{$mc_data}) { #sort by total count of all projects on SCC that ever used a module
	    print "$p ($mc_data->{$p}{total_count})";
	    print "\n";

    }

} # end printall_by_proj()



sub print_verbose_by_proj {
    my ($sortby, $mc_data, $line_limit) = @_;
    my $lc=0;
    my $header="SCC Usage sort by $sortby count from $after_date to $before_date:";
    print "=" x length($header);
    print "\n";
    print $header; 
    print "\n";
    print "=" x length($header);
    print "\n\n";

    foreach my $p (sort{ $mc_data{$b}{total_count} <=> $mc_data{$a}{total_count} } keys %{$mc_data}) { #sort by total count of all projects on SCC that ever used a module
	    $lc++;
	    print "$p ($mc_data->{$p}{total_count})";
	    print "\n";
	    print "\t Module_list: ( ";
	    print "$_($mc_data->{$p}{mod_list}{$_})," for (sort {$mc_data->{$p}{mod_list}{$b}<=>$mc_data->{$p}{mod_list}{$a}} keys %{$mc_data->{$p}{mod_list}});
	    print " )\n";
	    print "\t User_list: ( ";
	    print "$_($mc_data->{$p}{user_list}{$_})," for (sort {$mc_data->{$p}{user_list}{$b}<=>$mc_data->{$p}{user_list}{$a}} keys %{$mc_data->{$p}{user_list}});
	    print " )\n\n";
	    print "-"x20;
	    print "\n";
	    last if $lc==$line_limit; 
    }

} # end print_verbose_by_proj() 


sub printall_verbose_by_proj {
    my ($sortby, $mc_data) = @_;
    my $header="SCC Usage sort by $sortby count from $after_date to $before_date:";
    print "=" x length($header);
    print "\n";
    print $header; 
    print "\n";
    print "=" x length($header);
    print "\n\n";

    foreach my $p (sort{ $mc_data{$b}{total_count} <=> $mc_data{$a}{total_count} } keys %{$mc_data}) { #sort by total count of all projects on SCC that ever used a module
	    print "$p ($mc_data->{$p}{total_count})";
	    print "\n";
	    print "\t Module_list: ( ";
	    print "$_($mc_data->{$p}{mod_list}{$_})," for (sort {$mc_data->{$p}{mod_list}{$b}<=>$mc_data->{$p}{mod_list}{$a}} keys %{$mc_data->{$p}{mod_list}});
	    print " )\n";
	    print "\t User_list: ( ";
	    print "$_($mc_data->{$p}{user_list}{$_})," for (sort {$mc_data->{$p}{user_list}{$b}<=>$mc_data->{$p}{user_list}{$a}} keys %{$mc_data->{$p}{user_list}});
	    print " )\n\n";
	    print "-"x20;
	    print "\n";
    }

} # end printall_verbose_by_proj() 


sub print_by_user {
    my ($sortby, $mc_data, $line_limit) = @_;
    my $lc=0;
    my $header="SCC Usage sort by $sortby count from $after_date to $before_date:";
    print "=" x length($header);
    print "\n";
    print $header; 
    print "\n";
    print "=" x length($header);
    print "\n\n";

    foreach my $u (sort{ $mc_data{$b}{total_count} <=> $mc_data{$a}{total_count} } keys %{$mc_data}) { #sort by total count of all module loads on SCC by user
	    $lc++;
	    print "$u ($mc_data->{$u}{total_count})";
	    print "\n";
	    last if $lc==$line_limit; 
    }

} # end print_by_user() 

sub printall_by_user {
    my ($sortby, $mc_data) = @_;
    my $header="SCC Usage sort by $sortby count from $after_date to $before_date:";
    print "=" x length($header);
    print "\n";
    print $header; 
    print "\n";
    print "=" x length($header);
    print "\n\n";

    foreach my $u (sort{ $mc_data{$b}{total_count} <=> $mc_data{$a}{total_count} } keys %{$mc_data}) { #sort by total count of all module counts on SCC by a user
	    print "$u ($mc_data->{$u}{total_count})";
	    print "\n";
    }

} # end printall_by_user()



sub print_verbose_by_user {
    my ($sortby, $mc_data, $line_limit) = @_;
    my $lc=0;
    my $header="SCC Usage sort by $sortby count from $after_date to $before_date:";
    print "=" x length($header);
    print "\n";
    print $header; 
    print "\n";
    print "=" x length($header);
    print "\n\n";

    foreach my $u (sort{ $mc_data{$b}{total_count} <=> $mc_data{$a}{total_count} } keys %{$mc_data}) { #sort by total count of all projects on SCC that ever used a module
	    $lc++;
	    print "$u ($mc_data->{$u}{total_count})";
	    print "\n";
	    print "\t Module_list: ( ";
	    print "$_($mc_data->{$u}{mod_list}{$_})," for (sort {$mc_data->{$u}{mod_list}{$b}<=>$mc_data->{$u}{mod_list}{$a}} keys %{$mc_data->{$u}{mod_list}});
	    print " )\n";
	    print "\t Project_list: ( ";
	    print "$_($mc_data->{$u}{proj_list}{$_})," for (sort {$mc_data->{$u}{proj_list}{$b}<=>$mc_data->{$u}{proj_list}{$a}} keys %{$mc_data->{$u}{proj_list}});
	    print " )\n\n";
	    print "-"x20;
	    print "\n";
	    last if $lc==$line_limit; 
    }

} # end print_verbose_by_user()


sub printall_verbose_by_user {
    my ($sortby, $mc_data) = @_;
    my $header="SCC Usage sort by $sortby count from $after_date to $before_date:";
    print "=" x length($header);
    print "\n";
    print $header; 
    print "\n";
    print "=" x length($header);
    print "\n\n";

    foreach my $u (sort{ $mc_data{$b}{total_count} <=> $mc_data{$a}{total_count} } keys %{$mc_data}) { #sort by total count of all projects on SCC that ever used a module
	    print "$u ($mc_data->{$u}{total_count})";
	    print "\n";
	    print "\t Module_list: ( ";
	    print "$_($mc_data->{$u}{mod_list}{$_})," for (sort {$mc_data->{$u}{mod_list}{$b}<=>$mc_data->{$u}{mod_list}{$a}} keys %{$mc_data->{$u}{mod_list}});
	    print " )\n";
	    print "\t Project_list: ( ";
	    print "$_($mc_data->{$u}{proj_list}{$_})," for (sort {$mc_data->{$u}{proj_list}{$b}<=>$mc_data->{$u}{proj_list}{$a}} keys %{$mc_data->{$u}{proj_list}});
	    print " )\n\n";
	    print "-"x20;
	    print "\n";
    }

} # end printall_verbose_by_user()

