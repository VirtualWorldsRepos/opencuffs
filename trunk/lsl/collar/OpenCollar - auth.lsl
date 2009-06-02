//auth

//save owner, secowners, and group key
//check credentials when messages come in on COMMAND_NOAUTH, send out message on appropriate channel
//reset self on owner change

key owner;
string ownername;
key group = NULL_KEY;
string groupname;
integer groupenabled = FALSE;
list secowners;//strided list in the form key,name
string tmpname; //used temporarily to store new owner or secowner name while retrieving key

string parentmenu = "Main";
string submenu = "Owners";

string requesttype; //may be "owner" or "secowner"
key httpid;

integer listenchannel = 802930;//just something i randomly chose
integer listener;
integer timeout = 30;

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

//integer SEND_IM = 1000; deprecated.  each script should send its own IMs now.  This is to reduce even the tiny bt of lag caused by having IM slave scripts
integer POPUP_HELP = 1001;

integer HTTPDB_SAVE = 2000;//scripts send messages on this channel to have settings saved to httpdb
                            //str must be in form of "token=value"
integer HTTPDB_REQUEST = 2001;//when startup, scripts send requests for settings on this channel
integer HTTPDB_RESPONSE = 2002;//the httpdb script will send responses on this channel
integer HTTPDB_DELETE = 2003;//delete token from DB
integer HTTPDB_EMPTY = 2004;//sent by httpdb script when a token has no value in the db

integer MENUNAME_REQUEST = 3000;
integer MENUNAME_RESPONSE = 3001;
integer SUBMENU = 3002;
integer MENUNAME_REMOVE = 3003;

integer RLV_CMD = 6000;
integer RLV_REFRESH = 6001;//RLV plugins should reinstate their restrictions upon receiving this message.
integer RLV_CLEAR = 6002;//RLV plugins should clear their restriction lists upon receiving this message.

integer ANIM_START = 7000;//send this with the name of an anim in the string part of the message to play the anim
integer ANIM_STOP = 7001;//send this with the name of an anim in the string part of the message to stop the anim

string UPMENU = "~PrevMenu~";


string setowner = "Set Owner";
string setsecowner = "Add Secowner";
string setgroup = "Set Group";
string reset = "Reset All";
string remsecowner = "Rem Secowner";
string unsetgroup = "Unset Group";
string listowners = "List Owners";

debug(string str)
{
    //llOwnerSay(llGetScriptName() + ": " + str);
}

integer SecOwnerExists(string name)
{
    
    return (~llSubStringIndex(llToLower(llDumpList2String(secowners, ",")), llToLower(name)));
}

Popup(key id, string message)
{
    //one-way popup message.  don't listen for these anywhere
    llDialog(id, message, [], 298479);
}

Name2Key(string formattedname)
{
    //formatted name is firstname+lastname
    httpid = llHTTPRequest("http://w-hat.com/name2key?terse=1&name=" + formattedname, [HTTP_METHOD, "GET"], "");
}

GetGroupName(key groupkey)
{
    httpid = llHTTPRequest("http://groupname.scriptacademy.org/" + (string)groupkey, [HTTP_METHOD, "GET"], "");
}

SendIM(key dest, string message)
{
    llInstantMessage(dest, message);
}

AuthMenu(key av)
{
    string prompt = "Pick an option.";
    prompt += "  (Menu will time out in " + (string)timeout + " seconds.)\n";    
    list buttons;
    //add owner
    buttons += [setowner];    
    //add secowner
    buttons += [setsecowner];    
    //set group
    buttons += [setgroup];      
    //reset
    buttons += [reset];     
    
    
    //rem secowner    
    buttons += [remsecowner];    
  
    //unset group
    buttons += [unsetgroup];    
    //list owners
    buttons += [listowners];   
    
    //parent menu
    buttons += [UPMENU];
    llListenRemove(listener);
    listener = llListen(listenchannel, "", av, "");
    buttons = RestackMenu(FillMenu(buttons));
    llDialog(av, prompt, buttons, listenchannel);    
    llSetTimerEvent((float)timeout);    
}

