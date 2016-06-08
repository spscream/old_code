#!/usr/bin/perl
##########################################
# Asterisk queue analizer backend daemon #
##########################################
use Time::Local;

use strict;
use File::Tail;
use Getopt::Long;
use DBI;
use DBD::Pg;
use POSIX 'setsid';

my $VERSION = 0.1;

# Some static variables
my $logfile = "./queue_log";
my $db_host = "localhost";
my $db_user = "scream";
my $db_passwd = "";
my $db_name = "accm";
my $db_queue_table = "queue_log";
my $tz = "+4";
my $log_verbose = 1;
my $daemon_logfile = "./accmd.log";
my $daemon_pidfile = "./accmd.pid";
#The maximum number of seconds (real number) that will be spent sleeping. 
#Default is 60, meaning File::Tail will never spend more than sixty seconds without checking the file.
my $maxinterval = 1;
#The initial number of seconds (real number) that will be spent sleeping, before the file is first checked.
#Default is ten seconds, meaning File::Tail will sleep for 10 seconds and then determine, how many new lines have appeared in the file.
my $interval = 1;
# Useful vars
my $dbh;
my $rc;
my $last_timestamp;
my %opt = ();

# DEBUG PARAMS
my $DEBUG_PARSE_QUEUE = 0;
my $DEBUG_INIT = 0;
my $DEBUG_DB_INSERT = 0;
my $DEBUG_HANDLE = 0;

# Reasons static hash

my %reasons_static = (
    'ABANDON'			=> 1,
    'AGENTDUMP'			=> 2,
    'AGENTLOGIN'		=> 3,
    'AGENTCALLBACKLOGIN'	=> 4,
    'AGENTLOGOFF'		=> 5,
    'AGENTCALLBACKLOGOFF'	=> 6,
    'COMPLETEAGENT'		=> 7,
    'COMPLETECALLER'		=> 8,
    'CONFIGRELOAD'		=> 9,
    'CONNECT'			=> 10,
    'ENTERQUEUE'		=> 11,
    'EXITWITHKEY'		=> 12,
    'EXITWITHTIMEOUT'		=> 13,
    'QUEUESTART'		=> 14,
    'SYSCOMPAT'			=> 15,
    'TRANSFER'			=> 16,
    'RINGNOANSWER'		=> 17,
    'ADDMEMBER'			=> 18,
    'PAUSEALL'			=> 19,
    'UNPAUSEALL'		=> 20
);


# Some hashrefs
my $agents;
my $queues;
my $reasons;
# Some hashes
my %reasons;
my %agents;
my %queues;

# prototypes

## Func
sub is_float;

## Parser work
sub process_line_queue($);
sub process_line_cdr($);

## Init workers
sub init_queues;
sub init_agents;
sub init_reasons;
sub init_timestamp;

## Handlers
sub handle_timestamp;
sub handle_callid;
sub handle_reason;
sub handle_queue;
sub handle_agent;
sub handle_info;

## DB Work
sub db_connect;
sub db_disconnect;
sub db_insert;
# Lets begun!

# Func
sub is_float ($) {
    return unless defined $_[0] && $_[0] ne '';
    return unless $_[0] =~ /^([+-]?)(?=\d|\.\d)\d*(\.\d*)?([Ee]([+-]?\d+))?$/;
    return 1;
}

