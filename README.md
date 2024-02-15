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
            [ --help|-h]

         where:

             before_date: yyyy-mm-dd; end date of the date range, if not present, will be the set to current date
             after_date: yyyy-mm-dd; start date of the date range, if not present, will be one month earlier than before_date
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
        query_modcount -a 2023-10-01 -b 2023-12-31 -s proj -n 20
        query_modcount -a 2023-10-01 -b 2023-12-31 -s proj -n -1
        query_modcount -V
        query_modcount -h
