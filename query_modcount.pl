#!/usr/local/bin/perl

use strict;
use Getopt::Long qw(GetOptions);
use Time::Piece;
use Time::Seconds;
#use lib "/usr/local/sge/scv/nodes";
#use SCC_SGE_Data;
use Cwd qw(getcwd);
use File::Temp qw/tempfile tempdir/; # fix the issue https://github.com/bu-rcs/queryModCount/issues/3
Getopt::Long::Configure("no_ignore_case");

my %mc_data = ();

# set command line options:

my $before_date = ""; # date range start date
my $after_date = ""; # date range end date
my $sortby="module"; # default sort by module count in decreasing order, other possible choices can be sorted by project, or by user
my $line_limit=-1;
my $verbose=0;

my %opts=();
my $VERSION='v2.1.0';
my $EARLIEST='2017-09-01'; # the earliest date start collecting modcount stats.
my $LATEST=(Time::Piece->new-ONE_DAY)-> strftime('%Y-%m-%d'); # the last day has module count data available is yesterday.Today's data has not yet been calculated and recorded.


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
            [ --module|-m modname]
            [ --user|-u login]
            [ --proj|-p projname]
            [ --mlist|-M modlist_file]
            [ --ulist|-U userlist_file]
            [ --plist|-P projlist_file]
            [ --help|-h]

         where:

             before_date: yyyy-mm-dd; end date of the date range, if not present, or the date given is beyond current date, it will be the set to one day before the current date
             after_date: yyyy-mm-dd; start date of the date range, 1) if not present, will be one month earlier than before_date;2) the earliest date is 2017-09-01
             sortby: the field we will use to sort the count, by default, using a decreasing order.
                 module: sort module usage count according to module, from the most used module to the least
                 proj: sort by module usage count according to project, from the most used project to least
                 user: sort by module usage count according to user, from the most frequent user to the least
             line_limit: total lines to display in the result,
                 -1 means show all, and it is also the default
             verbose: if verbose is true, print out all the detailed count data at the individula module/project/user level. All the numbers in the parentheses are the number of usage count associated. Otherwise, print only the top level numbers.
             version: show the version of the tool
             module: specific module to look for, if given in modname/modver form, then the result will also be limited to the particular version only
             user: look for specific user by his/her login name
             proj: look for specific project usage count
             mlist: file containing a list of module/version entries (one per line); outputs a CSV summary for each
             ulist: file containing a list of user logins (one per line); outputs a CSV summary for each
             plist: file containing a list of project names (one per line); outputs a CSV summary for each
             help:  Prints out this help message

    Example #1 get the brief/long description about the command:
        query_modcount # brief
        query_modcount -h  # long
        query_modcount -V  # version info

    Example #2 get module statistics sort by module name (this is default):
        query_modcount -a 2023-10-01  # all module usages after 2023-10-01, sort by module name
        query_modcount --after_date 2023-10-01 --before_date 2023-12-31 -v -p ms-dental  # get detailed usage for 'ms-dental' project from 2023-10-01 to 2023-12-31 sort by module
        these two commands are equivalent:
	    query_modcount -a 2023-10-01 -p rcs-user -s module
	    query_modcount -a 2023-10-01 -p rcs-user

    Example #3 get module statistics sort by project name:
	query_modcount -s proj # return all module usage
	query_modcount -a 2023-10-01 -s proj # return all module usages after 2023-10-01
	query_modcount --after_date 2023-10-01 --before_date 2023-12-31 --sortby proj -v -p ms-dental  # get detailed usage for 'ms-dental' project from 2023-10-01 to 2023-12-31

    Example #4 get module statistics sort by user name:
        query_modcount -s user
        query_modcount -a 2023-10-01 -b 2023-12-31 -s user -n 20
        query_modcount -a 2023-10-01 -b 2023-12-31 -s user -v

    Example #5 batch CSV summary for a list of modules:
        query_modcount -a 2025-08-12 -b 2026-08-11 -M modlist.txt

    Example #6 batch CSV summary for a list of users:
        query_modcount -a 2025-08-12 -b 2026-08-11 -U userlist.txt

    Example #7 batch CSV summary for a list of projects:
        query_modcount -a 2025-08-12 -b 2026-08-11 -P projlist.txt

        

