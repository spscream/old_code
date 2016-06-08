<?php
#

function accmConnect()
{
	global $dbh, $dbhost, $dbname, $dbuser, $dbpass;
	$dbh = pg_connect("host=".$dbhost." dbname=".$dbname." user=".$dbuser." password=".$dbpass)
    		or die('Could not connect: ' . pg_last_error());
	return $dbh;
}

function accmGetUser($user,$pass)
{
	global $dbh;
	if (preg_match("/^[a-zA-Z0-9\-\_]+$/",$user))
		return 0;
	return pg_fetch_array(pg_query("select agent,name from agents where agent='".$user."' and pass='".md5($pass)."'"),NULL,PGSQL_ASSOC);
}

function accmGetCalls($date=0,$format=null,$count=0,$agent=0,$callerid=0)
{
	global $dbh;
	global $agents;
	$query='';
	$result='';
	$agents='';
	$query="SELECT q1.date as date,".
		"agents.agent as agent,".
		"q1.agent as aid,".
		"q1.callid,".
		"reasons.text as reason,".
		"clid.data2 as number,".
		"case when q1.reason in (7,8) then q1.data1 end as holdtime,".
		"case when q1.reason in (7,8) then q1.data2 end as calltime,".
		"case when q1.reason = 16 then q1.data1 end as transfer_to ".
		"from queue_log as q1,".
        	"(select queue_log.data2,queue_log.callid from queue_log where reason=11) as clid,".
        	"reasons,".
        	"agents ".
    		"where q1.callid=clid.callid and q1.queue=3 ";
	if ($_SESSION["date_end_now"]) {
		$query=$query." and q1.date > '".$date[0]."' ";
	}else{
		$query=$query." and q1.date between '".$date[0]."' and '".$date[1]."' ";
	};

	if ($agent){
	    $query=$query."and agents.agent='".$agent."' ";
	}

	if ($callerid){
	/* FIXME $callerid заэкранировать */
	    $query=$query."and clid.data2 like '%".$callerid."%'";
	}

	$query=$query."and q1.reason in (7,8,16,17) ".
		"and reasons.id=q1.reason ".
		"and agents.id=q1.agent ".
		"group by q1.date,q1.agent,agents.agent,q1.callid,q1.reason,reasons.text,clid.data2,q1.data1,q1.data2 order by q1.callid,q1.date";

	if ($count) {
		$query=$query." limit ".$count;
	};

	$_SESSION["query"]=$query;
	$result = pg_query($dbh,$query);
	$agents = array_values (array_unique (pg_fetch_all_columns($result,1)));
	sort ($agents);
	return pg_fetch_all($result);
}

function accmGet($item,$date=0,$format=null,$count=0,$callid=0,$agent=0)
{
	global $dbh;
	global $agents;
	$query='';
	switch ($item) {
		case "agents" :
			$query="select id,agent from agents";
			break;
		case "queue_log":
			$query="SELECT queue_log.date as date,".
			    "queue_log.callid as callid,".
			    "queues.text as queue,".
			    "agents.agent as agent,".
			    "reasons.text as reason,".
			    "data1,data2,data3 ".
			    "from agents,queue_log,reasons,queues ".
			    "where queues.id=queue_log.queue and queue_log.agent=agents.id and reasons.id=queue_log.reason";
						
			
			
			if($callid){
			    $query=$query." and queue_log.callid=".$callid;
			}
			else {
			    if ($agent){
			    $query=$query." and agents.agent='".$agent."' ";
			    }
			
			    if ($_SESSION["date_end_now"]) {
				$query=$query." and date > '".$date[0]."' order by queue_log.date";
			    }else{
				$query=$query." and date between '".$date[0]."' and '".$date[1]."' order by queue_log.date";
			    };

			    if ($count) {
				$query=$query." limit ".$count;
			    };
			};

			break;
		case "queues":
			$query="select id,text from queues";
			break;
		case "reasons":
			$query="select id,text from reasons";
			break;
		case "transfers":
			$query="select no,reason,start,stop,callid,agent from transfers";
			break;
		case "abonents":
			$query="select id,comm,info from abonents";
			break;
		case "phones":
			$query="select id,ph_no from phones";
			break;


	}

	$_SESSION["query"]=$query;
	$result = pg_query($dbh,$query);
	$agents = array_values (array_unique (pg_fetch_all_columns($result,3)));
	sort ($agents);
	return pg_fetch_all($result);
}

