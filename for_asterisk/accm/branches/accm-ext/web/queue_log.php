<?
if(isset($_POST['callid'])){
    	$callid = $_POST['callid'];
    } else {
	$callid = 0;
}
		
$data=accmGet("queue_log",array($_SESSION["date_begin"],$_SESSION["date_end"]),0,0,$callid);
?>

<div id="search" style="border:0px solid #000; padding:2px;">
    <form action="index.php?show=2" method="POST">
	<input type="text" name="callid" />
        <input type="submit" value="Поиск" />
    </form>
</div>

<?
$head=array_keys($data[0]);
print array2table($data,'col',$head);
?>				    

