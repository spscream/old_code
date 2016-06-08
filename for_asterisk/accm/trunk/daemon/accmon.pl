#!/usr/bin/perl
#----------------------------------------------------------------------
# Description:
# Author:  <Alexandr M Malaev aka SP|Scream>
# Created at: Fri Jan 25 19:24:00 MSK 2008
# Computer: hatchery 
# System: Linux 2.6.23.9 on i686
#    
# Copyright (c) 2008   All rights reserved.
#----------------------------------------------------------------------

use strict;
use IO::Socket;
use Digest::MD5;
use Data::Dumper;
use DBI;
use DBD::Pg;
use threads;

# Variables
## Static vars
my $db_host = "localhost";
my $db_user = "scream";
my $db_passwd = "1q2w3e4r";
my $db_name = "accm";
my $db_queue_table = "queue_log";
my $m_user = "choog";
my $m_secret = "megachoog";
my $m_host = "localhost";
my $m_port = "5038";

my $EOL = "\r\n";
my $BLANK = $EOL x 2;

### Debug
my $DEBUG = 1;
my $DEBUG_CB = 0;
my $DEBUG_DEFAULT_CB = 0;

## Dynamic vars
my $ERRSTR;
my $PROTOVERS;
my $m_connfd;
my $m_connected;
my $dbh;
my $rc;
# Callback
my $CB = {
    DEFAULT => \&default_cb,
    Agents => \&agents_cb,
    AgentsComplete => \&dump_cb,
    Agentcallbacklogin => \&agentcallbacklogin_cb,
    QueueStatusComplete => \&db_insert,
    Newcallerid => \&dump_cb,
#    AgentComplete => \&dump_cb,
#    Hangup => \&dump_cb,
#    Link => \&dump_cb,
    Rename => \&rename_cb,
#    Unlink => \&dump_cb
    QueueMember => \&queuemember_cb,
    QueueMemberStatus => \&queuememberstatus_cb
#    QueueParams => \&queueparams_cb,
#    Queues => \&dump_cb,
#    Status => \&dump_cb,
#    PeerStatus => \&dump_cb
#    PeerEntry => \&dump_cb
    
};

# Threads
my $thr;



# Some hashes
my %agents;
my %reasons;
my %queues;
my %queuemembers;
my %queyemembers_monitored;
my %agent_status = {
        'AGENT_LOGGEDOFF'	=> 1,
	'AGENT_IDLE'		=> 2,
	'AGENT_ONCALL'		=> 3,
	'AGENT_UNKNOWN'		=> 4
};


# Some hashrefs
my $queues;
my $agents;
my $queuemembers = \ %queuemembers;
my $queuemembers_monitored;



##	Agent states from QueueMember event
#	0 - Queue call 
#	1 - Available for calls 
#	2 - Busy (Currently on the phone) 
#	3 - Working
#	4 - Invalid
#	5 - Not Available (Disconnected) 
#	6 - Ringing

##	Extention status
#	Status codes: 
#	-1 = Extension not found 
#	0 = Idle 
#	1 = In Use 
#	4 = Unavailable 
#	8 = Ringing

# Asterisk manager monitor functions
sub m_connect;
sub m_disconnect;
sub m_sendcommand;
sub m_read_response;
sub m_handleevent;
sub m_eventcallback;

# DB work
sub db_connect;
sub db_disconnect;
sub db_insert;

# Init
sub init_eventloop;
sub init_agents;
sub init_queues;
sub init_queuemembers;


# Thread functions
sub eventloop_thread;
sub eventloop_thread_join;
sub sendcommand_thread;

# Callback functions
sub setcallback;
sub agents_cb;
sub agentcallbacklogin_cb;
sub queuemember_cb;
sub queuememberstatus_cb;
sub queueparams_cb;
sub rename_cb;
sub default_cb;
sub dump_cb;
sub test_cb;

# Error and exceptions functions
sub error;

# Usable stuff
sub to_timestamp;
sub h2s;
sub s2h;
sub a2h;
sub splitresult;

