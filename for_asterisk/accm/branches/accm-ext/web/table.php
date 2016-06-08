<?
#Тут будем рендерить таблички

function array2table($data,$class=null,$headers=null,$name=null,$links=null)
{

			if (is_string($class))
	{
		echo "<table class=\"".$class."\">";
		$tr="<tr class=\"".$class."\">";
		$td="<td class=\"".$class."\">";
		$th="<th class=\"".$class."\">";

	}
	else
	{
		echo "<table>";
		$tr="<tr>";
		$th="<th>";
		$td="<td>";
	};

	if (is_array($headers))
	{
		echo $tr;

		for ($i=0; $i<count($headers); $i++)
		{
			echo $th.inlang($name,$headers[$i])."</th>";
		};
		echo "</tr>";
	};

	if (is_array($data))
	{
		$c=1;
		foreach ($data as $lines)
		{

			echo "<tr class=\"".$class.$c."\">";
			$td = "<td class=\"".$class.$c."\">";
			foreach ($lines as $cell)
			{
				echo $td.$cell."</td>";
			}
			echo "</tr>";
			$c=!$c;
		}
	}
	echo "</table>";
//	return $table;
};


?>