list FillMenu(list in)
{
    //adds empty buttons until the list length is multiple of 3, to max of 12
    while (llGetListLength(in) != 3 && llGetListLength(in) != 6 && llGetListLength(in) != 9 && llGetListLength(in) < 12)
    {
        in += [" "];
    }
    return in;
}

list RestackMenu(list in)
{
    //re-orders a list so dialog buttons start in the top row
    list out = llList2List(in, 9, 11);
    out += llList2List(in, 6, 8);
    out += llList2List(in, 3, 5);    
    out += llList2List(in, 0, 2);    
    return out;
}

integer UserAuth(string id)
{
    integer auth;
    if (id == owner)
    {
        auth = COMMAND_OWNER;
    }
    else if (~llListFindList(secowners, [(string)id]))
    {
        auth = COMMAND_SECOWNER;
    }
    else if (llSameGroup(id) && groupenabled && id != llGetOwner())
    {
        auth = COMMAND_GROUP;
    }            
    else if (id == llGetOwner())
    {
        auth = COMMAND_WEARER;
    }
    else
    {
        auth = COMMAND_EVERYONE;
    }
    return auth;
}

integer ObjectAuth(key obj, key objownerkey)
{
    integer auth;
    if (objownerkey == owner)
    {
        auth = COMMAND_OWNER;
    }
    else if (~llListFindList(secowners, [(string)objownerkey]))
    {
        auth = COMMAND_SECOWNER;          
    }
    else if ((key)llList2String(llGetObjectDetails(obj, [OBJECT_GROUP]), 0) == group && objownerkey != llGetOwner() && group != NULL_KEY)
    {
        //meaning that the command came from an object set to our control group, and is not owned by the wearer
        auth = COMMAND_GROUP;
    }             
    else if (objownerkey == llGetOwner())
    {
        auth = COMMAND_WEARER;
    }
    else
    {
        auth = COMMAND_EVERYONE;
    }            
    return auth; 
}

Lock()
{
    locked = TRUE;
    llMessageLinked(LINK_THIS, HTTPDB_SAVE, "locked=1", NULL_KEY);   
    llMessageLinked(LINK_THIS, RLV_CMD, "detach=n", NULL_KEY);                
    llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + UNLOCK, NULL_KEY);                
    llMessageLinked(LINK_THIS, MENUNAME_REMOVE, parentmenu + "|" + LOCK, NULL_KEY);                
}

Unlock()
{
    locked = FALSE;
    llMessageLinked(LINK_THIS, HTTPDB_DELETE, "locked", NULL_KEY); 
    llMessageLinked(LINK_THIS, RLV_CMD, "detach=y", NULL_KEY);    
    llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + LOCK, NULL_KEY);                
    llMessageLinked(LINK_THIS, MENUNAME_REMOVE, parentmenu + "|" + UNLOCK, NULL_KEY);   
}

SendOwnerSettings(key id)
{
    llInstantMessage(id, "Owner: " + ownername + " (" + (string)owner + ")");
    
    //Do Secowners list            
    
    integer n;
    integer length = llGetListLength(secowners);
    string sostring;
    for (n = 0; n < length; n = n + 2)
    {
        sostring += "\n" + llList2String(secowners, n + 1) + " (" + llList2String(secowners, n) + ")";
    }
                
    llInstantMessage(id, "Secowners: " + sostring);                        
    llInstantMessage(id, "Group: " + groupname);            
    llInstantMessage(id, "Group Key: " + (string)group);     
}