# Begun =)

## ---------------------------------- ##
## Asterisk manager monitor functions ##
## ---------------------------------- ##

# Функция коннекта к интерфейсу AMI, возвращает ref на сокет.
sub m_connect
{
	my ($host,$port,$user,$secret) = @_;
	$host = $m_host if !defined $host;
	$port = $m_port if !defined $port;
	$user = $m_user if !defined $user;
	$secret = $m_secret if !defined $secret;
	
	my %resp; # инит хеша для респонза от AMI

	print "m_connect [DBG] Connect: ".$user.":".$secret."@".$host.":".$port."\n" if $DEBUG;
	
	my $conn = new IO::Socket::INET( Proto => 'tcp',
					PeerAddr => $host,
					PeerPort => $port
					);
	if(!$conn){
	    print error("Connection refused ($host:$port)\n"); # Валимся если чо нетаг =)
	    return undef;
	}
	
	$conn -> autoflush(1); # Валим всё автофлушем
	
	my $input = <$conn>;
	$input =~ s/$EOL//g;
	
	my ($manager, $version) = split('/', $input);
	
	if ($manager !~ /Asterisk Call Manager/) {
	    return error("Unknown Protocol\n"); # куда ломимся?
	}
	$PROTOVERS = $version;
	$m_connfd = $conn;
	
	print "m_connect [DBG] Proto: ".$PROTOVERS."\n" if $DEBUG;
	# check if the remote host supports MD5 Challenge authentication
	my %authresp = m_sendcommand( Action => 'Challenge',
		    		      AuthType => 'MD5'
				    );
	# Если AMI принимает md5 шлем в нём					 
	if (($authresp{Response} eq 'Success')) {
	    # do md5 login
	    my $md5 = new Digest::MD5;
	    $md5->add($authresp{Challenge});
	    $md5->add($secret);
	    my $digest = $md5->hexdigest;
	    %resp = m_sendcommand(  Action => 'Login',
				    AuthType => 'MD5',
				    Username => $user,
				    Key => $digest
				 );
	# Иначе ломимся открытым текстом, что некошерно
	} else {
	    # do plain text login
	    %resp = m_sendcommand(  Action => 'Login',
					 Username => $user,
					 Secret => $secret
				      );
	}
	if ( ($resp{Response} ne 'Success') && ($resp{Message} ne 'Authentication accepted') ) {
		error("Authentication failed for user $user\n"); # о_О Ты кто ???
		return undef;
	}
			    
	$m_connected=1; # Фух, законектились!!! =)
				
return $conn;
	
}

# Функция дисконекта от AMI, возвращает (true|false)
sub m_disconnect {
    my ($self) = @_;
    
	my $conn = $m_connfd;
	my %resp = m_sendcommand('Action' => 'Logoff');
	    
	print "Disconnect: ".$resp{Response}."\n" if $DEBUG;
	if ($resp{Response} eq 'Goodbye') {
	    $m_connfd = undef;
	    $m_connected = 0;
	    return 1;
	}
					    
	return 0;
}


# 
#$want is how you want the data returned
#$want = 0 (default) returns the results in a hash
#$want = 1 returns the results in a large string
#$want = 2 returns the results in an array
sub m_sendcommand
{
	my (%command, $want) = @_;

        if(!defined($want)){
	    $want = 0;
        }
	
	my $conn = $m_connfd || return;
	
	my $cstring = h2s(%command);
	
	$conn->send("$cstring$EOL");
	
	if ($want == 1) {
	    my $response = m_read_response($conn);
	    return $response;
	}
	
	my @resp = m_read_response($conn);
	
	if ($want == 2) {
		return @resp;
	} else {
		return map { splitresult($_) } @resp;
	}
    
}


sub m_read_response
{
	my ($connfd) = @_;
	my @response;
	
	if (!$connfd) { 
	    $connfd = $m_connfd;
	}
	
	while (my $line = <$connfd>) {
	    last if ($line eq $EOL);
	    if (wantarray) {
		$line =~ s/$EOL//g;
		push(@response, $line) if $line;
	    } else {
		$response[0] .= $line;
	    }
	}
	return wantarray ? @response : $response[0];
}

