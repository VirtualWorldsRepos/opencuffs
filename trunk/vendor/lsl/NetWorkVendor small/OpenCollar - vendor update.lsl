// Version 1.01
//on attach and on state_entry, http request for update

string g_sBaseURL = "http://collardata.appspot.com/updater/check?";

integer g_iUpdateIntervall = 80000; // 1 day for beta
key g_kHTTPRequest;

CheckForUpdate()
{
	list lParams = llParseString2List(llGetObjectDesc(), ["~"], []);
	string sName = llList2String(lParams, 0);
	string sVersion = llList2String(lParams, 1);
	if (sName == "" || sVersion == "")
	{
		llOwnerSay("You have changed my description.  Automatic updates are disabled.");
	}
	else
	{
		string sURL = g_sBaseURL;
		sURL += "object=" + llEscapeURL(sName);
		sURL += "&version=" + llEscapeURL(sVersion);
		g_kHTTPRequest = llHTTPRequest(sURL, [HTTP_METHOD, "GET",HTTP_MIMETYPE,"text/plain;charset=utf-8"], "");
	}
}

default
{
	state_entry()
	{
		CheckForUpdate();
		llSetTimerEvent(g_iUpdateIntervall);
	}

	on_rez(integer param)
	{
		llResetScript();
	}

	http_response(key kRequest_id, integer iStatus, list lMetadata, string sBody)
	{
		if (kRequest_id == g_kHTTPRequest)
		{
			if (llGetListLength(llParseString2List(sBody, ["|"], [])) == 2)
			{
				llInstantMessage(llGetOwner(), "There is a new version of "+ llGetObjectName() +" available.  An update should be delivered in 30 seconds or less.");
				//client side is done now.  server has queued the delivery,
				//and in-world giver will send us our object when it next
				//pings the server
			}
		}
	}

	timer()
	{
		CheckForUpdate();
	}
}
