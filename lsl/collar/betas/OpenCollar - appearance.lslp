//handle appearance menu
//handle saving position on detach, and restoring it on httpdb_response

string submenu = "Appearance";
string parentmenu = "Main";
integer menuchannel = 3907345;//we'll randomize this later
integer poschannel = 872634;//used for the position adjust menu
integer rotchannel = 872633;//used for the position adjust menu
integer listener;
integer timeout = 60;
list localbuttons = ["Position", "Rotation"];
list buttons;
float smallnudge=0.0005;
float mediumnudge=0.005;
float largenudge=0.05;
float nudge=mediumnudge;
float rotnudge;

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
integer CPLANIM_PERMREQUEST = 7002;//id should be av's key, str should be cmd name "hug", "kiss", etc
integer CPLANIM_PERMRESPONSE = 7003;//str should be "1" for got perms or "0" for not.  id should be av's key
integer CPLANIM_START = 7004;//str should be valid anim name.  id should be av
integer CPLANIM_STOP = 7005;//str should be valid anim name.  id should be av

//string UPMENU = "↑";//when your menu hears this, give the parent menu
string UPMENU = "^";

key wearer;
integer remenu;

Notify(key id, string msg, integer alsoNotifyWearer) {
    if (id == wearer) {
        llOwnerSay(msg);
    } else {
        llInstantMessage(id,msg);
        if (alsoNotifyWearer) {
            llOwnerSay(msg);
        }
    }    
}

debug(string str)
{
    //llOwnerSay(llGetScriptName() + ": " + str);
}

ForceUpdate()
{
    //workaround for https://jira.secondlife.com/browse/VWR-1168
    llSetText(".", <1,1,1>, 1.0);
    llSetText("", <1,1,1>, 1.0);
}

AdjustPos(vector delta)
{
    if (llGetAttached())
    {
        llSetPos(llGetLocalPos() + delta);
        ForceUpdate();
    }
}

AdjustRot(vector delta)
{
    if (llGetAttached())
    {
        llSetLocalRot(llGetLocalRot() * llEuler2Rot(delta));
        ForceUpdate();
    }
}

RotMenu(key id)
{
    string prompt = "Adjust the collar rotation.";
    prompt += "  (Menu will time out in " + (string)timeout + " seconds.)";    
    list mybuttons = ["tilt up", "right", "tilt left", "tilt down", "left", "tilt right"];// ria change
    mybuttons += [UPMENU];
    mybuttons = RestackMenu(mybuttons);//re-order buttons to start at the top left of the dialog instead of bottom left
    llSetTimerEvent(timeout);
    rotchannel = - llRound(llFrand(999999)) - 9999;
    llListenRemove(listener);    
    listener = llListen(rotchannel, "", id, "");
    llDialog(id, prompt, mybuttons, rotchannel);    
}

PosMenu(key id)
{
    string prompt = "Adjust the collar position:\nChoose the size of the nudge (S/M/L), and move the collar in one of the three directions (X/Y/Z).\nCurrent nudge size is: ";
    list mybuttons = ["left", "up", "forward", "right", "down", "backward"];// ria change
    if (nudge!=smallnudge) mybuttons+=["Nudge: S"];
    else prompt += "Small.";
    if (nudge!=mediumnudge) mybuttons+=["Nudge: M"];
    else prompt += "Medium.";
    if (nudge!=largenudge) mybuttons+=["Nudge: L"];
    else prompt += "Large.";
    prompt += "\n\n  (Menu will time out in " + (string)timeout + " seconds.)";    
    mybuttons += [UPMENU];
    mybuttons = RestackMenu(mybuttons);//re-order buttons to start at the top left of the dialog instead of bottom left
    llSetTimerEvent(timeout);
    poschannel = - llRound(llFrand(999999)) - 9999;
    llListenRemove(listener);    
    listener = llListen(poschannel, "", id, "");
    llDialog(id, prompt, mybuttons, poschannel);    
}

DoMenu(key id)
{
    string prompt = "Which aspect of the appearance would you like to modify?.\n";
    prompt += "(Menu will time out in " + (string)timeout + " seconds.)";
    list mybuttons = llListSort(localbuttons + buttons, 1, TRUE);
    
    //fill in your button list here
    
    
    mybuttons += [UPMENU];//make sure there's a button to return to the parent menu
    mybuttons = RestackMenu(mybuttons);//re-order buttons to start at the top left of the dialog instead of bottom left
    llSetTimerEvent(timeout);
    menuchannel = - llRound(llFrand(999999)) - 9999;
    llListenRemove(listener);
    listener = llListen(menuchannel, "", id, "");
    llDialog(id, prompt, mybuttons, menuchannel);
}

list RestackMenu(list in)
{ //adds empty buttons until the list length is multiple of 3, to max of 12
    while (llGetListLength(in) % 3 != 0 && llGetListLength(in) < 12)
    {
        in += [" "];
    }
    //look for ^ and > in the menu
    integer u = llListFindList(in, [UPMENU]);
    if (u != -1)
    {
        in = llDeleteSubList(in, u, u);
    }
    //re-orders a list so dialog buttons start in the top row
    list out = llList2List(in, 9, 11);
    out += llList2List(in, 6, 8);
    out += llList2List(in, 3, 5);    
    out += llList2List(in, 0, 2);
    //make sure we move ^ and > to position 1 and 2
    if (u != -1)
    {
        out = llListInsertList(out, [UPMENU], 1);
    }
    return out;
}