sub m_handleevent {
	my %resp = map { splitresult($_); } m_read_response;
	m_eventcallback(%resp);
	
	return %resp;
}

sub m_eventcallback {
    my (%resp) = @_;
    
    my $callback;
    my $event = $resp{Event};
	    
    return if (!$event);
		
    if (defined($CB->{$event})) {
	print "m_eventcallback [DBG] Defined: ".$event."\n" if $DEBUG;
	$CB->{$event}(%resp);
    } elsif (defined($CB->{DEFAULT})) {
	print "m_eventcallback [DBG] Defined: ". $event ." DEFAULT \n" if $DEBUG;
	$CB->{DEFAULT}(%resp);
    } else {
	print "m_eventcallback [DBG] Undefined $event sub";
        return;
    }
						
    return;
}

## ------------------------------------ ##
## 	Database work functions		##
## ------------------------------------ ##

#       Таблица "public.agents_online"
#	 Колонка   |           Тип            | Модификаторы
#	-----------+--------------------------+---------------
#	id         | integer                  | not null
#	status     | integer                  |
#	queue      | integer                  |
#	chan       | character varying        |
#	logintime  | timestamp with time zone |
#	talkingto  | character varying        |
#	callstaken | integer                  |
#	penalty    | integer                  |
#	paused     | boolean                  | default false
#	lastcall   | integer                  |
#	Индексы:
#	"agents_online_id_key" UNIQUE, btree (id)


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

sub db_disconnect
{
        return $dbh->disconnect;
}

sub db_insert
{
    my $table = "agents_online";
    my $sql;
    my @ids = sort keys %$queuemembers;
    my @pairs;
    my @fields;
    my @queuemember;
    foreach (@ids){
    	my $queuemember = %queuemembers->{$_};
	my $a_id = $_;
	my $a_status = (defined $queuemember->{Status}) ? $queuemember->{Status} : 5;
	my $a_queue = (defined $queuemember->{Queue}) ? $queuemember->{Queue} : 0;
	my $a_chan = (defined $queuemember->{LoggedInChan}) ? $queuemember->{LoggedInChan} : "n/a";
	my $a_logintime = (defined $queuemember->{LoggedInTime}) ? to_timestamp($queuemember->{LoggedInTime}) : undef;
	my $a_callerid = $queuemember->{TalkingTo};
	my $a_callstaken = $queuemember->{CallsTaken} ? $queuemember->{CallsTaken} : 0; 
	my $a_penalty = $queuemember->{Penalty} ? $queuemember->{Penalty} : 0;
	my $a_paused = $queuemember->{Paused} ? 1 : 0;
	my $a_lastcall = (defined $queuemember->{LastCall}) ? to_timestamp($queuemember->{LastCall}) : undef;

		
	@queuemember = ($a_id,$a_queue,$a_status,$a_chan,$a_logintime,$a_callerid,$a_callstaken,$a_penalty,$a_paused,$a_lastcall);
	@fields = ('id','queue','status','chan','logintime','callerid','callstaken','penalty','paused','lastcall');
	
	# Если id уже есть в базе, делаем апдейт
        if ( defined $queuemembers_monitored->{$a_id}){
	    my $sql = 'UPDATE '.$table.' SET ';
	    $sql .= join(', ', map { "$_ = ?" } @fields).' WHERE id=\''.$a_id.'\'';
	    print $sql."\n";
	    my $sth = $dbh->prepare_cached($sql);
	    $sth->execute(@queuemember);
	    $queuemembers_monitored->{$a_id} = a2h(@fields,@queuemember);
	}
	# Иначе инсёрт
	else {
	    $sql = sprintf "insert into %s (%s) values (%s)",
	    $table, join(",", @fields), join(",", ("?")x@fields);
	    print $sql."\n";
	    my $sth = $dbh->prepare_cached($sql);
	    $sth->execute(@queuemember);

	}
	$dbh->commit or die $dbh->errstr;
    }
}

