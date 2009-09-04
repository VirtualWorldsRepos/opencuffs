// Dow we want to see debug output?
integer g_nDebugging=TRUE;

integer g_nItemcounter;
key g_keyHTTPRequest;
string g_szBaseURL = "http://openvendor1.appspot.com/vendor/";
integer g_nReady;

// added for a regular resubmiting of the data to the http db
float g_fTimerDuration=14400.0;

// var to make sure the qwner gets not noticed on inbetween updates
integer g_nQuietMode=TRUE;

// Debug output
Debug(string s)
{
    if (g_nDebugging) llOwnerSay(s);
}

UpdateTexture()
{
    integer nNeededPerm = (PERM_MODIFY | PERM_COPY | PERM_TRANSFER);
    string url = g_szBaseURL;

    string szTextureName = llGetInventoryName(INVENTORY_TEXTURE,g_nItemcounter);
    string szTextureKey=""; // we use a string here, as we want to submit an empty sttring if not texture was found.
    
    if ((llGetInventoryPermMask(szTextureName, MASK_NEXT) & nNeededPerm)==nNeededPerm)
    {
        szTextureKey=llGetInventoryKey(szTextureName);
        url += "updatetexture?";
        url += "object=" + llEscapeURL(szTextureName);
        url += "&texture=" + llEscapeURL(szTextureKey);
        Debug(url);
        g_keyHTTPRequest = llHTTPRequest(url, [HTTP_METHOD, "POST",HTTP_MIMETYPE,"text/plain;charset=utf-8"], "");     
    }
    else
    {
        if (!g_nQuietMode)
        {
            llOwnerSay("The texture '"+szTextureName+"' needs to be full permission to be distributed automatically.");
        }
    }
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
        g_nQuietMode=FALSE;
        llOwnerSay("Submitting textures...");
        if(llGetInventoryNumber(INVENTORY_TEXTURE)>0)
        {
            UpdateTexture();       
        }
        else
        {
            llOwnerSay("No textures in the box, falling asleep!");
        }
    }
    
    http_response(key request_id, integer status, list metadata, string body)
    {
        if (request_id == g_keyHTTPRequest)
        {
            if (status==200)
            {
                // // is it an "positive" answer from the database?
                if ((body == "saved") || (nStartsWith(body,"Illegal item update")) )
                {
                    if (body!="saved")
                        // something went wrong with storing the data, inform the user, but continue
                    {
                        llOwnerSay(body+"\nPlease contact an OC Administrator!");
                        g_nReady = FALSE;
                        llSetTimerEvent(0);
                    }
                    else
                    {
                        // next item
                        g_nItemcounter++;
                        if (g_nItemcounter < llGetInventoryNumber(INVENTORY_TEXTURE))
                        {
                            // Update items, as long as there are some
                            UpdateTexture();
                        }
                        else
                        {
                            // last item has been submitted
                            if (!g_nQuietMode) llOwnerSay("Done");
                            // Make sure the dtatabase gets cleaned, wil be as well handled by a cron job
                            llSetTimerEvent(g_fTimerDuration);
                            g_nReady = TRUE;
                        }
                    }
                }
            }
            else
            {
                llOwnerSay("HTTP error "+(string)status+"\n\nBody:\n"+body+"\n\nPlease contact an OC Database Administrator!");
                g_nReady = FALSE;
                llSetTimerEvent(0);
            }

     
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
    
    timer()
    {
        // if its time to resumbit, reset the item counter and init the data transfer
        g_nItemcounter=0;
        g_nQuietMode=TRUE;
        UpdateTexture();
    }
}