string GetDBPrefix()
{//get db prefix from list in object desc
    return llList2String(llParseString2List(llGetObjectDesc(), ["~"], []), 2);
}

default
{
    state_entry()
    {
        wearer = llGetOwner();       
        rotnudge = PI / 32.0;//have to do this here since we can't divide in a global var declaration
         /* // no more needed i hope
        llSleep(1.0);
        llMessageLinked(LINK_THIS, MENUNAME_REQUEST, submenu, NULL_KEY);
        llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + submenu, NULL_KEY); 
        */       
    }
    
    on_rez(integer param)
    {
        llResetScript();
    }

    link_message(integer sender, integer num, string str, key id)
    {
        if (num == SUBMENU && str == submenu)
        {
            //someone asked for our menu
            //give this plugin's menu to id
            remenu = TRUE;
            llMessageLinked(LINK_THIS, COMMAND_NOAUTH, "appearance",id);
        }
        else if (num == MENUNAME_REQUEST && str == parentmenu)
        {
            
            llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + submenu, NULL_KEY);
        }
        else if (num == MENUNAME_RESPONSE)
        {
            list parts = llParseString2List(str, ["|"], []);
            if (llList2String(parts, 0) == submenu)
            {//someone wants to stick something in our menu
                string button = llList2String(parts, 1);
                if (llListFindList(buttons, [button]) == -1)
                {
                    buttons = llListSort(buttons + [button], 1, TRUE);
                }
            }
        }
        else if (num >= COMMAND_OWNER && num <= COMMAND_WEARER)
        {
            if (str == "refreshmenu")
            {
                buttons = [];
                llMessageLinked(LINK_SET, MENUNAME_REQUEST, submenu, NULL_KEY);
            }
            else if (str == "appearance")
            {
                if (id!=wearer && num!=COMMAND_OWNER)
                {
                    Notify(id,"You are not allowed to change the collar appearance.", FALSE);
                    if (remenu) llMessageLinked(LINK_THIS, SUBMENU, parentmenu, id);
                }
                else DoMenu(id);
                remenu=FALSE;
            }
            else if (str == "rotation")
            {
                if (id!=wearer && num!=COMMAND_OWNER)
                {
                    Notify(id,"You are not allowed to change the collar rotation.", FALSE);
                }
                else RotMenu(id);
             }
            else if (str == "position")
            {
                if (id!=wearer && num!=COMMAND_OWNER)
                {
                    Notify(id,"You are not allowed to change the collar position.", FALSE);
                }
                else PosMenu(id);
            }
        }
    } 
    
    listen(integer channel, string name, key id, string message)
    {
        llListenRemove(listener);
        llSetTimerEvent(0.0);
        if (channel == menuchannel)
        {
            if (message == UPMENU)
            {
                //give id the parent menu
                llMessageLinked(LINK_THIS, SUBMENU, parentmenu, id);
            }
            else if (~llListFindList(localbuttons, [message]))
            {
                //we got a response for something we handle locally
                if (message == "Position")
                {
                    PosMenu(id);
                }
                else if (message == "Rotation")
                {
                    RotMenu(id);
                }
            }
            else if (~llListFindList(buttons, [message]))
            {
                //we got a submenu selection
                llMessageLinked(LINK_THIS, SUBMENU, message, id);
            }            
        }
        else if (channel == poschannel)
        {
            if (message == UPMENU)
            {
                DoMenu(id);
                return;
            }
            else if (llGetAttached())
            {
                if (message == "left")
                {
                    AdjustPos(<nudge, 0, 0>);
                }
                else if (message == "up")
                {
                    AdjustPos(<0, nudge, 0>);                
                }
                else if (message == "forward")
                {
                    AdjustPos(<0, 0, nudge>);                
                }            
                else if (message == "right")
                {
                    AdjustPos(<-nudge, 0, 0>);                
                }            
                else if (message == "down")
                {
                    AdjustPos(<0, -nudge, 0>);                    
                }            
                else if (message == "backward")
                {
                    AdjustPos(<0, 0, -nudge>);                
                }                            
                else if (message == "Nudge: S")
                {
                    nudge=smallnudge;
                }
                else if (message == "Nudge: M")
                {
                    nudge=mediumnudge;                
                }
                else if (message == "Nudge: L")
                {
                    nudge=largenudge;                
                }
            }
            else
            {
                Notify(id, "Sorry, position can only be adjusted while worn",FALSE);
            }
            PosMenu(id);
        }
        else if (channel == rotchannel)
        {
            if (message == UPMENU)
            {
                DoMenu(id);
                return;
            }
            else if (llGetAttached())
            {
                if (message == "tilt up")
                {
                    AdjustRot(<rotnudge, 0, 0>);
                }
                else if (message == "right")
                {
                    AdjustRot(<0, rotnudge, 0>);                
                }
                else if (message == "tilt left")
                {
                    AdjustRot(<0, 0, rotnudge>);                
                }            
                else if (message == "tilt down")
                {
                    AdjustRot(<-rotnudge, 0, 0>);                
                }            
                else if (message == "left")
                {
                    AdjustRot(<0, -rotnudge, 0>);                    
                }            
                else if (message == "tilt right")
                {
                    AdjustRot(<0, 0, -rotnudge>);                
                }                        
            }
            else
            {
                Notify(id, "Sorry, position can only be adjusted while worn", FALSE);
            }
            RotMenu(id);            
        }
    }
    
    timer()
    {
        llListenRemove(listener);
        llSetTimerEvent(0.0);
    }
}

