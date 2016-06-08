<?

if(isset($_POST['queue'])){
    $queue = $_POST['queue'];
	} else {
    $queue = 3;
}

$data=accmGetAgentsStat($queue);
$head=array_keys($data[0]);
print array2table($data,'col',$head,"agents_table");
?>