integer RemSecOwner(string name)
{
    debug("removing: " + name);    
    //all our comparisons will be cast to lower case first
    name = llToLower(name);
    integer found = FALSE;
    integer n;
    //loop from the top and work down, so we don't skip when we remove things
    for (n = llGetListLength(secowners) - 1; n >= 0; n = n - 2)
    {
        string thisname = llToLower(llList2String(secowners, n));
        debug("checking " + thisname);        
        if (name == thisname)
        {
            //remove name and key
            secowners = llDeleteSubList(secowners, n - 1, n);
            //set found to true
            found = TRUE;
        }
    }
    //return TRUE if name found, else FALSE
    if (found)
    {
        llMessageLinked(LINK_THIS, HTTPDB_SAVE, "secowners=" + llDumpList2String(secowners, ","), NULL_KEY);                            
    }
    
    return found;
}

default
{
    state_entry()
    {
        //until set otherwise, wearer is owner
        owner = llGetOwner();
        ownername = llKey2Name(llGetOwner());
       
        llSleep(1.0);//giving time for others to reset before populating menu        
        llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + submenu, NULL_KEY);                     
        llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + LOCK, NULL_KEY);    
    }
    
    
    link_message(integer sender, integer num, string str, key id)
    {
        //authenticate messages on COMMAND_NOAUTH
        if (num == COMMAND_NOAUTH)
        {
            integer auth = UserAuth((string)id);
            llMessageLinked(LINK_SET, auth, str, id);              
            debug("noauth: " + str + " from " + (string)id + " who has auth " + (string)auth);            
        }
        else if (num == COMMAND_OBJECT)
        {
            //on object sent a command, see if that object's owner is an owner or secowner in the collar
            //or if the object is set to the same group, and group is enabled in the collar
            //or if object is owned by wearer
            key objownerkey = llGetOwnerKey(id);   
            integer auth = ObjectAuth(id, objownerkey);
            llMessageLinked(LINK_SET, auth, str, id);              
            debug("noauth: " + str + " from object " + (string)id + " who has auth " + (string)auth);             
        }
        else if ((str == "lock" || str == "unlock") && num >= COMMAND_OWNER && num <=COMMAND_WEARER)
        {
            //owners and secowners can lock and unlock. no one else
            if (num == COMMAND_OWNER || num == COMMAND_SECOWNER)
            {
                if (str == "lock")
                {
                    Lock();
                    llInstantMessage(id, "Locked.");                    
                }
                else if (str == "unlock")
                {
                    Unlock();                             
                    llInstantMessage(id, "Unlocked.");                              
                }                   
            }     
            else
            {
                llInstantMessage(id, "Sorry, only owners and secowners can lock and unlock the collar.");
            }    
        }
        else if ((str == "settings" || str == "listowners") && num >= COMMAND_OWNER && num <=COMMAND_WEARER)
        {
            //say owner, secowners, group
            SendOwnerSettings(id);    
            
            //send lock setting, but not if the cmd was "listowners"
            if (str == "settings")
            {
                if (locked)
                {
                    llInstantMessage(id, "Locked.");                    
                }
                else
                {
                    llInstantMessage(id, "Unlocked.");                                        
                }
            }                                                                
        }     
        else if (num == COMMAND_OWNER)
        {
        //respond to messages to set or unset owner, group, or secowners.  only owner may do these things            

            list params = llParseString2List(str, [" "], []);
            string command = llList2String(params, 0);
            if (command == "owner")
            {
                //set a new owner.  use w-hat name2key service.  benefits: not case sensitive, and owner need not be present
                requesttype = "owner";
                
                //pop the command off the param list, leaving only first and last name
                params = llDeleteSubList(params, 0, 0);
                
                //record owner name
                tmpname = llDumpList2String(params, " ");
                        
                //get owner key
                Name2Key(llDumpList2String(params, "+"));
            }
            else if (command == "secowner")
            {
                //set a new secowner
                requesttype = "secowner";
                
                //pop the command off the param list, leaving only first and last name
                params = llDeleteSubList(params, 0, 0);
                
                //record owner name
                tmpname = llDumpList2String(params, " ");
                
                if (SecOwnerExists(tmpname))
                {
                    //error
                    llInstantMessage(id, "Error: " + tmpname + " is already in the secowner list.");
                }
                else
                {
                    //get owner key
                    Name2Key(llDumpList2String(params, "+"));                       
                }             
            }
            else if (command == "remsecowner")//i don't like this command.  see what amethyst uses
            {
                //remove secowner, if in the list
                requesttype = "remsecowner";
                
                //pop the command off the param list, leaving only first and last name
                params = llDeleteSubList(params, 0, 0);
                
                //name of person concerned
                tmpname = llDumpList2String(params, " ");
                
                if (RemSecOwner(tmpname))
                {
                    string notification = tmpname + " removed from secondary owner list.";
                    //notify sub too if not same person
                    if (id != llGetOwner())
                    {   //use a popup so that it doesn't have a delay
                        Popup(llGetOwner(), notification);
                    }                    
                    llInstantMessage(id, notification);                    
                }
                else
                {
                    llInstantMessage(id, "Error: '" + tmpname + "' not in secondary owner list.");                    
                }                                                          
            }
            else if (command == "setgroup")
            {
                requesttype = "group";
                //record current group key
                group = (key)llList2String(llGetObjectDetails(llGetKey(), [OBJECT_GROUP]), 0);
                llMessageLinked(LINK_THIS, HTTPDB_SAVE, "group=" + (string)group, NULL_KEY);                                
                groupenabled = TRUE;
                GetGroupName(group);
                
            }
            else if (command == "unsetgroup")
            {
                group = NULL_KEY;
                groupname = "";
                llMessageLinked(LINK_THIS, HTTPDB_DELETE, "group", NULL_KEY);                                
                llMessageLinked(LINK_THIS, HTTPDB_DELETE, "groupname", NULL_KEY);                
                groupenabled = FALSE;
                llInstantMessage(id, "Group unset.");
                
            }
            else if (command == "reset")
            {
                //tell owner and wearer about reset
                llInstantMessage(owner, "Resetting...");
                //remove owner from httpdb
                //UnsetOwnerDB();//deprecated.  httpdb script now clears ALL values on reset command
                
                //reset script, forgetting owner, group, secowners
                llResetScript();      
            }
        }
        else if (num == COMMAND_WEARER)
        {
            list params = llParseString2List(str, [" "], []);
            string command = llList2String(params, 0);            
            if (command == "runaway" || command == "reset")
            {
                //IM Owner
                llInstantMessage(owner, llKey2Name(llGetOwner()) + " has run away!");                
                llInstantMessage(llGetOwner(), "Running away from " + ownername);                
                //reset, forgetting owner, group, secowners
                //remove owner from httpdb
                //UnsetOwnerDB();//deprecated.  httpdb script now clears ALL values on reset command
                                        
                llResetScript();
            }
        }
        else if (num == HTTPDB_RESPONSE)
        {
            list params = llParseString2List(str, ["="], []);
            string token = llList2String(params, 0);
            string value = llList2String(params, 1);
            if (token == "owner")
            {
                list tmp = llParseString2List(value, [","], []);
                owner = (key)llList2String(tmp, 0);                
                ownername = llList2String(tmp, 1);
                //llInstantMessage(llGetOwner(), "Loaded owner " + ownername + " from database.");
            }
            else if (token == "group")
            {
                group = (key)value;
                //llInstantMessage(llGetOwner(), "Loaded group key " + value + " from database.");                
            }
            else if (token == "groupname")
            {
                groupname = value;
                //llInstantMessage(llGetOwner(), "Loaded group " + value + " from database.");                 
            }            
            else if (token == "secowners")
            {
                secowners = llParseString2List(value, [","], [""]);
                string readablelist;
                integer n;
                integer length = llGetListLength(secowners);
                for (n = 0; n < length; n = n + 2)
                {
                    if (n == 0)
                    {
                        readablelist += llList2String(secowners, n + 1);
                    }
                    else
                    {
                        readablelist += ", " + llList2String(secowners, n + 1);                        
                    }
                }
                //llInstantMessage(llGetOwner(), "Loaded secowners " + readablelist + " from database.");                                 
            }
            else if (token == "locked")
            {
                locked = (integer)value;
                if (locked)
                {
                    llMessageLinked(LINK_THIS, RLV_CMD, "detach=n", NULL_KEY);
                }
                else
                {
                    llMessageLinked(LINK_THIS, RLV_CMD, "detach=y", NULL_KEY);                    
                }
                //llInstantMessage(llGetOwner(), "Loaded 'locked' setting from database.");                  
            }
        }
        else if (num == MENUNAME_REQUEST && str == parentmenu)
        {
            llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + submenu, NULL_KEY);
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
            if (str == submenu)
            {
                //give the Owner menu here.  should let the dialog do whatever the chat commands do
                AuthMenu(id);                
            }
            else if (str == LOCK)
            {
                if (UserAuth(id) >= COMMAND_GROUP)
                {
                    //say no
                    llInstantMessage(id, "Sorry, only owners and secowners can lock and unlock the collar.");
                    llMessageLinked(LINK_THIS, SUBMENU, parentmenu, id);                         
                }
                else
                {
                    Lock();
                    llInstantMessage(id, "Locked.");
                    //give menu back
                    llMessageLinked(LINK_THIS, SUBMENU, parentmenu, id);                      
                }                              
            }
            else if (str == UNLOCK)
            {
                if (UserAuth(id) >= COMMAND_GROUP)
                {
                    //say no
                    llInstantMessage(id, "Sorry, only owners and secowners can lock and unlock the collar.");
                    llMessageLinked(LINK_THIS, SUBMENU, parentmenu, id);                         
                }
                else
                {
                    Unlock();
                    llInstantMessage(id, "Unlocked.");
                    //give menu back
                    llMessageLinked(LINK_THIS, SUBMENU, parentmenu, id);                                      
                }
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
    
    listen(integer channel, string name, key id, string message)
    {
        if (message == UPMENU)
        {
            llMessageLinked(LINK_THIS, SUBMENU, parentmenu, id);
            return;
        }
        else if (message == setowner)
        {
            //for now, give a popup saying how to set owner in chat.
            //Later, possibly do sensor and give menu of nearby avs
            llMessageLinked(LINK_THIS, POPUP_HELP, "To set owner, say _PREFIX_owner and the owner name.  Example: _PREFIX_owner Nandana Singh", id);
        }
        else if (message == setsecowner)
        {
            //for now, give a popup saying how to set secowner in chat.
            //Later, possibly do sensor and give menu of nearby avs        
            llMessageLinked(LINK_THIS, POPUP_HELP, "To add a secowner, say _PREFIX_secowner and the name.  Example: _PREFIX_secowner Nandana Singh", id);                
        }
        else if (message == setgroup)
        {
            llMessageLinked(LINK_THIS, COMMAND_NOAUTH, "setgroup", id);
        }
        else if (message == reset)
        {
            llMessageLinked(LINK_THIS, COMMAND_NOAUTH, "reset", id);            
        }
        else if (message == remsecowner)
        {
            //for now, give a popup saying how to remove secowner in chat.
            //Later, possibly do sensor and give menu of nearby avs               
            llMessageLinked(LINK_THIS, POPUP_HELP, "To remove a secowner, say _PREFIX_remsecowner and the secowner name.  Example: _PREFIX_remsecowner Nandana Singh", id);            
        }
        else if (message == unsetgroup)
        {
            llMessageLinked(LINK_THIS, COMMAND_NOAUTH, "unsetgroup", id);            
        }
        else if (message == listowners)
        {
            llMessageLinked(LINK_THIS, COMMAND_NOAUTH, "listowners", id);            
        }
        AuthMenu(id);
    }
    
    on_rez(integer param)
    {
        //check to see if the group is set properly
        if (group != NULL_KEY)
        {
            if ((key)llList2String(llGetObjectDetails(llGetKey(), [OBJECT_GROUP]), 0) == group)
            {
                groupenabled = TRUE;
            }
            else
            {
                //Commenting this notice out because the leash holder object is the new preferred way of sending group commands, 
                //if (groupname == "X")
                //{
                //    Popup(llGetOwner(), "Warning: Group-specific commands are disabled because your current group is not the same as the one stored in the collar.  To re-enable group-specific commands, set the proper group on your av and re-attach the collar.");                    
                //}
                //else
                //{
                //    Popup(llGetOwner(), "Warning: Group-specific commands are disabled because you do not have the '" + groupname + "' group set.  To re-enable group-specific commands, set yourself to the '" + groupname + "' group and re-attach the collar.");                    
                //}
                groupenabled = FALSE;
            }
        }
        else
        {
            groupenabled = FALSE;
        }        
    }
    
    changed(integer change)
    {
        if (change & CHANGED_OWNER)
        {
            llResetScript();
        }
    }
    
    http_response(key id, integer status, list meta, string body)
    {
        if (id == httpid && status == 200)
        {
            //here's where we add owners or secowners, after getting their keys
            if (body == "00000000-0000-0000-0000-000000000000")
            {
                //owner name not in name2key database
                Popup(owner, "Error: unable to retrieve key for '" + tmpname + "'.");
            }
            else if (requesttype == "owner")
            {
                owner = (key)body;
                ownername = tmpname;
                
                //send wearer a message about the new ownership
                Popup(llGetOwner(), "You are now owned by " + ownername + ".");
                        
                //owner might be offline, so they won't necessarily get a popup.  Send an IM instead
                SendIM(owner, "You have been set as owner on " + llKey2Name(llGetOwner()) + "'s collar.");
                
                //save owner to httpdb in form key,name
                llMessageLinked(LINK_THIS, HTTPDB_SAVE, "owner=" + (string)owner + "," + ownername, NULL_KEY);
                
                //give help card
                //llGiveInventory(owner, "OpenCollar Help");
                llMessageLinked(LINK_THIS, COMMAND_OWNER, "help", owner);
            }
            else if (requesttype == "secowner")
            {
                //only add to list if this secowner not already there
                key secowner = (key)body;                
                integer index = llListFindList(secowners, [body]);
                if (index == -1)
                {
                    //secowner is not already in list.  add him/her
                    secowners += [body, tmpname];
                }
                else
                {
                    //secowner is already in list.  just replace the name
                    secowners = llListReplaceList(secowners, [tmpname], index + 1, index + 1);
                }
                
                if (secowner != llGetOwner())
                {
                    Popup(llGetOwner(), "Added secondary owner " + tmpname);
                }
                SendIM(secowner, "You have been added you as a secondary owner to " + llKey2Name(llGetOwner()) + "'s collar.");
                
                
                //give help card
                //llGiveInventory((key)body, "OpenCollar Help");    
                llMessageLinked(LINK_THIS, COMMAND_SECOWNER, "help", secowner);
                
                //save secowner list to database
                llMessageLinked(LINK_THIS, HTTPDB_SAVE, "secowners=" + llDumpList2String(secowners, ","), NULL_KEY);
            }
            else if (requesttype == "group")
            {
                groupname = body;
                llMessageLinked(LINK_THIS, HTTPDB_SAVE, "groupname=" + groupname, NULL_KEY);                
                if (groupname == "X")
                {
                    Popup(owner, "Group set to (group name hidden)");
                }
                else
                {
                    Popup(owner, "Group set to " + groupname);
                }
            }
        }
    }
    
    timer()
    {
        llSetTimerEvent(0);
        llListenRemove(listener);
    }
    
    attach(key id)
    {
        if (locked && id == NULL_KEY)
        {
            llInstantMessage(owner, llKey2Name(llGetOwner()) + " has detached me while locked!");
        }
    }
}