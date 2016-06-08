<?
if(isset($_POST['callid'])){
    	$callid = $_POST['callid'];
    } else {
	$callid = 0;
}

if(isset($_POST['agent'])){
        $agent = $_POST['agent'];
    } else {
	$agent = 0;
}
		
		
$data=accmGet("queue_log",array($_SESSION["date_begin"],$_SESSION["date_end"]),0,0,$callid,$agent);
?>

<div id="search" style="border:0px solid #000; padding:2px;">
    <form action="index.php?show=2" method="POST">
	<b>id: </b><input type="text" name="callid" />
	<b>Агент:</b>
	<select id="agent" name="agent">
	        <option value="0" selected>Все агенты</option>
		    <? fillSelection($agents); ?>
	</select>
			
        <input type="submit" value="Поиск" />
    </form>
</div>

<?
$head=array_keys($data[0]);
print array2table($data,'col',$head);

function fillSelection($options){
    foreach ($options as $option){
            print "<option value='$option'>$option</option>";
	        }
}
		
?>				    

