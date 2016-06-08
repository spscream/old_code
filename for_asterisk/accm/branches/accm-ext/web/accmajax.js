function letsbegin()
{
	getItem('date_begin');
	getItem('date_end');
	getsetField('username');
	getItem('date_end_now',0);
	if (document.getElementById('date_end_now').checked=true)
	{
		document.getElementById('date_end').disabled='disabled';
	}

}

function send_to(item,itemName) {
	var myRequest = new Array();
	myRequest[itemName]=item.value;
	myRequest['action']='setValue';
	JsHttpRequest.query(
            'ajax.php',
			myRequest,

            function(result, errors) {
                document.getElementById("debug").innerHTML = errors;
                if (result) {
                    item.value = result["data"];
					for (var i in result) {
						alert('key is: ' + i + ', value is: ' + eval('result.' + i));
					}
                }
            },
            false
        );
}

function getItem(item,v) {
	var myRequest = new Array();
	var itemValue;
	myRequest["item"]=item;
	myRequest['action']='getValue';
	JsHttpRequest.query(
	     'ajax.php',
			 myRequest,

	    function(result, errors) {
		document.getElementById("debug").innerHTML = errors;
		if (result) {
		if (v)
		     {
			 document.getElementById(item).checked = result["data"];
		     }else {
			 document.getElementById(item).value = result["data"];
		    }
		}
	},
	false
        );
}

function setItem(item,itemValue) {
	var myRequest = new Array();
	var itemValue;
	myRequest["item"]=item;
	myRequest['data']=itemValue;
	myRequest['action']='setValue';
	JsHttpRequest.query(
 'ajax.php',
 myRequest,

 function(result, errors) {
	 document.getElementById("debug").innerHTML = errors;
	 if (result) {
		 document.getElementById(item).value = result["data"];
	 }
 },
 false
        );
}

function getsetField(item) {
	var myRequest = new Array();
	var itemValue;
	myRequest["item"]=item;
	myRequest['action']='getValue';
	JsHttpRequest.query(
 'ajax.php',
 myRequest,

 function(result, errors) {
	 document.getElementById("debug").innerHTML = errors;
	 if (result) {
			 document.getElementById(item).innerHTML += result["data"];
	 }
 },
 false
        );
}

function getAgents(item){
	var myRequest = new Array();
		JsHttpRequest.query(
 'getagents.php',
 myRequest,

 function(result, errors) {
	 document.getElementById("debug").innerHTML = errors;
	 if (result) {
			 document.getElementById(item).innerHTML = result["data"][0]["agent"];
	 }
 },
 false
        );
}