# Parsers
sub process_line_queue($)
{
	my $line = shift; 
        chomp $line;
	my $q_time; 	# epoch timestamp of listed action
	my $q_callid;	# uniqueid of call
	my $q_queue;	# queue name
	my $q_agent;	# bridged channel
	my $q_reason;	# event
	my $q_info1;	# event data 1
	my $q_info2;	# event data 2
	my $q_info3;	# event data 3
	my @data;
	
	if ($line =~ /\n*\|.*\|.*\|.*\|.*\|.*/){
    		@data = ($q_time,$q_callid,$q_queue,$q_agent,$q_reason,$q_info1,$q_info2,$q_info3) = split (/\|/,$line);
	} 
	 else 
	{ 
	    warn "WARNING: line format error...ignored: '".$line."'\n";
	    return 1;
	}
	if($q_time <= $last_timestamp){
	    warn "line ignored...\n" if $DEBUG_PARSE_QUEUE;
	    return 1;
	}
	 else
	{
	    # Handlers
	    $data[0] = handle_timestamp($data[0]);
	    $data[1] = handle_callid($data[1]);
	    $data[2] = handle_queue($data[2]);
	    $data[3] = handle_agent($data[3]);
	    $data[4] = handle_reason($data[4]);
	    $data[5] = handle_info($data[5]);
	    $data[6] = handle_info($data[6]);
	    $data[7] = handle_info($data[7]);
	
	    # DB Inserts
	    db_insert($db_queue_table,@data);
	
	    # Some debug fun stuff :)
	    if($DEBUG_PARSE_QUEUE){
	    warn "q_times: ".$q_time." ".$data[0]."\n";
	    warn "q_callid: ".$q_callid." ".$data[1]."\n";
	    warn "q_name: ".$q_queue." ".$data[2]."\n";
	    warn "q_agent: ".$q_agent." ".$data[3]."\n";
	    warn "q_action: ".$q_reason." id: ".$data[4]."\n";
	    warn "q_info1: ".$q_info1." ".$data[5]."\n";
	    warn "q_info2: ".$q_info2." ".$data[6]."\n";
	    warn "q_info3: ".$q_info3." ".$data[7]."\n";
	    warn "line: ".$line."\n";
	    
	    return 1;
	    }
	}
#	exit();
}

sub process_line_cdr($)
{
	my $line = shift;
	chomp $line;
	my $cdr_accode;		# Accountcode, Assigned if configured for the channel in the channel configuration file
	my $cdr_src; 		# Received Caller ID (string, 80 characters).
	my $cdr_dst;		# Destination extension.
	my $cdr_dcontext;	# Destination context. 
	my $cdr_clid;		# Caller ID with text (80 characters).
	my $cdr_channel;	# Channel used (80 characters).
	my $cdr_dstchannel;	# Destination channel, if appropriate (80 characters).
	my $cdr_lastapp;	# Last application, if appropriate (80 characters).
	my $cdr_lastdata;	# Last application data (arguments, 80 characters).
	my $cdr_start;		# Start of call (date/time).
	my $cdr_answer;		# Answer of call (date/time).
	my $cdr_end;		# End of call (date/time).
	my $cdr_duration;	# Total time in system, in seconds (integer), from dial to hangup.
	my $cdr_billsec;	# Total time call is up, in seconds (integer), from answer to hangup.
	my $cdr_disposition;	# What happened to the call (ANSWERED, NO ANSWER, BUSY).
	my $cdr_amaflags;	# What flags to use (DOCUMENTATION, BILL, IGNORE, etc.), specified on a per-channel
				# basis, like accountcode. AMA flags stand for Automated Message Accounting flags,
				# which are somewhat standard (supposedly) in the industry.
	my $userfield;		# A user-defined field, maximum 255 characters.
}	


# Handlers

sub handle_timestamp
{
	my $time = shift;
	my @t=localtime($time);
	#my $timestamp = sprintf "'%4d-%02d-%02d %02d:%02d:%02d%s'", $t[5]+1900,$t[4]+1,$t[3],$t[2],$t[1],$t[0],$tz;
	my $timestamp = sprintf "'%4d-%02d-%02d %02d:%02d:%02d'", $t[5]+1900,$t[4]+1,$t[3],$t[2],$t[1],$t[0];
	return $timestamp;
}

sub handle_callid
{
	my $callid = shift;
	if(is_float($callid)){
	    return $callid
	} else { 
	    return 0;
	}
}

sub handle_reason
{
	my $reason = shift;
	my $reason_id;
	if (defined $reasons->{$reason}->{id})
	    {
		$reason_id = $reasons->{$reason}->{id};
	    }
	else
	    {
		my $SQL = "INSERT INTO reasons (text) VALUES ('".$reason."')";
		$dbh->do($SQL) or die $dbh->errstr;
		$reason_id = $dbh->last_insert_id(undef,undef,undef,undef,{sequence=>'reasons_id_seq'});
		$reasons->{$reason}->{id} = $reason_id;
		warn "DEBUG_HANDLE: New reason. id: ".$reasons->{$reason}->{id}."; reason: ".$reason."\n" if $DEBUG_HANDLE;
	    }
	return $reason_id;
}

