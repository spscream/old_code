<?
$data=accmGetAgentsStat();
$head=array_keys($data[0]);
print array2table($data,'col',$head,"agents_table");
?>