sub db_update
{
    my ($what,$where) = @_;
    
    
    my @column = sort keys %$what;
    my @value  = map { $what->{$_} } @column;
    
    my $sql = 'UPDATE agents_online SET ';
    $sql .= join(', ', map { "$_ = ?" } @column).' WHERE '.$where;
    
    print "db_update [DBG]: \n";
    print "What: ".Dumper $what;
    print "Where: ".Dumper $where;
    print "SQL: ".$sql."\n";
    
    
    my $sth = $dbh->prepare_cached($sql);
    $sth->execute(@value);
    $dbh->commit or die $dbh->errstr;
}

## ----------------------------	##
## 	Init functions		##
## ----------------------------	##
sub init_eventloop {
    print "DB Connect: \n";
    db_connect;
    print "Init Agents hash... \n";
    init_agents;
    print "Init queues hash... \n";
    init_queues;
    print "init agents_online hash...\n";
    init_queuemembers;
    my ($self) = @_;
    while (1) {
	m_handleevent;
    }
}


sub init_agents
{
        my $SQL = "SELECT id, agent, name, pass FROM agents";
	my $sth = $dbh->prepare($SQL);
	$sth->execute;
	$agents = $sth->fetchall_hashref('agent');
	$sth->finish;
}

sub init_queues
{
        my $SQL = "SELECT id, text FROM queues";
        my $sth = $dbh->prepare($SQL);
        $sth->execute;
        $queues = $sth->fetchall_hashref('text');
        $sth->finish;
					    
}

sub init_queuemembers
{
        my $SQL = "SELECT * FROM agents_online";
	my $sth = $dbh->prepare($SQL);
	$sth->execute;
	$queuemembers_monitored = $sth->fetchall_hashref('id');

	$sth->finish;
}

## ----------------------------	##
## 	Threads functions	##
## ----------------------------	##

sub eventloop_thread {
    $thr = threads->create( \&init_eventloop );
#    $thr->yield();
}

sub eventloop_thread_join {
    $thr->join();
}

sub sendcommand_thread {
    my $thr_agents = threads->create( \&m_sendcommand, Action => 'Agents');
    my $thr_queuestatus = threads->create ( \& m_sendcommand, Action => 'QueueStatus');
}


sub setcallback {
    my ($event, $function) = @_;
    
    if (defined($function) && ref($function) eq 'CODE') {
	$CB->{$event} = $function;
    }
}

# Events callbacks
sub agents_cb{
    my %data = @_;
    my $data = \ %data;
    my $agent_id = $agents->{"Agent/".$data->{Agent}}->{id};
    my $queue_id = $queues->{$data->{Queue}}->{id};

# ЙА ДЕБАЖКО
    print "agents_cb [DBG] state: \n" if $DEBUG_CB;
    print " Event: ".$data->{Event}."\n" if $DEBUG_CB;
    print " Name: ".$data->{Name}."\n" if $DEBUG_CB;
    print " Agent: ".$data->{Agent}."\n" if $DEBUG_CB;
    print " Agent_id: ".$agent_id."\n" if $DEBUG_CB;
    print " Status: ".$data->{Status}."\n" if $DEBUG_CB;
    print " TalkingTo: ".$data->{TalkingTo}."\n" if $DEBUG_CB;
    print " LoggedInChan: ".$data->{LoggedInChan}."\n" if $DEBUG_CB;
    print " LoggedInTime: ".$data->{LoggedInTime}."\n\n" if $DEBUG_CB;
    
# Инициализация хэша queuemembers, в этот хеш бум сливать инфу о агентах
    $queuemembers->{ $agent_id } = {
	'Name' 		=> $data->{Name},
	'Agent' 	=> $data->{Agent},
	'Status' 	=> $queuemembers->{$agent_id}->{Status},
	'Queue' 	=> $queue_id,
	'Location'    	=> $queuemembers->{$agent_id}->{Location},
	'LoggedInChan' 	=> $data->{LoggedInChan},
	'LoggedInTime' 	=> $data->{LoggedInTime},
	'TalkingTo' 	=> $data->{TalkingTo},
	'CallsTaken'	=> $queuemembers->{$agent_id}->{CallsTaken},
	'Penalty'	=> $queuemembers->{$agent_id}->{Penalty},
	'Paused'	=> $queuemembers->{$agent_id}->{Paused},
	'LastCall' 	=> $queuemembers->{$agent_id}->{LastCall}
    };
}