USAGE
#
######################################################

########################################################
# USAGE_SHORT
#
my $USAGE_SHORT =<<USAGE_SHORT;

     Usage:

         query_modcount 
            [ --before_date|-b before_date ]
            [ --after_date|-a after_date ]
            [ --sortby|-s module|proj|user ]
            [ --line_limit|-n total_lines_to_show ]
            [ --verbose|-v ] 
            [ --version|-V ]
            [ --module|-m modname]
            [ --user|-u login]
            [ --proj|-p projname]
            [ --mlist|-M modlist_file]
            [ --ulist|-U userlist_file]
            [ --plist|-P projlist_file]
            [ --help|-h]

USAGE_SHORT
#
######################################################

# check if the command is called without any arguments
# if so, show the help message:
die $USAGE_SHORT if @ARGV < 1;

GetOptions(
    "help|h" => \$opts{help},
    "after_date|a=s" => \$opts{after_date},
    "before_date|b=s" => \$opts{before_date},
    "sortby|s=s" => \$opts{sortby},
    "line_limit|n=i" => \$opts{line},
    "version|V" => \$opts{version},
    "verbose|v" => \$opts{verbose},
    "module|m=s" => \$opts{modname},
    "user|u=s" => \$opts{login},
    "proj|p=s" => \$opts{projname},
    "mlist|M=s" => \$opts{modlist},
    "ulist|U=s" => \$opts{usrlist},
    "plist|P=s" => \$opts{prjlist},
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
    if( defined($opts{before_date}) ) {
	$before_date=$opts{before_date};
    }
    else {
    #	$before_date=Time::Piece->strptime($after_date, '%Y-%m-%d')->add_years(1) -> strftime('%Y-%m-%d');
	$before_date=$LATEST; # set the default end time to be today. 
    }
}
elsif ( defined($opts{before_date}) ) {
    $before_date=$opts{before_date};
    # since after_date not defined, we set the 1 year range by default:
    $after_date=Time::Piece->strptime($before_date, '%Y-%m-%d')->add_years(-1) -> strftime('%Y-%m-%d');
}
else {
    # both start/end dates are not defined, set one year default from current date:
    $before_date=$LATEST; # set today's date
    $after_date=Time::Piece->strptime($before_date, '%Y-%m-%d')->add_years(-1) -> strftime('%Y-%m-%d');
}

# check date boundary:
die "start date can not be later than end date\n" if($after_date gt $before_date);
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

if( defined($opts{verbose})) {
    $verbose = $opts{verbose};
}


# auto-set sortby for batch list modes
if (defined($opts{usrlist}) && $opts{usrlist} ne "") {
    $sortby = "user";
} elsif (defined($opts{prjlist}) && $opts{prjlist} ne "") {
    $sortby = "proj";
}

# read in all the modcount data
get_csv_data($after_date, $before_date, $sortby, \%mc_data);

#print "DONE with reading data\n";

if(defined($opts{modlist}) &&  $opts{modlist} ne "") {
    output_moduse_summary($opts{modlist},\%mc_data);
}
elsif (defined($opts{usrlist}) &&  $opts{usrlist} ne "") {
    output_usruse_summary($opts{usrlist},\%mc_data);
}
elsif (defined($opts{prjlist}) &&  $opts{prjlist} ne "") {
    output_prjuse_summary($opts{prjlist},\%mc_data);
}
else {
    output_result($sortby, \%mc_data, $line_limit, $verbose);
}

#print "\n\nDone!\n";


