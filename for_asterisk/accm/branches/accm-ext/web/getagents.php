<?
#Обработка прилётов-залётов
require_once('config.php');

require_once "lib/JsHttpRequest/JsHttpRequest.php";
$JsHttpRequest =& new JsHttpRequest("utf-8");
//$GLOBALS['_RESULT']=array('data'=>session_id());

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
				
$data = accmGetAgents(array($_SESSION["date_begin"],$_SESSION["date_end"]),0,$callerid);

$GLOBALS["_RESULT"]=array('data' => $data);

?>
		<b>Пришедшие значения:</b> <? print_r($_REQUEST);print_r($_SESSION); ?>