sub agentcallbacklogin_cb{
    my %data = @_;
    my $data = \ %data;
    my $loginchan = %data->{Loginchan};
    my $agent_id = $agents->{"Agent/". $data->{Agent}}->{id};
    my $timestamp = %data->{Timestamp};
    
    $queuemembers -> {$agent_id} -> {LoggedInChan} = $loginchan;
    $queuemembers -> {$agent_id} -> {LoggedInTime} = $timestamp;
    
#    db_insert;
    db_update({'chan' => $loginchan, 'logintime' => to_timestamp($timestamp)}, 'id = \''.$agent_id.'\'');
# m_eventcallback [DBG] Defined: Agentcallbacklogin
# Start Dump [DBG]
# $VAR1 = 'Timestamp';
# $VAR2 = '1200932703.858066';
# $VAR3 = 'Event';
# $VAR4 = 'Agentcallbacklogin';
# $VAR5 = 'Uniqueid';
# $VAR6 = '1200932697.403';
# $VAR7 = 'Privilege';
# $VAR8 = 'agent,all';
# $VAR9 = 'Loginchan';
# $VAR10 = '214';
# $VAR11 = 'Agent';
# $VAR12 = '509';
# $VAR1 = {};
# End Dump [DBG]

}

sub queuemember_cb{
    my %data = @_;
    my $data = \ %data;
    my $status = $data->{Status};
    my $callstaken = $data->{CallsTaken};
    my $lastcall = $data->{LastCall};
    my $paused = $data->{Paused};
    my $penalty = $data->{Penalty};
    my $agent_id = $agents->{$data->{Location}}->{id};
    my $queue_id = $queues->{$data->{Queue}}->{id};
# ЙА ДЕБАЖКО
    print "queuemember_cb [DBG] state: \n" if $DEBUG_CB;
    print " Event: ".$data->{Event}."\n" if $DEBUG_CB;
    print " Queue: ".$data->{Queue}."\n" if $DEBUG_CB;
    print " Location: ".$data->{Location}."\n" if $DEBUG_CB;
    print " Membership: ".$data->{Membership}."\n" if $DEBUG_CB;
    print " Penalty: ".$data->{Penalty}."\n" if $DEBUG_CB;
    print " CallsTaken: ".$data->{CallsTaken}."\n" if $DEBUG_CB;
    print " LastCall: ".$data->{LastCall}."\n" if $DEBUG_CB;
    print " Status: ".$data->{Status}."\n" if $DEBUG_CB;
    print " Paused: ".$data->{Paused}."\n\n" if $DEBUG_CB;
    $queuemembers -> {$agent_id} -> {'Location'} = $data->{Location};
    $queuemembers -> {$agent_id} -> {'Status'} = $status;
    $queuemembers -> {$agent_id} -> {'Queue'} = $queue_id;
    $queuemembers -> {$agent_id} -> {'CallsTaken'} = $callstaken;
    $queuemembers -> {$agent_id} -> {'LastCall'} = $lastcall;
    $queuemembers -> {$agent_id} -> {'Penalty'} = $penalty;
    $queuemembers -> {$agent_id} -> {'Paused'} = $paused;
} 

