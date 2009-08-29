//Licensed under the GPLv2, with the additional requirement that these scripts remain "full perms" in Second Life.  See "OpenCollar License" for details.

key owner;
// string ownername;  //NEVER used

string parentmenu = "Main";

string requesttype; //may be "owner" or "secowner" or "rem secowner"
key httpid;

integer listenchannel = 802930;//just something i randomly chose
integer listener;

integer locked = FALSE;

string LOCK = "*Lock*";
string UNLOCK = "*Unlock*";

//MESSAGE MAP
integer COMMAND_NOAUTH = 0;
integer COMMAND_OWNER = 500;
integer COMMAND_SECOWNER = 501;
integer COMMAND_GROUP = 502;
integer COMMAND_WEARER = 503;
integer COMMAND_EVERYONE = 504;
//integer CHAT = 505;//deprecated
integer COMMAND_OBJECT = 506;
integer COMMAND_RLV_RELAY = 507;
integer COMMAND_SAFEWORD = 510;  // new for safeword

//integer SEND_IM = 1000; deprecated.  each script should send its own IMs now.  This is to reduce even the tiny bt of lag caused by having IM slave scripts
integer POPUP_HELP = 1001;

integer HTTPDB_SAVE = 2000;//scripts send messages on this channel to have settings saved to httpdb
                            //str must be in form of "token=value"
integer HTTPDB_REQUEST = 2001;//when startup, scripts send requests for settings on this channel
integer HTTPDB_RESPONSE = 2002;//the httpdb script will send responses on this channel
integer HTTPDB_DELETE = 2003;//delete token from DB
integer HTTPDB_EMPTY = 2004;//sent by httpdb script when a token has no value in the db

integer LOCALSETTING_SAVE = 2500;
integer LOCALSETTING_REQUEST = 2501;
integer LOCALSETTING_RESPONSE = 2502;
integer LOCALSETTING_DELETE = 2503;
integer LOCALSETTING_EMPTY = 2504;

integer MENUNAME_REQUEST = 3000;
integer MENUNAME_RESPONSE = 3001;
integer SUBMENU = 3002;
integer MENUNAME_REMOVE = 3003;

integer RLV_CMD = 6000;
integer RLV_REFRESH = 6001;//RLV plugins should reinstate their restrictions upon receiving this message.
integer RLV_CLEAR = 6002;//RLV plugins should clear their restriction lists upon receiving this message.

integer remenu=FALSE;

key wearer;

Notify(key id, string msg, integer alsoNotifyWearer) 
{
    if (id == wearer) 
    {
        llOwnerSay(msg);
    } 
    else 
    {
        llInstantMessage(id,msg);
        if (alsoNotifyWearer) 
        {
            llOwnerSay(msg);
        }
    }    
}

Lock()
{
    locked = TRUE;
    llMessageLinked(LINK_SET, LOCALSETTING_SAVE, "locked=1", NULL_KEY);   
    llMessageLinked(LINK_THIS, RLV_CMD, "detach=n", NULL_KEY);                
    llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + UNLOCK, NULL_KEY);                
    llPlaySound("abdb1eaa-6160-b056-96d8-94f548a14dda", 1.0);
    llMessageLinked(LINK_THIS, MENUNAME_REMOVE, parentmenu + "|" + LOCK, NULL_KEY);
}

Unlock()
{
    locked = FALSE;
    llMessageLinked(LINK_SET, LOCALSETTING_DELETE, "locked", NULL_KEY); 
    llMessageLinked(LINK_THIS, RLV_CMD, "detach=y", NULL_KEY);    
    llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + LOCK, NULL_KEY);                  
    llPlaySound("ee94315e-f69b-c753-629c-97bd865b7094", 1.0);
    llMessageLinked(LINK_THIS, MENUNAME_REMOVE, parentmenu + "|" + UNLOCK, NULL_KEY);   
}