function accmGetAgentsStat($queue=3,$date=0,$format=null,$count=0)
{

	global $dbh;
	$query='';
	$query='SELECT agents.id,agents.agent,'.
			'count(case queue_log.reason when 10 then 1 end) as calls,'.
			'sum(case when queue_log.reason in (7,8) then queue_log.data2::interval end) as calltime,'.
			'sum(case when queue_log.reason = 10 then queue_log.data1::interval end) as holdtime,'.
/*			'count(case queue_log.reason when 7 then 1 end) as by_agent,'.
			'count(case queue_log.reason when 8 then 1 end) as by_caller,'.*/
			'count(case queue_log.reason when 17 then 1 end) as  unanswered,'.
			'count(case queue_log.reason when 16 then 1 end) as  transfered,'.
			'sum(case when queue_log.data1 <> \'\' and queue_log.reason=6 then queue_log.data2::interval end) as  worktime,'.
			'count(case when queue_log.data3 = \'Autologoff\' and queue_log.reason=6 then queue_log.data2 end) as  autologoff'.
//			'count(case when queue_log.data1 is null and queue_log.reason=6 then 1 end) as  syslogoff '.
			' from agents, queue_log where queue_log.agent=agents.id and queue_log.reason in (6,7,8,10,16,17)';

	if ($_SESSION["date_end_now"]) {
		$query=$query." and date > '".$_SESSION["date_begin"]."' group by agents.id,agents.agent order by agent";
	} else {
		$query=$query." and date between '".$_SESSION["date_begin"]."' and '".$_SESSION["date_end"]."' group by agents.id,agents.agent order by agent";
	};

	if ($count) {
		$query=$query." limit ".$count;
	};

	$_SESSION["query"]=$query;
	return pg_fetch_all(pg_query($dbh,$query));

}

function accmGetCallsStat($format=null,$count=0)
{

	global $dbh;
	$query='';
	$query="SELECT q1.callid,q1.date,q1.data2 as number,agents.agent from queue_log as q1, queue_log as q2,agents where q2.agent=agents.id and q1.callid=q2.callid and q1.reason=11 and q2.reason=10 ";

	if ($_SESSION["date_end_now"]) {
		$query=$query." and q1.date > '".$_SESSION["date_begin"]."' group by q1.callid,q1.date,q1.data2,agents.agent order by date desc";
	}else{
		$query=$query." and q1.date between '".$_SESSION["date_begin"]."' and '".$_SESSION["date_end"]."' group by q1.callid,q1.date,q1.data2,agents.agent order by date desc";
	};

	if ($count) {
		$query=$query." limit ".$count;
	};

	$_SESSION["query"]=$query;
	return pg_fetch_all(pg_query($dbh,$query));

}

function accmGetAgentsOnline()
{
	global $dbh;
	$query='';
	$query='SELECT agents.agent as agent,'.
	'agents.name as agent_name,'.
	'status.text as status,'.
	'queues.text as queue,'.
	'agents_online.chan as chan,'.
	'agents_online.logintime as logintime,'.
	'agents_online.callstaken as callstaken,'.
	'agents_online.lastcall as lastcall '.
	'from agents, agents_online, status, queues where agents.id=agents_online.id and status.id=agents_online.status and queues.id=agents_online.queue order by agent;';
	$_SESSION["query"] = $query;
	return pg_fetch_all(pg_query($dbh,$query));

}

function accmGetAgents($date=0,$format=null,$callerid=0)
{
	global $dbh;
	$query='';
	$query="SELECT queue_log.date as date,agents.agent as agent,queue_log.agent as aid ".
		"from queue_log,".
        	"agents ";

	if ($_SESSION["date_end_now"]) {
		$query=$query."where queue_log.date > '".$date[0]."' ";
	}else{
		$query=$query."where queue_log.date between '".$date[0]."' and '".$date[1]."' ";
	};

	$query=$query."and agents.id=queue_log.agent ".
		"order by queue_log.date";

	$_SESSION["query"]=$query;
	$result = pg_query($dbh,$query);
	$agents = array_values (array_unique (pg_fetch_all_columns($result,1)));
	sort ($agents);
	return pg_fetch_all($result);
}

accmConnect();

?>
