SELECT agents.id,agents.agent, 
	count(case queue_log.reason when 10 then 1 end) as calls,
	sum(case when queue_log.reason in (7,8) then queue_log.data2::interval end) as calltime, 
	sum(case when queue_log.reason = 10 then queue_log.data1::interval end) as holdtime, 
	count(case queue_log.reason when 7 then 1 end) as by_agent, 
	count(case queue_log.reason when 8 then 1 end) as by_caller, 
	count(case queue_log.reason when 17 then 1 end) as  unanswered,
	count(case queue_log.reason when 16 then 1 end) as  transfer,
	sum(case when queue_log.data1 <> '' and queue_log.reason=6 then queue_log.data2::interval end) as  worktime,
	count(case when queue_log.data3 = 'Autologoff' and queue_log.reason=6 then queue_log.data2 end) as  autologoff,
	count(case when queue_log.data1 is null and queue_log.reason=6 then 1 end) as  syslogoff
from agents, queue_log where queue_log.agent=agents.id and queue_log.reason in (6,7,8,10,16,17) and queue_log.date >= '2007-12-01' group by agents.id,agents.agent order by agent;