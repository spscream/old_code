<?

$dbhost="node-f";
$dbname="accm";
$dbuser="scream";
$dbpass="1q2w3e4r";

$pages=array(
	1=>"agents.php",
	2=>"queue_log.php",
	3=>"callcentre.php",
	4=>"calls.php");

define(LOCALE,"ru");

require_once('libpg.php');
require_once('session.php');
require_once('language.php');
require_once('check.php');
require_once('libqueue.php');
require_once('table.php');
require_once('lib/JsHttpRequest/JsHttpRequest.php');

?>