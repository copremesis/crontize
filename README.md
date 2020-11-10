crontize
========

a nice way to monitor arbitrary/legacy cron jobs

#crontize.rb:

Crontize is a client-server model that collects & controlls/filters the start and stop of each command.

* You can than design a secondary filter based on a set of UI rules. 
* You can also chart the display of an event regardless of it's length of time or name or platform run on.

The one fact that if it is in a crontab means it's a command line. (incredibly obvious)
Yet cause we (i) are lazy we can use this as the provided input for this applicaiton ...
so to use this application effectively you would replace your current crontab entries with something like:
```
SHELL=/bin/sh

17 *	* * *	root    cd / && run-parts --report /etc/cron.hourly
25 6	* * *	root	test -x /usr/sbin/anacron || ( cd / && run-parts --report /etc/cron.daily )
47 6	* * 7	root	test -x /usr/sbin/anacron || ( cd / && run-parts --report /etc/cron.weekly )
52 6	1 * *	root	test -x /usr/sbin/anacron || ( cd / && run-parts --report /etc/cron.monthly )
#


25 6	* * *	root /some/path/crontize.rb -c "./yourcommand" -d  "a description"
```
Now this is where the magic happens ...


this program will send a restful request to and action controller charting data ...
This way no matter what machine this is being run from it will appear to have
all the information it needs from this simple command line interface.

TODO:
output formats can be as:

JSON
XML
HTML
av params
your own
even javascript


#before this ever gets run the only thing we care of is is protecting and executing the command line
#for now we'll send fake ones and worry about edge casing while testing

Fri Sep 24 15:41:18 CDT 2010


Latest news is we want to do a wrapper for some of our resque processing ...

I'm thinking that this would be the simplest way to alter any code that is run from
somehting other than cron

as crontize expects a command line as it's input we can write it so that it can also expect a block.
