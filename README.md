# queryModCount
query SCC modcount data to provide usage info. sorted by module, project or user perspective. 

## Usage:
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



##NOTES: call command without any parameters will show the short command line usage message:
     $ query_modcount
     
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
            [ --help|-h]
            