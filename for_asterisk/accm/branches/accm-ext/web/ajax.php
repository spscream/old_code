<?
#Обработка прилётов-залётов
require_once('config.php');

require_once "lib/JsHttpRequest/JsHttpRequest.php";
$JsHttpRequest =& new JsHttpRequest("utf-8");
//$GLOBALS['_RESULT']=array('data'=>session_id());
switch ($_REQUEST["action"])
{
	case "getValue":
		$GLOBALS["_RESULT"]=array('data'=> $_SESSION[$_REQUEST["item"]]);
		break;
	case "setValue":
		$_SESSION[$_REQUEST["item"]]=$_REQUEST["data"];
		break;
}

?>
		<b>Пришедшие значения:</b> <? print_r($_REQUEST);print_r($_SESSION); ?>