default
{
    state_entry()
    {   //until set otherwise, wearer is owner
        owner = llGetOwner();
        wearer = owner;
//        ownername = llKey2Name(llGetOwner());   //NEVER used
        listenchannel = -1 - llRound(llFrand(9999999.0));
        /* //no more needed
        llSleep(1.0);//giving time for others to reset before populating menu      
        llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + LOCK, NULL_KEY);
        */    
    }

    link_message(integer sender, integer num, string str, key id)
    {
        if (str == "settings" && num >= COMMAND_OWNER && num <=COMMAND_WEARER)
        {
            if (locked) Notify(id, "Locked.", FALSE);                   
            else Notify(id, "Unlocked.", FALSE);                                    
        }                                                      
        else if ((str == "lock" || str == "unlock") && num >= COMMAND_OWNER && num <=COMMAND_WEARER)
        {   //owners and secowners can lock and unlock. no one else
            if (str == "lock"){
                if (num == COMMAND_OWNER || id == wearer )
                {
                    Lock();
        //            owner = id; //need to store the one who locked (who has to be also owner) here
                    Notify(id, "Locked.", FALSE);                    
                    if (id!=wearer) llOwnerSay("Your collar has been locked.");  
                    if (remenu) {remenu=FALSE; llMessageLinked(LINK_THIS, SUBMENU, parentmenu, id);}
                }
                else 
                {
                    Notify(id, "Sorry, only owners or wearer can lock the collar.", FALSE);
                }
            }
            else if (str == "unlock") {
                   if (num == COMMAND_OWNER)
                   {
                    Unlock();                             
                    Notify(id, "Unlocked.", FALSE);                              
                    if (id!=wearer) llOwnerSay("Your collar has been unlocked.");  
                    if (remenu) {remenu=FALSE; llMessageLinked(LINK_THIS, SUBMENU, parentmenu, id);}
                }
                   else
                {
                    Notify(id, "Sorry, only owners can unlock the collar.", FALSE);
                }                          
            }
        }

        else if (num == LOCALSETTING_RESPONSE)
        {
            list params = llParseString2List(str, ["="], []);
            string token = llList2String(params, 0);
            string value = llList2String(params, 1);
            if (token == "locked")
            {
                locked = (integer)value;
                if (locked)
                {
                    llMessageLinked(LINK_THIS, RLV_CMD, "detach=n", NULL_KEY);
                    llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + UNLOCK, NULL_KEY);                
                    llMessageLinked(LINK_THIS, MENUNAME_REMOVE, parentmenu + "|" + LOCK, NULL_KEY);  
                }
                else
                {
                    llMessageLinked(LINK_THIS, RLV_CMD, "detach=y", NULL_KEY); 
                    llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + LOCK, NULL_KEY);                
                    llMessageLinked(LINK_THIS, MENUNAME_REMOVE, parentmenu + "|" + UNLOCK, NULL_KEY);                     
                }
            }
            else if (token == "owner")
            {
                // now get the owner value from the database - as wearers can lock collar
                owner = value;
            }

        }
        else if (num == MENUNAME_REQUEST && str == parentmenu)
        {
            if (locked)
            {
                llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + UNLOCK, NULL_KEY);
            }
            else
            {
                llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + LOCK, NULL_KEY);                            
            }
        }
        else if (num == SUBMENU)
        {
            if (str == LOCK) 
            {
                remenu=TRUE;
                llMessageLinked(LINK_THIS, COMMAND_NOAUTH, "lock", id);
            }
            else if (str == UNLOCK) 
            {
                remenu=TRUE;
                llMessageLinked(LINK_THIS, COMMAND_NOAUTH, "unlock", id);
            }
        }        
        
        else if (num == RLV_REFRESH)
        {
            if (locked)
            {
                llMessageLinked(LINK_THIS, RLV_CMD, "detach=n", NULL_KEY);
            }
            else
            {
                llMessageLinked(LINK_THIS, RLV_CMD, "detach=y", NULL_KEY);
            }
        }
        else if (num == RLV_CLEAR)
        {
            Unlock();
        }
                
    }
    attach(key id)
    {
        if (locked && id == NULL_KEY)
        {
            Notify(owner, llKey2Name(wearer) + " has detached me while locked!", FALSE);
        }
    }

    changed(integer change)
    {
        if (change & CHANGED_OWNER)
        {
            llResetScript();
        }
    }
}
