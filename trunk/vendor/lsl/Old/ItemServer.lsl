// Dow we want to see debug output?
integer g_nDebugging=TRUE;

integer itemcounter;
key httprequest;
key queuerequest;
string baseurl = "http://collardata1.appspot.com/updater/";
integer ready;

// added for a regular resubmiting of the data to the http db
float g_fTimerDuration=30.0;
float g_fResubmitTimeLimit=14400.0;
float g_fResubmitTime;

// var to make sure the qwner gets not noticed on inbetween updates
integer g_nQuietMode=TRUE;

// Debug output
Debug(string s)
{
    if (g_nDebugging) llOwnerSay(s);
}

UpdateItem()
{
    integer nNeededPerm = (PERM_MODIFY | PERM_COPY | PERM_TRANSFER);
    string url = baseurl;
    string object = llList2String(llParseString2List(llGetInventoryName(INVENTORY_OBJECT, itemcounter), [" - "], []), 0);
    string version = llList2String(llParseString2List(llGetInventoryName(INVENTORY_OBJECT, itemcounter), [" - "], []), 1);

    string szTextureName = object;
    string szTextureMessage;
    string szTextureKey=""; // we use a string here, as we want to submit an empty sttring if not texture was found.
    
    if (llGetInventoryType(szTextureName)==INVENTORY_TEXTURE)
    {
        if ((llGetInventoryPermMask(szTextureName, MASK_NEXT) & nNeededPerm)==nNeededPerm)
        {
            szTextureKey=llGetInventoryKey(szTextureName);
        }
        else
        {
            szTextureMessage="The texture for '"+object+"' needs to be full permission ot be distributed automatically.";
        }
    }
    else
    {
         szTextureMessage="There is no texture for '"+object+"' or it is named wrong. For the automatic texture distributing it needs to be called '"+szTextureName+"' and full perm.";
    }
    url += "givercheckin?";
    url += "&object=" + llEscapeURL(object);
    url += "&version=" + llEscapeURL(version);
    if (szTextureKey!="")
    {
         url += "&texture=" + llEscapeURL(szTextureKey);
    }
    else
    {
         if (!g_nQuietMode) llOwnerSay(szTextureMessage);
    }
    Debug(url);
    httprequest = llHTTPRequest(url, [HTTP_METHOD, "GET",HTTP_MIMETYPE,"text/plain;charset=utf-8"], "");     
}

// The finalize gets called after the last object has been submitted to clean out outdated objects
// could be removed as the cron job wil take care of that
FinalizeUpdate()
{
    string url = baseurl;
    url += "givercheckin";
    Debug(url);
    httprequest = llHTTPRequest(url, [HTTP_METHOD, "PUT",HTTP_MIMETYPE,"text/plain;charset=utf-8"], "");     
}

GetDeliveryQueue()
{
    string url = baseurl;
    url += "deliveryqueue?";
    url += "&pop=true";    
    queuerequest = llHTTPRequest(url, [HTTP_METHOD, "GET"], "");
}

//===============================================================================
//= parameters   :    string    szMsg   message string received
//=
//= return        :    integer TRUE/FALSE
//=
//= description  :    checks if a string begin with another string
//=
//===============================================================================

integer nStartsWith(string szHaystack, string szNeedle) // http://wiki.secondlife.com/wiki/llSubStringIndex
{
    return (llDeleteSubString(szHaystack, llStringLength(szNeedle), -1) == szNeedle);
}


default
{
    state_entry()
    {
        // Be chatty tio the users
        g_nQuietMode=FALSE;
        llOwnerSay("Submitting items...");
        //http://ilse.kicks-ass.net/updater/givercheckin?mysecretkey=0f182629-00f9-011c-75d1-55eb22871354&key=35k34&object=blah&version=3
        if(llGetInventoryNumber(INVENTORY_OBJECT)>0)
        {
            UpdateItem();       
        }
        else
        {
            llOwnerSay("No items in the box, falling asleep!");
        }
    }
    
    http_response(key request_id, integer status, list metadata, string body)
    {
        if (request_id == httprequest)
        {
            // // is it an "positive" answer from the databae?
            if ((body == "saved") || (nStartsWith(body,"Illegal item update")) )
            {
                if (body!="saved")
                // something went wrong with storing the data, inform the user, but continue
                {
                    llOwnerSay(body+"\nPlease contact an OC Administrator!");
                }
                // next item
                itemcounter++;
                if (itemcounter < llGetInventoryNumber(INVENTORY_OBJECT))
                {
                    // Update items, as long as there are some
                    UpdateItem();
                }
                else
                {
                    // last item has been submitted
                    if (!g_nQuietMode) llOwnerSay("Done");
                    // Make sure the dtatabase gets cleaned, wil be as well handled by a cron job
                    FinalizeUpdate();
                    llGetNextEmail("", "");
                    llSetTimerEvent(g_fTimerDuration);
                    ready = TRUE;
                }
            }
        }
        else if (request_id == queuerequest)
        // Delivery part, unchnegd atm
        {       
            //split on \n
            list deliveries = llParseString2List(body, ["\n"], []);
            integer n;
            integer num = llGetListLength(deliveries);
            for (n = 0; n < num; n++)
            {            
                string line = llList2String(deliveries, n);
                //we'll either have a | delimited list, or a blank line, or "more"
                if (line == "more")
                {
                    GetDeliveryQueue();
                }
                else
                {
                    list delivery = llParseString2List(line, ["|"], []);
                    if (llGetListLength(delivery) == 2)
                    {
                        string object = llList2String(delivery, 0);
                        key rcpt = (key)llList2String(delivery, 1);
                        //send item, if in inventory
                        if (llGetInventoryType(object) != INVENTORY_NONE)
                        {
                            llGiveInventory(rcpt, object);
                        }
                        else
                        {
                            llInstantMessage(llGetOwner(), "Trying to deliver " + object + " but it's not in inventory.");
                        }
                    }
                }
            }
        }
    }

    on_rez(integer param)
    {
        llResetScript();
    }
    
    changed(integer change)
    {
        if (change & CHANGED_INVENTORY && ready)
        {
            llOwnerSay("Inventory changed.  Touch to reset.");
        }
    }
    
    touch_start(integer num)
    {
        if (llDetectedKey(0) == llGetOwner())
        {
            llResetScript();
        }
    }
    
    email(string time, string address, string subj, string message, integer num_left)
    {
        //strip headers from message
        message = llDeleteSubString(message, 0, llSubStringIndex(message, "\n\n") + 1);   
        //remove trailing space
        if (llGetSubString(message, -1, -1) == " ")
        {
            message = llGetSubString(message, 0, -2);
        }
        //message should have <rcpt key>|exact object name
        key recipient = (key)llList2String(llParseString2List(message, ["|"], []), 0);
        string object = llList2String(llParseString2List(message, ["|"], []), 1);
        llMessageLinked(LINK_SET, 0, object, recipient);
        llGiveInventory(recipient, object);
        if (num_left)
        {
            //get next email
            llGetNextEmail("", "");
        }
    }
    
    timer()
    {
        // poll the delivery queue
        GetDeliveryQueue();
        // and updated the timer for automativc resubmitting
        g_fResubmitTime+=g_fTimerDuration;
        if (g_fResubmitTime>g_fResubmitTimeLimit)
        {
            // if its time to resumbit, reset the item counter and init the data transfer
            itemcounter=0;
            g_fResubmitTime=0;
            g_nQuietMode=TRUE;
            UpdateItem();
        }
    }
}
