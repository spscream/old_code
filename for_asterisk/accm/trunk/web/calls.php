<?
if(isset($_POST['agent'])){
	$agent = $_POST['agent'];
} else {
	$agent = 0;
}

if(isset($_POST['callerid'])){
	$callerid = $_POST['callerid'];
} else {
	$callerid = 0;
}

$data = accmGetCalls(array($_SESSION["date_begin"],$_SESSION["date_end"]),0,0,$agent,$callerid);


function printCallsTable($data,$class){
    $headers = array_keys($data[0]);
    $tr = "<tr class=\"col\">";
    $td = "<td class=\"col\">";
    $th = "<th class=\"col\">";
    array_push($headers,"file");
    echo "<table>";
    if(is_array($headers)){
	echo $tr;
    
	for($i=0; $i<count($headers);$i++){
	echo $th.$headers[$i]."</th>";
	}
	echo "</tr>";
    };

    if(is_array($data)){
	$c=1;
	foreach ($data as $lines){
	    $filename = "";
	    if (exec("ls /var/spool/asterisk/monitor | grep ".$lines["callid"],$filename))
		{
		    $file = "/var/spool/asterisk/monitor/".$filename[0];
		    if(file_exists($file)){
			$callfile_url = "<a href=get.php?file=".$filename[0].">WAV</a>";
		    }
		}
	    else  if (exec("ls /var/spool/asterisk/monitor/11 | grep ".$lines["callid"],$filename))
		{
		    $file = "/var/spool/asterisk/monitor/11/".$filename[0];
		    if(file_exists($file)){
			$callfile_url = "<a href=get.php?file=".$filename[0].">WAV</a>";
		    }
		}
	    else {
	    $callfile_url = "N/A";
	    }
	    array_push($lines,$callfile_url);
	        echo "<tr class=\"".$class.$c."\">";
		$td = "<td class=\"".$class.$c."\">";
		foreach ($lines as $cell){
		    echo $td.$cell."</td>";
		}
		echo "</tr>";
		$c=!$c;		    
	}    
	echo "</table>";
    };
}

?>

<div id="search" style="border:0px solid #000; padding:2px;">
    <form action="index.php?show=4" method="POST">
    <span id="agents">
    Агент: 
    <select id="agent" name="agent">
    <option value="0" selected>Все агенты</option>
    <? fillSelection($agents); ?>
    </select>
    </span>
    <span id="callerid">
    Номер: <input type="text" size="15" name="callerid" />
    </span>
    <input type="submit" value="Обновить" />
    </form>
</div>

<div id="data">

<?

$head=array_keys($data[0]);

#print array2table($data,'col',$head);
print printCallsTable($data,'col');

function fillSelection($options){
    foreach ($options as $option){
	print "<option value='$option'>$option</option>";
    }
}

?>

</div>