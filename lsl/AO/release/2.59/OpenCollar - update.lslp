//on attach and on state_entry, http request for update

string baseurl = "http://collardata.appspot.com/updater/check?";

key httprequest;

CheckForUpdate()
{
    list params = llParseString2List(llGetObjectDesc(), ["~"], []);
    string name = llList2String(params, 0);
    string version = llList2String(params, 1);
    if (name == "" || version == "")
    {
        llOwnerSay("You have changed my description.  Automatic updates are disabled.");
    }
    else
    {
        string url = baseurl;
        url += "object=" + llEscapeURL(name);
        url += "&version=" + llEscapeURL(version);
        httprequest = llHTTPRequest(url, [HTTP_METHOD, "GET",HTTP_MIMETYPE,"text/plain;charset=utf-8"], "");        
    }
}

default
{
    state_entry()
    {
        CheckForUpdate();
    }
        
    on_rez(integer param)
    {
        llResetScript();
    }
    
    http_response(key request_id, integer status, list metadata, string body)
    {
        if (request_id == httprequest)
        {
            if (llGetListLength(llParseString2List(body, ["|"], [])) == 2)
            {
                llOwnerSay("There is a new version of me available.  An update should be delivered in 30 seconds or less.");
                //client side is done now.  server has queued the delivery, 
                //and in-world giver will send us our object when it next 
                //pings the server
            }
        }
    }
}
