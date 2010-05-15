?// !OpenVendor Texture Server - 0.007
// Dow we want to see debug output?
integer g_iDebugging=FALSE;

integer g_iItemcounter;
key g_keyHTTPSendRequest;
key g_keyHTTPDeleteRequest;
key g_keyHTTPDoneRequest;
string g_sBaseURL = "http://vendors.mycollar.org";
string g_sTextureServerURL;
integer g_iReady;

integer g_iMaxItemsToSend = 10;
integer g_iItemSend;

string g_sAdminNames;

// added for a regular resubmiting of the data to the http db
float g_fTimerDuration=3600.0;

// var to make sure the qwner gets not noticed on inbetween updates
integer g_iQuietMode=TRUE;

// Debug output
Debug(string s)
{
    if (g_iDebugging) llOwnerSay(s);
}

AddAdmins()
{
    integer i;
    integer iCount = llGetInventoryNumber(INVENTORY_NOTECARD);
    string sName;

    g_sAdminNames = "";

    for (i = 0; i < iCount; i++)
    {
        sName = llGetInventoryName(INVENTORY_NOTECARD, i);
        if (llGetSubString(sName,0,0) == "!")
        {
            g_sAdminNames += llGetSubString(sName,1,-1) + ",";
            //llSay(0, "Admin name added: " + sName);
        }
    }
}


StartUpdate()
{
    integer nNeededPerm = (PERM_MODIFY | PERM_COPY | PERM_TRANSFER);
    integer i;
    for (i = 0; i< llGetInventoryNumber(INVENTORY_TEXTURE); i++)
    {
        string szTextureName = llGetInventoryName(INVENTORY_TEXTURE, i);
        if ((llGetInventoryPermMask(szTextureName, MASK_NEXT) & nNeededPerm)!=nNeededPerm)
        {
            llSay(0, "The texture '"+szTextureName+"' needs to be full permission to be distributed automatically. Updating canceled");
            return;
        }

    }

    string url = g_sTextureServerURL + "deletetextures";
    g_keyHTTPDeleteRequest = llHTTPRequest(url, [HTTP_METHOD, "POST",HTTP_MIMETYPE,"text/plain;charset=utf-8"], "");
    g_iItemSend = 0;
    g_iItemcounter = 0;
}

UpdateTexture()
{
    string url = g_sTextureServerURL + "updatetextures";
    string sBody;
    integer iItemsToSend = 0;
    integer iLastItem = g_iItemcounter + g_iMaxItemsToSend;
    if (iLastItem > llGetInventoryNumber(INVENTORY_TEXTURE))
        iLastItem = llGetInventoryNumber(INVENTORY_TEXTURE);
    llSay(0, "Sending textures for items " + (string)(g_iItemcounter +1 ) + " - " + (string)iLastItem);
    do
    {

        string szTextureName = llGetInventoryName(INVENTORY_TEXTURE, g_iItemcounter);
        string szTextureKey=""; // we use a string here, as we want to submit an empty sttring if not texture was found.

        szTextureKey=llGetInventoryKey(szTextureName);
        sBody += szTextureName + "=" + szTextureKey+"\n";

        iItemsToSend++;
        g_iItemcounter++;
    } while ( (iItemsToSend < g_iMaxItemsToSend) && (g_iItemcounter<llGetInventoryNumber(INVENTORY_TEXTURE)));
    Debug(url);
    Debug(sBody);
    g_keyHTTPSendRequest = llHTTPRequest(url, [HTTP_METHOD, "POST",HTTP_MIMETYPE,"text/plain;charset=utf-8"], sBody);

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
        // Be chatty to the users
        g_iQuietMode=FALSE;
        string s = llStringTrim(llGetObjectDesc(),STRING_TRIM);
        if ((s != "") && (s != "(No Description)"))
        {
            g_sBaseURL = s;

        }
        llSay(0, "Server adress used: " + g_sBaseURL);
        g_sTextureServerURL = g_sBaseURL + "/vendor/";
        if(llGetInventoryNumber(INVENTORY_TEXTURE)>0)
        {
            llSay(0, "Ready for submitting textures, click the box...");
        }
        else
        {
            llSay(0, "No textures in the box, falling asleep!");
        }
        AddAdmins();
    }

    http_response(key request_id, integer status, list metadata, string body)
    {
        integer iErrorOccured = FALSE;
        if (request_id == g_keyHTTPDeleteRequest)
        {
            // llOwnerSay((string)status);
            if (status==200)
            {
                llSay(0, "Deleted sucessfull, now resubmitting ...");

                UpdateTexture();
            }
            else
            {
                iErrorOccured = TRUE;
            }
        }
        else if (request_id == g_keyHTTPSendRequest)
        {
            if (status==200)
            {
                // // is it an "positive" answer from the database?
                if ((body == "saved") || (nStartsWith(body,"Illegal item update")) )
                {
                    if (body!="saved")
                        // something went wrong with storing the data, inform the user, but continue
                    {
                        iErrorOccured = TRUE;
                    }
                    else
                    {
                        // next item
                        //g_iItemcounter++;
                        if (g_iItemcounter < llGetInventoryNumber(INVENTORY_TEXTURE))
                        {
                            // Update items, as long as there are some
                            UpdateTexture();
                        }
                        else
                        {
                            string url = g_sTextureServerURL + "updateversion?done=1";
                            g_keyHTTPDoneRequest = llHTTPRequest(url, [HTTP_METHOD, "POST",HTTP_MIMETYPE,"text/plain;charset=utf-8"], "");

                            // last item has been submitted
                            if (!g_iQuietMode) llSay(0, "Sending confirmation to database");
                        }
                    }
                }
            }
            else
            {
                iErrorOccured = TRUE;
            }


        }
        else if (request_id == g_keyHTTPDoneRequest)
        {
            if ((status==200) && (nStartsWith(body,"Version updated:")))
            {
                if (!g_iQuietMode) llSay(0, body);
                g_iReady = TRUE;

            }
            else
            {
                iErrorOccured = TRUE;
            }

        }

        if (iErrorOccured)
        {
            llSay(0, "HTTP error "+(string)status+"\n\nBody:\n"+body+"\n\nPlease contact an OC Database Administrator!");
            g_iReady = FALSE;
            llSetTimerEvent(0);
        }

    }

    on_rez(integer param)
    {
        llResetScript();
    }

    changed(integer change)
    {
        if (change & CHANGED_INVENTORY)
        {
            string s = llStringTrim(llGetObjectDesc(),STRING_TRIM);
            if ((s != "") && (s != "(No Description)"))
            {
                g_sBaseURL = s;

            }
            llSay(0, "Inventory changed.  Touch to reset. (Server adress used: " + g_sBaseURL + ")");
            AddAdmins();
        }
    }

    touch_start(integer num)
    {
        //llOwnerSay(g_sAdminNames+":"+ llDetectedName(0)+":"+(string)llSubStringIndex(g_sAdminNames, llDetectedName(0) ));
        if (llSubStringIndex(g_sAdminNames, llDetectedName(0) )>=0)
        {
            llSay(0, "Update of texture pack started ...");
            StartUpdate();
        }
    }

}