sub handle_agent
{
	my $agent = shift;
	my $agent_id;
	$agent = "NONE" if $agent eq "";
	if (defined $agents->{$agent}->{id})
	    {
		$agent_id = $agents->{$agent}->{id};
	    }
	else
	    {
		my $SQL = "INSERT INTO agents (agent) VALUES ('".$agent."')";
		$dbh->do($SQL) or die $dbh->errstr;
		$agent_id = $dbh->last_insert_id(undef,undef,undef,undef,{sequence=>'agents_id_seq'});
		$agents->{$agent}->{id} = $agent_id;
		warn "DEBUG_HANDLE: New agent. id: ".$agents->{$agent}->{id}."; agent: ".$agent."\n" if $DEBUG_HANDLE;
	    }
	return $agent_id;
}

sub handle_queue
{
	my $queue = shift;
	my $queue_id;
	
	if (defined $queues->{$queue}->{id})
	    {
		
		$queue_id = $queues->{$queue}->{id};
	    }
	else
	    {
		my $SQL = "INSERT INTO queues (text) VALUES ('".$queue."')";
		$dbh->do($SQL) or die $dbh->errstr;
		$queue_id = $dbh->last_insert_id(undef,undef,undef,undef,{sequence=>'queues_id_seq'});
		$queues->{$queue}->{id} = $queue_id;
		warn "DEBUG_HANDLE: New queue. id: ".$queues->{$queue}->{id}."; text: ".$queue."\n" if $DEBUG_HANDLE;
	    }
	return $queue_id;
}

sub handle_info
{
	my $info = shift;
	if($info eq "")
	{
	    $info = undef;
	}
	return $info;
}


# Database workers

sub db_insert
{
	my $DEBUG=0;
	my $db_table_name;
	my @data;
	($db_table_name, @data) = @_;
	my $SQL = "INSERT INTO ".$db_table_name." VALUES (?,?,?,?,?,?,?,?)";
	my $sth = $dbh->prepare($SQL);
	
	if($DEBUG_DB_INSERT){
	    warn "DEBUG_DB_INSERT: \n";
    	    warn "q_times: ".$data[0]."\n";
	    warn "q_callid: ".$data[1]."\n";
	    warn "q_name: ".$data[2]."\n";
	    warn "q_agent: ".$data[3]."\n";
	    warn "q_action: ".$data[4]."\n";
	    warn "q_info1: ".$data[5]."\n";
	    warn "q_info2: ".$data[6]."\n";
	    warn "q_info3: ".$data[7]."\n";
	}

		
	$sth->bind_param(1,$data[0]);	# timestamp
	$sth->bind_param(2,$data[1]);	# callid
	$sth->bind_param(3,$data[2]);	# queue
	$sth->bind_param(4,$data[3]);	# agent
	$sth->bind_param(5,$data[4]);	# reason
	$sth->bind_param(6,$data[5]);	# data1
	$sth->bind_param(7,$data[6]);	# data2
	$sth->bind_param(8,$data[7]);	# data3

	$sth->execute();
	$dbh->commit or die $dbh->errstr;
}

sub db_connect
{	
	$dbh = DBI->connect("dbi:Pg:dbname=$db_name;host=$db_host", "$db_user", "$db_passwd", {
	    AutoCommit => 0,
	    RaiseError => 1
	}) or die $DBI::errstr;
	warn "OK!\n";
}

sub db_disconnect
{
	return $dbh->disconnect;
}

# Init workers

sub init_queues
{
        my $SQL = "SELECT id, text FROM queues";
	my $sth = $dbh->prepare($SQL);
	$sth->execute;
	$queues = $sth->fetchall_hashref('text');
	$sth->finish;
}

sub init_agents
{
        my $SQL = "SELECT id, agent, name, pass FROM agents";
	my $sth = $dbh->prepare($SQL);
	$sth->execute;
	$agents = $sth->fetchall_hashref('agent');
	$sth->finish;
}