######################
sub get_csv_data() {
    my ($after, $before, $sortby, $mc_data) = @_;
    my $data_dir='/projectnb/rcsmetrics/modcounter/data/daily/';
    my $tmp_csv=tempdir . '/mc_all.csv';
    
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
	    my $csv=sprintf("%02d%02d\.csv", $y,$m);
    	    push @csv_list, $csv if -e "$data_dir/$csv";
	}
    }
    my $work_dir=getcwd();
    chdir($data_dir);
    system("cat " . join(" ", @csv_list) . " > $tmp_csv");
    chdir($work_dir);
    if (defined($opts{modname}) && ($opts{modname} ne "")) {
	my $tmp2=$tmp_csv . ".2";
	my ($mname, $mver) = split("/", $opts{modname});
	if (defined($mver)) {
	   # use -F option to match literally
	   system("grep -F '$mname' $tmp_csv | grep -F '$mver' > $tmp2");
	   system("mv $tmp2 $tmp_csv");
	}
	else {
	   system("grep '$opts{modname}' $tmp_csv > $tmp2");
	   system("mv $tmp2 $tmp_csv");
	}
    }
    
    if (defined($opts{login}) && ($opts{login} ne "")) {
	my $tmp2=$tmp_csv . ".2";
	system("grep '$opts{login}' $tmp_csv > $tmp2");
	system("mv $tmp2 $tmp_csv");
    }

    if (defined($opts{projname}) && ($opts{projname} ne "")) {
	my $tmp2=$tmp_csv . ".2";
	system("grep '$opts{login}' $tmp_csv > $tmp2");
	system("mv $tmp2 $tmp_csv");
    }

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
    while(my $line=<IN>) {
	my @cols = split(',', $line);
	next if $line=~/^date/;
	next if $cols[0] lt $after;
	last if $cols[0] gt $before;
# check if proj/module/user name is/are specified
	next if (defined($opts{modname}) && ($cols[1] ne $opts{modname} && "$cols[1]/$cols[2]" ne $opts{modname} ));
	next if (defined($opts{projname}) && ($cols[3] ne $opts{projname}));
	next if (defined($opts{login}) && ($cols[4] ne $opts{login}));
	if($sortby eq "module") {
	    $mc_data->{$cols[1]}{ver_list}{$cols[2]}{proj_list}{$cols[3]}+=$cols[6];
	    $mc_data->{$cols[1]}{ver_list}{$cols[2]}{user_list}{$cols[4]}+=$cols[6];
	    $mc_data->{$cols[1]}{ver_list}{$cols[2]}{total_count}+=$cols[6];
	    $mc_data->{$cols[1]}{total_count}+=$cols[6];
	    # track distinct (user, date) pairs for user_day_count metric
	    $mc_data->{$cols[1]}{ver_list}{$cols[2]}{user_day_set}{"$cols[4]|$cols[0]"} = 1;
	    $mc_data->{$cols[1]}{user_day_set}{"$cols[4]|$cols[0]"} = 1;
	}
	elsif($sortby eq "proj") {
	    $mc_data->{$cols[3]}{mod_list}{$cols[1] . "/" . $cols[2]}+=$cols[6];
	    $mc_data->{$cols[3]}{user_list}{$cols[4]}+=$cols[6];
	    $mc_data->{$cols[3]}{total_count}+=$cols[6];
	}
	elsif($sortby eq "user") {
	    $mc_data->{$cols[4]}{mod_list}{$cols[1] . "/" . $cols[2]}+=$cols[6];
	    $mc_data->{$cols[4]}{proj_list}{$cols[3]}+=$cols[6];
	    $mc_data->{$cols[4]}{total_count}+=$cols[6];
	}
    } # end while loop
    close IN;
    system("rm $tmp_csv");
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

