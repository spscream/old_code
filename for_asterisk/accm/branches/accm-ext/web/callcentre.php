<?
$data=accmGetAgentsOnline();
$head=array_keys($data[0]);
print array2table($data,'col',$head);

?>