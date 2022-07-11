
# Date manipulation library.
# The routines within can convert a clearcase format time to its
#  component parts (suitable for feeding to timelocal().
# And given a number of seconds since the epoch, return a clearcase
# format date

# XXX note that these routines are not symetrical.  I suspect cctime needs
# to be changed

#require 'timelocal.pl';


%daynum     = ('Sun', 0 , 'Mon', 1, 'Tue', 2, 'Wed', 3, 'Thu', 4, 'Fri', 5, 'Sat', 6);
%monthnum   = (
        Jan, 0, Feb, 1, Mar, 2, Apr, 3, May, 4, Jun, 5,
        Jul, 6, Aug, 7, Sep, 8, Oct, 9, Nov, 10, Dec, 11
);

#-----------------------------------------------------------------------
# given a ClearCase format time turn it into it's component parts
# this returns a list just like localtime
#
# This routine would be suitable to call like so:
#	$seconds = &timelocal(&uncctime($time));
#
#  date-time   :=  date.time | date | time | now
#  date        :=  day-of-week | long-date
#  day-of-week :=  today | yesterday | Sunday | .. | Saturday | Sun | .. | Sat
#  long-date   :=  d[d]-month[-[yy]yy]
#  month       :=  January | ... | December | Jan | ... | Dec
#  time        :=  h[h]:m[m][:s[s]]
#
sub uncctime
{
        local($str) = @_;
	local($begintime) = time;
        local($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)
		= localtime($begintime);
	local($adjtime);
        local($timezone);

	# replace yesterday and today
	$str =~ s/\btoday\b/$mday-$ctime::MoY[$mon]-$year/;

	if ($str =~ /\byesterday\b/)
	{
		$adjtime = $begintime - 86400;		#24 hours ago
        	local($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)
			= localtime($adjtime);
		$str =~ s/\byesterday\b/$mday-$ctime::MoY[$mon]-$year/;
	}

	if ($str eq "now")
	{
		# do nothing
	}
	elsif ($str =~ /^(\w\w\w)\w*$/)
	{
		$error++ unless (defined $daynum{$1});
		$adjtime = $begintime - ($wday-$daynum{$1})*86400;
		($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)
			= localtime($adjtime);
		$hour = $min = $sec = 0;
	}
	elsif ($str =~ /^(\w\w\w)\w*\.(\d+):(\d+):?(\d+)?/)
	{
		$error++ unless (defined $daynum{$1});
		$adjtime = $begintime - ($wday-$daynum{$1})*86400;
		($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)
			= localtime($adjtime);
		$hour = $2; $min = $3;
		$sec = $4 if $4;
	}
	elsif ($str =~ /(\d\d?)-(\w\w\w)\w*-\d?\d?(\d\d)\.(\d+):(\d+):?(\d+)?/)
	{
		$error++ unless (defined $monthnum{$2});
		$mday = $1; $mon = $monthnum{$2};  $year = $3;
		$hour = $4; $min = $5;
		$sec = 0;
		$sec = $6 if $6;
	}
	elsif ($str =~ /(\d\d?)-(\w\w\w)\w*\.(\d+):(\d+):?(\d+)?/)
	{
		$error++ unless (defined $monthnum{$2});
		$mday = $1; $mon = $monthnum{$2};
		$hour = $3; $min = $4;
		$sec = 0;
		$sec = $5 if $5;
	}
	elsif ($str =~ /(\d\d?)-(\w\w\w)\w*-\d?\d?(\d\d)/)
	{
		$error++ unless (defined $monthnum{$2});
		$mday = $1; $mon = $monthnum{$2};  $year = $3;
		$hour = $min = $sec = 0;
	}
	elsif ($str =~ /(\d\d?)-(\w\w\w)\w*/)
	{
		$error++ unless (defined $monthnum{$2});
		$mday = $1; $mon = $monthnum{$2};
		$hour = $min = $sec = 0;
	}
	elsif ($str =~ /(\d+):(\d+):?(\d+)?/)
	{
		$hour = $1; $min = $2;
		$sec = 0;
		$sec = $3 if $3;
	}
	else
	{
		$error++;
	}

	# if we get an error we return the current time, and an error
	if ($error)
	{
		&log("warning", "Unknown date format: $str, using now\n");
        	($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)
			= localtime($begintime);
	}
#	printf "%d %d %d %d %d %d %d %d %d\n",
#		$sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst;
        return($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst);
}