sub print_header {
    my $header="SCC Usage sort by $sortby from $after_date to $before_date";
    print "=" x length($header);
    print "\n";
    print $header; 
    print "\n";
    print "=" x length($header);
    print "\n";
    my $header_spec = "";
    $header_spec = " USER Login: $opts{login}\n" if defined($opts{login}); 
    $header_spec .= " MODULE: $opts{modname}\n" if defined($opts{modname}); 
    $header_spec .= " PROJECT: $opts{projname}\n" if defined($opts{projname});
    print "$header_spec\n" if $header_spec ne "";
    print "\n";
}

sub print_by_module {
    my ($sortby, $mc_data, $line_limit) = @_;
    my $lc=0;
    print_header();
    foreach my $m (sort{ $mc_data{$b}{total_count} <=> $mc_data{$a}{total_count} } keys %{$mc_data}) { #sort by total count of all versions of a module
	    $lc++;
	    my $udc_m = scalar keys %{$mc_data->{$m}{user_day_set}};
	    print "$m ($mc_data->{$m}{total_count} loads, $udc_m user-days)";
	    print "\n";
	    foreach my $v (sort {$mc_data->{$m}{ver_list}{$b}{total_count} <=> $mc_data->{$m}{ver_list}{$a}{total_count}} keys %{$mc_data->{$m}{ver_list}}) {
		my $udc_v = scalar keys %{$mc_data->{$m}{ver_list}{$v}{user_day_set}};
		print "$m/$v (" . $mc_data->{$m}{ver_list}{$v}{total_count} . " loads, $udc_v user-days)";
		print "\n";
	    }
	    print "-"x20;
	    print "\n";
	    last if $lc==$line_limit;
	}

} # end print_by_module()


sub printall_by_module {
    my ($sortby, $mc_data, $line_limit) = @_;
    print_header();
	foreach my $m (sort{ $mc_data{$b}{total_count} <=> $mc_data{$a}{total_count} } keys %{$mc_data}) { #sort by total count of all versions of a module
	    my $udc_m = scalar keys %{$mc_data->{$m}{user_day_set}};
	    print "$m ($mc_data->{$m}{total_count} loads, $udc_m user-days)";
	    print "\n";
	    foreach my $v (sort {$mc_data->{$m}{ver_list}{$b}{total_count} <=> $mc_data->{$m}{ver_list}{$a}{total_count}} keys %{$mc_data->{$m}{ver_list}}) {
		my $udc_v = scalar keys %{$mc_data->{$m}{ver_list}{$v}{user_day_set}};
		print "$m/$v (" . $mc_data->{$m}{ver_list}{$v}{total_count} . " loads, $udc_v user-days)";
		print "\n";
	    }
	    print "-"x20;
	    print "\n";
	}

} # end printall_by_module()


