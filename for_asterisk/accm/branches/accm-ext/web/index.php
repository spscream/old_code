<?require_once('config.php');?><!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="ru">
<head>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
<title>accm</title>
<link rel="stylesheet" href="/accm.css" type="text/css" />
<link rel="stylesheet" type="text/css" media="all" href="calendar-brown.css" title="system" />
  <script type="text/javascript" src="calendar.js"></script>
  <script type="text/javascript" src="calendar-ru.js"></script>
  <script type="text/javascript" src="calendar-setup.js"></script>
  <script type="text/javascript" src="hideshow.js"></script>
		<script type="text/javascript" src="/lib/JsHttpRequest/JsHttpRequest.js"></script>
		<script type="text/javascript" src="/accmajax.js"></script>

</head>
		<body onload="letsbegin();">
		<div id="username" style="float: right;">Вы вошли как </div>
		<div id="title" style="height: 95px; background: url('/accm_banner.png') no-repeat bottom right; border-bottom: 2px #000 solid; padding: 0px 0px 3px 0px;">
		<span style="position: relative; top:20px;"><img src="/begun_logo.gif" /></span>
		</div>
		<div style="padding: 2px; background: #ddd; position: absolute; left: 10px; width: 90%;">
		<span class="button"><a href="/index.php?show=1">агенты</a> |</span>
		<span class="button"><a href="/index.php?show=2">лог очереди</a> |</span>
		<span class="button"><a href="/index.php?show=3">контакт-центр</a> |</span>
		<span class="button"><a href="/index.php?show=4">звонки</a></span>
		</div>
		<div style="padding: 2px; background: #ddd; text-align: right;">
		<span class="button"><a onclick="showhide('debug')" value="1"> debug </a></span>
		<span class="button"><a onclick="getAgents('data')" value="1"> data </a></span>
		</div>
		
		<div style="border-top: 2px #000 solid; padding: 3px; ">
		<form  method="post" enctype="multipart/form-data" onsubmit="return false">
		Отчётный период: <input type="text" name="date" id="date_begin" size="13" onchange="setItem('date_begin',this.value)"/> по <input type="text" name="date" id="date_end" size="13" onchange="setItem('date_end',this.value)" />&nbsp;<input type="checkbox" id="date_end_now" value="1" onchange="document.getElementById('date_end').disabled=!document.getElementById('date_end').disabled; setItem('date_end_now',document.getElementById('date_end').disabled);" />&nbsp;<label for="date_end_now">сегодня</label>
		</form>
		</div>
  		<script type="text/javascript" src="accmcalendar.js"></script>

		<div id="ans" style="border:1px solid #000; padding:2px; display: none; white-space: pre;">
		Structured results
		</div>

		<div id="debug" style="border:1px dashed red; padding:2px; display: none;  white-space: pre;">
		Debug info
		</div>
		
		<div id="module">
		<? require_once('io.php');?>
		</div>
</body>
</html>