sub init_reasons
{
	my $SQL = "SELECT id, text FROM reasons";
	my $sth = $dbh->prepare($SQL);
	$sth->execute;
	$reasons = $sth->fetchall_hashref('text'); 
	$sth->finish;
}

sub init_timestamp
{	
	my $timestamp;
	my $SQL = "SELECT EXTRACT ('epoch' FROM (SELECT max(date) FROM queue_log)) AS unixtime";
	my $sth = $dbh->prepare($SQL);
	$sth->execute;
	$sth->bind_columns( \$timestamp );
	while($sth->fetch){
	    $last_timestamp = $timestamp;
	}
	$sth->finish;
}

sub usage
{
	print "usage: qanalise [*options*]\n\n";
	print "  -h, --host=HOST	postgresql database hostname\n";
	print "  -U, --username	postgresql database username\n";
	print "  -p, --password	postgresql database password\n";
	print "  -D, --database	postgresql database dbname\n";	    
	print "  -l, --logfile f	monitor logfile f instead of $logfile\n";
	print "  -c, --cat          	causes the logfile to be only read and not monitored\n";
	print "  -d, --daemon       	start in the background\n";
	print "  --daemon-pid=FILE  	write PID to FILE instead of /var/run/mailgraph.pid\n";
	print "  --daemon-log=FILE  	write verbose-log to FILE instead of /var/log/mailgraph.log\n";
	print "  -h, --help         	display this help and exit\n";
	print "  -V, --version      	output version information and exit\n\n";
	
	exit;
}

sub daemonize()
{
        open STDIN, '/dev/null' or die "queueanaliser: can't read /dev/null: $!";
        if($opt{verbose}) {
                open STDOUT, ">>".$daemon_logfile
                        or die "queueanaliser: can't write to $daemon_logfile: $!";
        }
        else {
                open STDOUT, '>/dev/null'
                        or die "queueanaliser: can't write to /dev/null: $!";
        }
        defined(my $pid = fork) or die "queueanaliser: can't fork: $!";
        if($pid) {
                # parent
                open PIDFILE, ">$daemon_pidfile"
                        or die "queueanaliser: can't write to $daemon_pidfile: $!\n";
                print PIDFILE "$pid\n";
                close(PIDFILE);
                exit;
        }
        # child
        setsid                  or die "queueanaliser: can't start a new session: $!";
        open STDERR, '>&STDOUT' or die "queueanaliser: can't dup stdout: $!";
}

sub main
{
	Getopt::Long::Configure('no_ignore_case');
        GetOptions(\%opt, 'help|h', 'cat|c', 'logfile|l=s', 'version|V','verbose|v',
		    'daemon|d!','host|h=s','username|U=s','password|p=s','database|D=s',
		     'daemon_pid|daemon-pid=s','daemon_log|daemon-log=s'
		     ) or usage;
        usage if $opt{help};

        if($opt{version}) {
                print "qanalize $VERSION\n";
                exit;
        }
	
	$daemon_pidfile = $opt{daemon_pid} if defined $opt{daemon_pid};
	$daemon_logfile = $opt{daemon_log} if defined $opt{daemon_log};
        $logfile = $opt{logfile} if defined $opt{logfile};
	$db_host = $opt{host} if defined $opt{host};
	$db_user = $opt{username} if defined $opt{username};
	$db_passwd = $opt{password} if defined $opt{password};
	$db_name = $opt{database} if defined $opt{database};

	daemonize if $opt{daemon};

	print "DB Connect: \n";
	db_connect;
	print "Read last timestamp... \n ";
	init_timestamp;
	print "Init Agents hash... \n";
	init_agents;
	print "Init Queues hash... \n";
	init_queues;
	print "Init Reasons hash... \n";
	init_reasons;
	
        if($opt{cat}) {
                open(FILE, "<$logfile") or die "can't open $logfile\n";
                while(<FILE>) {
                        process_line_queue($_);
                }
        }
        else {  
		my $file = File::Tail->new(name=>$logfile, tail=>-1, interval=>$interval, maxinterval=>$maxinterval);
                my $line;
                while (defined($line=$file->read)) {
                        process_line_queue($line);
                }
		
        }
	warn "DB Disconnect:".db_disconnect."\n";

}

main;