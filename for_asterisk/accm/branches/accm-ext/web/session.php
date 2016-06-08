<?
#Функционал работы с сессиями
  if (!isset($_SERVER['PHP_AUTH_USER'])) {
	header('WWW-Authenticate: Basic realm="My Realm"');
	header('HTTP/1.0 401 Unauthorized');
	echo 'Restricted area\n';
	die;
  } else {
	  $user=accmGetUser($_SERVER['PHP_AUTH_USER'],$_SERVER['PHP_AUTH_PW']);
	  if (!(count($user)>1))
	  {
		  header('WWW-Authenticate: Basic realm="My Realm"');
		  header('HTTP/1.0 401 Unauthorized');
		  echo 'Restricted area\n';
		  die;
	  }

  }

if (!session_id())
		session_start();

$_SESSION["agent"]=$_SERVER['PHP_AUTH_USER'];
$_SESSION["username"]=$user["name"];
$_SESSION["user"]=$user;
if (!isset($_SESSION["date_end_now"]))
	$_SESSION["date_end_now"]="1";

if (!isset($_SESSION["date_begin"]))
	$_SESSION["date_begin"]= date("Y-m-d H:i",time()-86400);

if (!isset($_SESSION["date_end"]))
	$_SESSION["date_end"]= date("Y-m-d H:i");
?>