#-----------------------------------------------------------------------
# given a time produce a clearcase format time
#
# time is specified in the unix tradition, seconds since the epoch
# returns a string without a newline (unlike ctime)
#
sub cctime
{
        local($tm) = @_;
        local($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
                localtime($tm);

        #
        # this build system better be replaced before this code breaks!
        #
        $year = "19".$year if $year > 70;
        $year = "20".$year if $year < 70;

        return(sprintf("%d-%s-%d.%02d:%02d:%02d",
                                $mday, $ctime'MoY[$mon], $year,
                                $hour, $min, $sec));
}

#-----------------------------------------------------------------------
# Produce an ascii representation of a time span, given two times
#
# this is just a front end to hourminsec, to check the incoming values
#
# This needs to be done as a timeout may occur, leaving the endtime undefined
# in which case we need to use the current time instead.
#
sub timespan
{
	local($start, $end) = @_;

	# if both are undefined nothing happened (un-run phase)
	return "00:00:00"               if (!defined($start) && !defined($end));

	# if the end time doesn't exist, then a timeout must have occurred
	# use the current time
	return &hourminsec(time-$start) if (defined($start) && !defined($end));

	# normal case:  both are defined
	return &hourminsec($end-$start) if (defined($start) && defined($end));

	# this should never happen (I hope)
	&log("error", "internal error: starttime undefined, endtime defined" .
			" (timewarp?)\n");
	return " E:RR:OR";
}

#-----------------------------------------------------------------------
# A very trivial routine to spit out a string of hours, minutes
# and seconds given a number of seconds.
#
sub hourminsec
{
	local($seconds) = @_;
	local($days,$hours,$minutes);

	# if we get a negative number, either something is seriously wrong
	# or human nature has struck again, and the time subtraction
	# was done in the wrong order :-)
	if ($seconds < 0)
	{
		&log("error", "internal error: negative time span $seconds,",
			" using absolute value\n");
		$seconds = abs($seconds);
	}

	$days =  int($seconds  / (24 * 3600));
	$seconds -= $days * (24 * 3600);

	$hours =  int($seconds / 3600);
	$seconds -= $hours * 3600;

	$minutes =  int($seconds / 60);
	$seconds -= $minutes * 60; 

	return sprintf("%d+%02d:%02d:%02d",
			$days, $hours, $minutes, $seconds) if $days;

	return sprintf("%02d:%02d:%02d", $hours, $minutes, $seconds)
}
#-----------------------------------------------------------------------
# given a time of the format days.hrs:min:sec, return the number of seconds
# days and sec are optional (the . can also be a +).
# if given a number only (i.e. no non numerics), return it verbatim
#
sub unhourminsec
{
	local($str) = @_;
	local($sec);

	# they gave us seconds, give it back
	return $str if ($str =~ /^\d+$/);

	if    ($str =~ /^(\d+)[\.+](\d+):(\d+):?(\d+)?$/)
	{
		$sec = $1 * (24*60*60) + $2 * (60*60) + $3 * 60 + $4;
	}
	elsif ($str =~ /^(\d+):(\d+):?(\d+)?$/)
	{
		$sec = $1 * (60*60) + $2 * 60 + $3;
	}
	else
	{
		$sec = 0;
	}
}

#------------------------------------------------------------------------
# get the date components from a date
# known formats:
#     22-Dec-92
#     Tue Dec 22 11:40:47 PST 1992
#     Mon, 7 Dec 92 12:55:24 PST
#     Fri, 19 Jul 91 10:25 PDT
#     22 Dec 92 12:32:17 GMT
#     Oct 15 00:00:00 PDT 1992
#     Dec 31 92
#     12/31/92
#     Mon, 21 Dec 92 03:00:02 -0800
#     Wed, 16 Dec 1992 15:38:33 -0800 (PST)
#     Thu Aug 12, 1993 22:15:13 EDT
#     Mon Jan 20 23:30:20 US/Pacific 1997
# todo:
#     convert time zone info??
#
# This is an old routine I wrote at PSU (around Dec-92)
# It was part of the GIPR task system
# warning: this is probably one of the sickest bits of perl I ever wrote
#
sub grokdate
{
        local($str) = @_;
        local($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst);
        local($timezone);

        $str =~ s/^\s+//;
        $str =~ s/\s+$//;

        # format: 22-Dec-92
        if ($str =~ /^(\d\d?)-([a-zA-Z]+)-\d?\d?(\d\d)$/) {
                $mday = $1; $mon = $monthnum{$2};  $year = $3;
        }
        # format: Tue Dec 22 11:40:47 PST 1992
        #         Mon Jan 20 23:30:20 US/Pacific 1997
        elsif ($str =~ /^([a-zA-Z]{3}) ([a-zA-Z]{3}) ([0-3\s]?\d) +(\d?\d):(\d\d):(\d\d) ([\w\/+-]+) \d?\d?(\d\d)$/)
        {
                $mon = $monthnum{$2};
                $wday = $daynum{$1};
                $mday = $3;
                $hour = $4; $min = $5; $sec = $6;
                $timezone = $7; $year = $8;
        }
        # format: Tue Mar 23  0:32:27 1993
        elsif ($str =~ /^([a-zA-Z]{3}) ([a-zA-Z]{3}) ([0-3\s]?\d) ([\d\s]?\d):(\d\d):(\d\d) \d?\d?(\d\d)$/)
        {
                $mon = $monthnum{$2};
                $wday = $daynum{$1};
                $mday = $3;
                $hour = $4; $min = $5; $sec = $6;
                $timezone = ""; $year = $7;
        }
        # format: Mon, 7 Dec 92 12:55:24 PST
        elsif ($str =~ /^([a-zA-Z]{3}), (\d?\d) ([a-zA-Z]{3}) \d?\d?(\d\d) (\d?\d):(\d\d):(\d\d) ([a-zA-Z]{3})$/)
        {
                $mon = $monthnum{$3};
                $wday = $daynum{$1};
                $mday = $2; $year = $4;
                $hour = $5; $min = $6; $sec = $7;
                $timezone = $8;
        }
        # format: Fri, 19 Jul 91 10:25 PDT
        elsif ($str =~ /^([a-zA-Z]{3}), (\d?\d) ([a-zA-Z]{3}) \d?\d?(\d\d) (\d?\d):(\d\d) ([a-zA-Z]{3})$/)
        {
                $mon = $monthnum{$3};
                $wday = $daynum{$1};
                $mday = $2; $year = $4;
                $hour = $5; $min = $6; $sec = 0;
                $timezone = $7;
        }
        # format: 22 Dec 92 12:32:17 GMT
        #         20 Sep 1993 15:43:15 -0700
        elsif ($str =~ /^(\d?\d) ([a-zA-Z]{3}) \d?\d?(\d\d) (\d?\d):(\d\d):(\d\d)\s*([a-zA-Z]{3}|[+-]\d+|)$/)
        {
                $mon = $monthnum{$2};
                $mday = $1; $year = $3;
                $hour = $4; $min = $5; $sec = $6;
                $timezone = $7;
        }
        # format: Oct 15 00:00:00 PDT 1992
        elsif ($str =~ /^([a-zA-Z]{3}) ([0-3\s]?\d) (\d?\d):(\d\d):(\d\d) ([a-zA-Z]{3}) \d?\d?(\d\d)$/)
        {
                $mon = $monthnum{$1};
                $mday = $2;
                $hour = $3; $min = $4; $sec = $5;
                $timezone = $6; $year = $7;
        }
        # format:  12/31/92
        elsif ($str =~ /^(\d\d?)[\/-](\d\d?)[\/-]\d?\d?(\d\d)$/)
        {
                $mon = $1-1;
                $mday = $2; $year = $3;
        }
        # Mon, 21 Dec 92 03:00:02 -0800
        # Wed, 16 Dec 1992 15:38:33 -0800 (PST)
        # Thu,  9 Sep 1993 14:39:30 -0800
        elsif ($str =~ /^([a-zA-Z]{3}),\s+(\d?\d) ([a-zA-Z]{3}) \d?\d?(\d\d) (\d?\d):(\d\d):(\d\d) ([+-]?\d+)/)
        {
                $mon = $monthnum{$3};
                $wday = $daynum{$1}; $mday = $2; $year = $4;
                $hour = $5; $min = $6; $sec = $7;
                $timezone = $8;
        }
        # Thu Aug 12, 1993 22:15:13 EDT
        # Thu Aug 12, 93 22:15:13 EDT
        elsif ($str =~ /^([a-zA-Z]{3}) ([a-zA-Z]{3}) (\d?\d), \d?\d?(\d\d) (\d?\d):(\d\d):(\d\d) (.*)/)
        {
                $mon = $monthnum{$2};
                $wday = $daynum{$1}; $mday = $3; $year = $4;
                $hour = $5; $min = $6; $sec = $7;
                $timezone = $8;
        }
        # Dec 31 92
        elsif ($str =~ /^([a-zA-Z]+) (\d\d?) \d?\d?(\d\d)$/)
        {
                $mon = $monthnum{$1};
                $mday = $2; $year = $3;
        }
        return($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst);
}

1;