sub queuememberstatus_cb{
    my %data = @_;
    my $data = \ %data;
    my $agent_id = $agents->{$data->{MemberName}}->{id};
    my $status = $data->{Status};
    my $talkingto = $data->{TalkingTo};
    my $callstaken = $data->{CallsTaken};
    my $lastcall = $data->{LastCall};
    my $paused = $data->{Paused};
    my $penalty = $data->{Penalty};
    $queuemembers -> {$agent_id} -> {'Status'} = $status if defined ($status) && $status ne $queuemembers -> {$agent_id} -> {'Status'} ;
    $queuemembers -> {$agent_id} -> {'CallsTaken'} = $callstaken if defined ($callstaken) && $callstaken ne $queuemembers -> {$agent_id} -> {'CallsTaken'};
    $queuemembers -> {$agent_id} -> {'Paused'} = $paused if defined ($paused) && $paused ne $queuemembers -> {$agent_id} -> {'Paused'};
    $queuemembers -> {$agent_id} -> {'LastCall'} = $lastcall if defined ($lastcall) && $lastcall ne $queuemembers -> {$agent_id} -> {'LastCall'};
    $queuemembers -> {$agent_id} -> {'Penalty'} = $penalty if defined ($penalty) && $penalty ne $queuemembers -> {$agent_id} -> {'Penalty'};
    $queuemembers -> {$agent_id} -> {'LoggedInChan'} = "n/a" if $status eq 5;
    # db_insert;
    db_update({
		'status' => $queuemembers -> {$agent_id} -> {'Status'},
		'callstaken' => $queuemembers -> {$agent_id} -> {'CallsTaken'} ? $queuemembers -> {$agent_id} -> {'CallsTaken'} : 0,
		'paused' => $paused ? $paused : 0,
		'lastcall' => to_timestamp($queuemembers -> {$agent_id} -> {'LastCall'}),
		'penalty' => $penalty ? $penalty :0,
		'chan' => $status eq 5 ? "n/a" : $queuemembers -> {$agent_id} -> {'LoggedInChan'}
		}
		,'id = \''.$agent_id.'\'');
    # from app_queue.c
    # manager_event(EVENT_FLAG_AGENT, "QueueMemberStatus",
    # "Queue: %s\r\n"
    # "Location: %s\r\n"
    # "MemberName: %s\r\n"
    # "Membership: %s\r\n"
    # "Penalty: %d\r\n"
    # "CallsTaken: %d\r\n"
    # "LastCall: %d\r\n"
    # "Status: %d\r\n"
    # "Paused: %d\r\n",
    # q->name, cur->interface, cur->membername, cur->dynamic ? "dynamic" : "static",
    # cur->penalty, cur->calls, (int)cur->lastcall, cur->status, cur->paused);

}	

sub queueparams_cb{
    my %data = @_;
    my $data = \ %data;

# ЙА ДЕБАЖКО
    print "queueparams_cb [DBG] state: \n" if $DEBUG_CB;
    print " Event: ".$data->{Event}."\n" if $DEBUG_CB;
    print " Queue: ".$data->{Queue}."\n" if $DEBUG_CB;
    print " Max: ".$data->{Max}."\n" if $DEBUG_CB;
    print " Calls: ".$data->{Calls}."\n" if $DEBUG_CB;
    print " Holdtime: ".$data->{Holdtime}."\n" if $DEBUG_CB;
    print " Completed: ".$data->{Completed}."\n" if $DEBUG_CB;
    print " Abandoned: ".$data->{Abandoned}."\n" if $DEBUG_CB;
    print " ServiceLevel: ".$data->{ServiceLevel}."\n" if $DEBUG_CB;
    print " ServicelevelPerf: ".$data->{ServicelevelPerf}."\n\n" if $DEBUG_CB;
}

