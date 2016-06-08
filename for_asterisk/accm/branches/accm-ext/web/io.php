<?
#Ввод-вывод пользовательских данных

#$date=array("now() - interval '50 min'","now()");
if(isset($_GET["show"])){
	switch($_GET["show"])
	{
	    case "1":
		require_once('agents.php');
		break;
	    case "2":
		require_once('queue_log.php');
		break;
	    case "3":
		require_once('callcentre.php');
		break;
	    case "4";
		require_once('calls.php');
		break;
	    default:
		require_once('agents.php');
		break;
	}
    } else
	{
	    require_once('agents.php');
	}

?>
