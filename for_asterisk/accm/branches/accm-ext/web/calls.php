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

$data_json = json_encode($data);

$head=array_keys($data[0]);

function fillSelection($options){
    foreach ($options as $option){
	print "<option value='$option'>$option</option>";
    }
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
    <br />
    <span id="callerid">
    Номер: <input type="text" size="15" name="callerid" />
    </span>
    <br />
    <span id="calltime">
    Продолжительность: <input type="text" size="5" name="callerid" />
    </span>
    <br />
    <input type="submit" value="Обновить" />
    </form>
</div>
<div id="data">
<?
print_r ($data_json);
?>
</div>
<script>

</script>


<?

#print array2table($data,'col',$head);


?>