sub print_verbose_by_module {
    my ($sortby, $mc_data, $line_limit) = @_;
    my $lc=0;
    print_header();
	foreach my $m (sort{ $mc_data{$b}{total_count} <=> $mc_data{$a}{total_count} } keys %{$mc_data}) { #sort by total count of all versions of a module
	    $lc++;
	    my $udc_m = scalar keys %{$mc_data->{$m}{user_day_set}};
	    print "$m ($mc_data->{$m}{total_count} loads, $udc_m user-days)";
	    print "\n";
	    foreach my $v (sort {$mc_data->{$m}{ver_list}{$b}{total_count} <=> $mc_data->{$m}{ver_list}{$a}{total_count}} keys %{$mc_data->{$m}{ver_list}}) {
		my $udc_v = scalar keys %{$mc_data->{$m}{ver_list}{$v}{user_day_set}};
		my $np = scalar keys %{$mc_data->{$m}{ver_list}{$v}{proj_list}};
		my $nu = scalar keys %{$mc_data->{$m}{ver_list}{$v}{user_list}};
		print "$m/$v (" . $mc_data->{$m}{ver_list}{$v}{total_count} . " loads, $udc_v user-days)";
		print "\n";
	        print "\t Project_list($np): ( ";
		print "$_($mc_data->{$m}{ver_list}{$v}{proj_list}{$_})," for (sort {$mc_data->{$m}{ver_list}{$v}{proj_list}{$b}<=>$mc_data->{$m}{ver_list}{$v}{proj_list}{$a}} keys %{$mc_data->{$m}{ver_list}{$v}{proj_list}});
		print " )\n";
	        print "\t User_list($nu): ( ";
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
    print_header();
	foreach my $m (sort{ $mc_data{$b}{total_count} <=> $mc_data{$a}{total_count} } keys %{$mc_data}) { #sort by total count of all versions of a module
	    my $udc_m = scalar keys %{$mc_data->{$m}{user_day_set}};
	    print "$m ($mc_data->{$m}{total_count} loads, $udc_m user-days)";
	    print "\n";
	    foreach my $v (sort {$mc_data->{$m}{ver_list}{$b}{total_count} <=> $mc_data->{$m}{ver_list}{$a}{total_count}} keys %{$mc_data->{$m}{ver_list}}) {
		my $udc_v = scalar keys %{$mc_data->{$m}{ver_list}{$v}{user_day_set}};
		my $np = scalar keys %{$mc_data->{$m}{ver_list}{$v}{proj_list}};
		my $nu = scalar keys %{$mc_data->{$m}{ver_list}{$v}{user_list}};
		print "$m/$v (" . $mc_data->{$m}{ver_list}{$v}{total_count} . " loads, $udc_v user-days)";
		print "\n";
	        print "\t Project_list($np): ( ";
		print "$_($mc_data->{$m}{ver_list}{$v}{proj_list}{$_})," for (sort {$mc_data->{$m}{ver_list}{$v}{proj_list}{$b}<=>$mc_data->{$m}{ver_list}{$v}{proj_list}{$a}} keys %{$mc_data->{$m}{ver_list}{$v}{proj_list}});
		print " )\n";
	        print "\t User_list($nu): ( ";
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

    print_header();
    
    foreach my $p (sort{ $mc_data{$b}{total_count} <=> $mc_data{$a}{total_count} } keys %{$mc_data}) { #sort by total count of all projects on SCC that ever used a module
	    $lc++;
	    print "$p ($mc_data->{$p}{total_count})";
	    print "\n";
	    last if $lc==$line_limit; 
    }

} # end print_by_proj() 

sub printall_by_proj {
    my ($sortby, $mc_data) = @_;
    print_header();
    foreach my $p (sort{ $mc_data{$b}{total_count} <=> $mc_data{$a}{total_count} } keys %{$mc_data}) { #sort by total count of all projects on SCC that ever used a module
	    print "$p ($mc_data->{$p}{total_count})";
	    print "\n";

    }

} # end printall_by_proj()



sub print_verbose_by_proj {
    my ($sortby, $mc_data, $line_limit) = @_;
    my $lc=0;
    print_header();
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
    print_header();
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
    print_header();
    foreach my $u (sort{ $mc_data{$b}{total_count} <=> $mc_data{$a}{total_count} } keys %{$mc_data}) { #sort by total count of all module loads on SCC by user
	    $lc++;
	    print "$u ($mc_data->{$u}{total_count})";
	    print "\n";
	    last if $lc==$line_limit; 
    }

} # end print_by_user() 

sub printall_by_user {
    my ($sortby, $mc_data) = @_;
    print_header();
    foreach my $u (sort{ $mc_data{$b}{total_count} <=> $mc_data{$a}{total_count} } keys %{$mc_data}) { #sort by total count of all module counts on SCC by a user
	    print "$u ($mc_data->{$u}{total_count})";
	    print "\n";
    }

} # end printall_by_user()



sub print_verbose_by_user {
    my ($sortby, $mc_data, $line_limit) = @_;
    my $lc=0;

    print_header();
    
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
    print_header();
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


###########################################
#  output_moduse_summary
#  date: 07-19-2024; updated 2026-09-03
###########################################
sub output_moduse_summary {

    my ($mlist, $mc_data) = @_;
    print join(",", "dateFrom", "dateTo", "module/version", "unique_users", "unique_projects", "total_loads", "user_day_count");
    print "\n";
    open(my $ML, "<", $mlist) or die "can't open $mlist: $!\n";
    my @modlist = <$ML>;
    close $ML;
    foreach my $minfo (sort @modlist) {
	chomp $minfo;
	next if $minfo =~ /^\s*$/;
	my ($m, $mv) = split("/", $minfo, 2);
	if (defined($mv) && $mv ne "") {
	    my $udc = scalar keys %{$mc_data->{$m}{ver_list}{$mv}{user_day_set}};
	    print join(",", $after_date, $before_date, "$m/$mv",
		scalar(keys %{$mc_data->{$m}{ver_list}{$mv}{user_list}}),
		scalar(keys %{$mc_data->{$m}{ver_list}{$mv}{proj_list}}),
		$mc_data->{$m}{ver_list}{$mv}{total_count} // 0,
		$udc);
	    print "\n";
	}
	else { # print all versions
	    foreach my $v (sort {$mc_data->{$m}{ver_list}{$b}{total_count} <=> $mc_data->{$m}{ver_list}{$a}{total_count}} keys %{$mc_data->{$m}{ver_list}}) {
		my $udc = scalar keys %{$mc_data->{$m}{ver_list}{$v}{user_day_set}};
		print join(",", $after_date, $before_date, "$m/$v",
		    scalar(keys %{$mc_data->{$m}{ver_list}{$v}{user_list}}),
		    scalar(keys %{$mc_data->{$m}{ver_list}{$v}{proj_list}}),
		    $mc_data->{$m}{ver_list}{$v}{total_count} // 0,
		    $udc);
		print "\n";
            } # end foreach $v
	} # end if-else
    } # end foreach minfo

} # end output_moduse_summary


###########################################
#  output_usruse_summary
#  date: 07-19-2024; updated 2026-09-03
###########################################
sub output_usruse_summary {

    my ($ulist, $mc_data) = @_;
    print join(",", "dateFrom", "dateTo", "user_login", "unique_modvers", "unique_projects", "total_loads");
    print "\n";
    open(my $UL, "<", $ulist) or die "can't open $ulist: $!\n";
    my @users = <$UL>;
    close $UL;
    foreach my $uinfo (sort @users) {
	chomp $uinfo;
	next if $uinfo =~ /^\s*$/;
	my $u = $uinfo;
	print join(",", $after_date, $before_date, $u,
	    scalar(keys %{$mc_data->{$u}{mod_list}}),
	    scalar(keys %{$mc_data->{$u}{proj_list}}),
	    $mc_data->{$u}{total_count} // 0);
	print "\n";
    } # end foreach uinfo

} # end output_usruse_summary


###########################################
#  output_prjuse_summary
#  date: 2026-09-03
###########################################
sub output_prjuse_summary {

    my ($plist, $mc_data) = @_;
    print join(",", "dateFrom", "dateTo", "project", "unique_modvers", "unique_users", "total_loads");
    print "\n";
    open(my $PL, "<", $plist) or die "can't open $plist: $!\n";
    my @projs = <$PL>;
    close $PL;
    foreach my $pinfo (sort @projs) {
	chomp $pinfo;
	next if $pinfo =~ /^\s*$/;
	my $p = $pinfo;
	print join(",", $after_date, $before_date, $p,
	    scalar(keys %{$mc_data->{$p}{mod_list}}),
	    scalar(keys %{$mc_data->{$p}{user_list}}),
	    $mc_data->{$p}{total_count} // 0);
	print "\n";
    } # end foreach pinfo

} # end output_prjuse_summary