sub rename_cb{
    my %data = @_;
    my $data = \ %data;
    
    my $newname = $data->{Newname};
    my $oldname = $data->{Oldname};
    
    my $agent_id;
    my $callerid;
    my $chan;
    my $chan_type;
    my $chan_num;
    my $chan_id;
    
    print "Rename_cb DBG Oldname: ".$oldname."\n";
    print "Rename_cb DBG old Newname: ".$newname."\n";
#    $newname =~ s/(.*)\/(\d*).*/$2/g;
    if($newname =~ /(.*)\/([0-9.]*)(\-|\@default\-)(\w*|\w*\,\d)\<??(\w+)\>??$/){
	$chan_type = $1;
	$chan_num = $2;
	$chan_id = $4;
    }
        
    if ($chan_type eq "SIP"){
    	$chan = $chan_type."/".$chan_num."-".$chan_id;
	$callerid = $chan_num;
	db_update({'chan' => $chan, 'callerid' => $callerid }, 'chan = \''.$chan_num.'\'');
    } 
    elsif ($chan_type eq "Local"){
	$chan = $chan_num;
	$callerid = $chan_num;
#	db_update({'chan' => $chan}, 'callerid = \''.$chan_num.'\'');
    }
    
    print "Rename_cb DBG Newname: ".$chan_type." ".$chan_num." ".$chan_id." ".$chan."\n";
    
    # m_eventcallback [DBG] Defined: Rename
    # Start Dump [DBG]
    # $VAR1 = 'Newname';
    # $VAR2 = 'Local/212@default-d3fb,1<ZOMBIE>';
    # $VAR3 = 'Timestamp';
    # $VAR4 = '1201599442.350916';
    # $VAR5 = 'Event';
    # $VAR6 = 'Rename';
    # $VAR7 = 'Uniqueid';
    # $VAR8 = '1201599439.16323';
    # $VAR9 = 'Privilege';
    # $VAR10 = 'call,all';
    # $VAR11 = 'Oldname';
    # $VAR12 = 'SIP/212-07b40000<MASQ>';
    # End Dump [DBG]
}

sub default_cb{
    my %data = @_;
    print "Default Event Handler!!! \n\n" if $DEBUG_DEFAULT_CB;
    return;
}

sub dump_cb{
    my %data = @_;
    print "Start Dump [DBG]\n";
    print Dumper %data;
    print "End Dump [DBG]\n\n";
}

sub test_cb{
    print "PeerStatus test\n";
    return;
}

## ----------------------------	##
## 	Error functions		##
## ----------------------------	##
sub error
{
    my ($error) = @_;
    if ($error) {
	$ERRSTR = $error;
    }
    
    return $ERRSTR;	
}


## ----------------------------	##
## 	Stuff functions		##
## ----------------------------	##
sub to_timestamp{
        my $time = shift;
        my @t=localtime($time);
        #my $timestamp = sprintf "'%4d-%02d-%02d %02d:%02d:%02d%s'", $t[5]+1900,$t[4]+1,$t[3],$t[2],$t[1],$t[0],$tz;
        my $timestamp = sprintf "%4d-%02d-%02d %02d:%02d:%02d", $t[5]+1900,$t[4]+1,$t[3],$t[2],$t[1],$t[0];
    return $timestamp;
}


sub h2s {
    my (%thash) = @_;
    my $tstring = '';
    foreach my $key (keys %thash) {
	$tstring .= $key . ': ' . $thash{$key} . $EOL;
    }
    return $tstring;
}
			    
sub s2h {
    my ($tstring) = @_;
    my %thash;
    foreach my $line (split(/$EOL/, $tstring)) {
	if ($line =~ /(\w*):\s*(\w*)/) {
	    $thash{$1} = $2;
	}
    }
    return %thash;
}

sub a2h {
    my (@a,@b) = @_;
    my $c;
    for (my $i = 0; $i < @a; $i++)
    {
	$c->{$a[$i]} = $b[$i];
    }
    return $c;
}

sub splitresult {
    my ($res) = @_;
    my ($key, $val) = ('', '');
	
    $res =~ /^([^:]+):\ {0,1}([^\ ].*)$/;
    $key = $1 if ($1);
    $val = $2 if ($2);
	    
return ($key, $val);
}

# ------------- #
#     Main	#
# ------------- #
sub main
{
# Monitor init						
    m_connect;
    eventloop_thread;
    sendcommand_thread;
    eventloop_thread_join;
    m_disconnect;
}

main;
# END
