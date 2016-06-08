<?
#Локализации
$lang = array( "ru" => array (
			   		"agents_table" => array (
								"agent" => "агент",
		 						"calls" => "обработано",
		 						"calltime" => "продолжительность",
   								"holdtime" => "ожидание",
	 							"unanswered" => "пропущено",
  								"transfered" => "переведено",
  								"worktime" => "время работы",
  								"autologoff" => "отключён системой"
									 )
							 )
			 );

function inlang($name=null, $text)
{
	global $lang;

	if (!isset($name) || !isset($lang[LOCALE][$name][$text]))
		return $text;
	else
		return $lang[LOCALE][$name][$text];
}
?>