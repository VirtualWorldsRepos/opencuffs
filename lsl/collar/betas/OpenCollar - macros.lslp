// Template for creating a OpenCOllar Plugin - OpenCollar Version 3.0xx

//Licensed under the GPLv2, with the additional requirement that these scripts remain "full perms" in Second Life.  See "OpenCollar License" for details.
//Collar Cuff Menu

string submenu = "Plugin"; // Name of the submenu
string parentmenu = "Main"; // mname of the menu, where the menu plugs in
integer menuchannel = 3907345;//we'll randomize this later
integer listener; // for storing and removing the listener
integer timeout = 60; // length of tiimeout for the menus

key g_keyWearer; // key of the current wearer to reset only on owner changes


list localbuttons = ["Command 1","Command 2"]; // any local, not changing buttons which will be used in this plugin, leave emty or add buttons as you like

list buttons;

//OpenCollae MESSAGE MAP
// messages for authenticating users
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

// messages for storing and retrieving values from http db
integer HTTPDB_SAVE = 2000;//scripts send messages on this channel to have settings saved to httpdb
//str must be in form of "token=value"
integer HTTPDB_REQUEST = 2001;//when startup, scripts send requests for settings on this channel
integer HTTPDB_RESPONSE = 2002;//the httpdb script will send responses on this channel
integer HTTPDB_DELETE = 2003;//delete token from DB
integer HTTPDB_EMPTY = 2004;//sent by httpdb script when a token has no value in the db

// messages for creating OC menu structure
integer MENUNAME_REQUEST = 3000;
integer MENUNAME_RESPONSE = 3001;
integer SUBMENU = 3002;
integer MENUNAME_REMOVE = 3003;

// messages for RLV commands
integer RLV_CMD = 6000;
integer RLV_REFRESH = 6001;//RLV plugins should reinstate their restrictions upon receiving this message.
integer RLV_CLEAR = 6002;//RLV plugins should clear their restriction lists upon receiving this message.
integer RLV_VERSION = 6003; //RLV Plugins can recieve the used rl viewer version upon receiving this message..

// messages for poses and couple anims
integer ANIM_START = 7000;//send this with the name of an anim in the string part of the message to play the anim
integer ANIM_STOP = 7001;//send this with the name of an anim in the string part of the message to stop the anim
integer CPLANIM_PERMREQUEST = 7002;//id should be av's key, str should be cmd name "hug", "kiss", etc
integer CPLANIM_PERMRESPONSE = 7003;//str should be "1" for got perms or "0" for not.  id should be av's key
integer CPLANIM_START = 7004;//str should be valid anim name.  id should be av
integer CPLANIM_STOP = 7005;//str should be valid anim name.  id should be av


// menu option to go one step back in menustructure
//string UPMENU = "↑";
//string MORE = "→";
string UPMENU = "^";
string MORE = ">";

//===============================================================================
//= parameters   :    string    szMsg   message string received
//=
//= return        :    none
//=
//= description  :    output debug messages
//=
//===============================================================================


Debug(string szMsg)
{
    llOwnerSay(llGetScriptName() + ": " + szMsg);
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

/*
//===============================================================================
//= parameters   :    string    keyID   key of person requesting the menu
//=
//= return        :    none
//=
//= description  :    build menu and display to user
//=
//===============================================================================

DoMenu(key keyID)
{
    string prompt = "Pick an option.";
    list mybuttons = localbuttons + buttons;

    //fill in your button list and additional prompt here


    // now back to OC Standard
    prompt += "\n(Menu will time out in " + (string)timeout + " seconds.)";

    llListSort(localbuttons, 1, TRUE); // resort menu buttons alphabetical

    mybuttons += [UPMENU];//make sure there's a button to return to the parent menu
    mybuttons = RestackMenu(FillMenu(mybuttons));//re-order buttons to start at the top left of the dialog instead of bottom left

    // and dispay the menu
    llSetTimerEvent(timeout);
    menuchannel = - llRound(llFrand(999999)) - 99999;
    llListenRemove(listener);
    listener = llListen(menuchannel, "", keyID, "");
    llDialog(keyID, prompt, mybuttons, menuchannel);
}

//===============================================================================
//= parameters   :    list    lstIn   list of menu buttons
//=
//= return        :   list    updated list of menu buttons
//=
//= description  :    build user friendly menu
//=
//===============================================================================

list FillMenu(list lstIn)
{
    //adds empty buttons until the list length is multiple of 3, to max of 12
    while (llGetListLength(lstIn) != 3 && llGetListLength(lstIn) != 6 && llGetListLength(lstIn) != 9 && llGetListLength(lstIn) < 12)
    {
        lstIn += [" "];
    }
    return lstIn;
}

//===============================================================================
//= parameters   :    list    lstIn   list of menu buttons
//=
//= return        :   list    updated list of menu buttons
//=
//= description  :    resort menu button top to do
//=
//===============================================================================

list RestackMenu(list lstIn)
{
    //re-orders a list so dialog buttons start in the top row
    list out = llList2List(lstIn, 9, 11);
    out += llList2List(lstIn, 6, 8);
    out += llList2List(lstIn, 3, 5);
    out += llList2List(lstIn, 0, 2);
    return out;
}

//===============================================================================
//= parameters   :    none
//=
//= return        :   string     DB prefix from the description of the collar
//=
//= description  :    prefix from the description of the collar
//=
//===============================================================================

string GetDBPrefix()
{//get db prefix from list in object desc
    return llList2String(llParseString2List(llGetObjectDesc(), ["~"], []), 2);
}

*/


list ownermacronames=[];
list ownermacrocontents=[];
list wearermacronames=[];
list wearermacrocontents=[];
key curuser;
string curmacroname="";
string curmacrocontent;

playmacro(string macro, integer auth, key id)
{
    string content;
    integer index;
    if (auth==COMMAND_OWNER)
    {
        index=llListFindList(ownermacronames,[(string)macro]);
        if (index==-1) {llInstantMessage(id, macro+": undefined macro."); return;}
        else content=llList2String(ownermacrocontents,index);
    }
    if (auth==COMMAND_WEARER)
    {
        index=llListFindList(wearermacronames,[macro]);
        if (index==-1) {llInstantMessage(id, macro+": undefined macro."); return;}
        else content=llList2String(wearermacrocontents,index);
    }
    llInstantMessage(id,"Playing macro: "+macro);
    list actions=llParseString2List(content,["|"],[]);
    for (index=0;index<llGetListLength(actions);index++)
    {
        llMessageLinked(LINK_THIS, auth, llList2String(actions,index), id);
    }
}


recmacro(string macro, integer auth, key id, string content)
{
    integer index;
    if (auth==COMMAND_OWNER)
    {
        index=llListFindList(ownermacronames,[macro]);
        if (index==-1)
        {
            ownermacronames+=[macro];
            ownermacrocontents+=[content];
        }
        else
        {
            ownermacrocontents=llListReplaceList(ownermacrocontents,[content],index,index);
        }
    }
    else if (auth==COMMAND_WEARER)
    {
        index=llListFindList(wearermacronames,[macro]);
        if (index==-1)
        {
            wearermacronames+=[macro];
            wearermacrocontents+=[content];
        }
        else
        {
            wearermacrocontents=llListReplaceList(wearermacrocontents,[content],index,index);
        }
    }
    else return;
    llInstantMessage(id,"Macro "+macro+" has been saved. Say <prefix>$"+macro+" to play it.");
}




default
{
    state_entry()
    {
//        menuchannel = -1 - llFloor(llFrand(9999999.0)); //randomizing listening channel

        // sleep a sceond to allow all scripts to be initialized
//        llSleep(1.0);
        // send reequest to main menu and ask other menus if the wnt to register with us
//        llMessageLinked(LINK_THIS, MENUNAME_REQUEST, submenu, NULL_KEY);
//        llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + submenu, NULL_KEY);

    }

    // reset the script on rezzing, data should be received than from httpdb.
    // by only reseting on owner change we store our most values internal and
    // they do not get lost, if the httpdb for the wearer is "full"
//    on_rez(integer param)
//    {
//        if (llGetOwner()==g_keyWearer)
            //= still the same wearer?
//        {
            // Reset if wearer changed
//            llResetScript();
//        }
//    }


    // listen for likend messages fromOC scripts
    link_message(integer sender, integer num, string str, key id)
    {
//        if (num == SUBMENU && str == submenu)
//        {
//            //someone asked for our menu
//            //give this plugin's menu to id
//            DoMenu(id);
//        }
//        else if (num == MENUNAME_REQUEST && str == parentmenu)
            // our parent menu requested to receive buttons, so send ours
//        {

//            llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + submenu, NULL_KEY);
//        }
//        else if (num == MENUNAME_RESPONSE)
//            // a button is sned ot be added to a plugin
//        {
//            list parts = llParseString2List(str, ["|"], []);
//            if (llList2String(parts, 0) == submenu)
//            {//someone wants to stick something in our menu
//                string button = llList2String(parts, 1);
//                if (llListFindList(buttons, [button]) == -1)
//                    // if the button isnt in our benu yet, than we add it
//                {
//                    buttons = llListSort(buttons + [button], 1, TRUE);
//                }
//            }
//        }
//        else if (num == HTTPDB_RESPONSE)
//            // response from httpdb have been received
//        {
            // pares the answer
//            list params = llParseString2List(str, ["="], []);
//            string token = llList2String(params, 0);
//            string value = llList2String(params, 1);
//            // and check if any values for use are received
            // replace token1 by your own token, which should always start with the db identifier of the collar, f.i oc_visible=1
//            if (token == "value1" )
//            {
                // work with the received values
//            }
            // replace token2 by your own token
//            else if (token == "value2")
//            {
                // work with the received values
//            }
//        }
//        else
        if (num >= COMMAND_OWNER && num <= COMMAND_WEARER)
            // a validated command from a owner, secowner, groupmember or the wear has been received
            // can also be used to listen to chat commands
        {   /* //no more self resets
            if (str == "reset")
                // it is a request for a reset
            {
                if (num == COMMAND_WEARER || num == COMMAND_OWNER)
                {   //only owner and wearer may reset
                    llResetScript();
                }
            }
            else 
            */
            if (llList2String(llParseString2List(str,[" "],[]),0) == "recmacro")
            {
                curmacroname=llList2String(llParseString2List(str,[" "],[]),1);
                curmacrocontent="";
                curuser=id;
                llInstantMessage(id, "Now recording macro "+curmacroname+". Say <prefix>stopmacro when you are done.");
            }
            else if (str == "stopmacro"&&id==curuser)
            {
                recmacro(curmacroname,num,id,curmacrocontent);
                curmacroname="";
            }
            else if (llGetSubString(str,0,0)=="$")
            {
                playmacro(llGetSubString(str,1,-1),num,id);
            }
            else if (llList2String(llParseString2List(str,[" "],[]),0) == "showmacro")
            {
                string macroname=llList2String(llParseString2List(str,[" "],[]),1);
                string content;
                string out="Content of "+macroname+": ";
                integer i;
                if (num==COMMAND_OWNER)
                {
                    i = llListFindList(ownermacronames,[macroname]);
                    if (i!=-1) out += llDumpList2String(llParseString2List(llList2String(ownermacrocontents,i),["|"],[]),", ");
                    else out = "Sorry, this macro hasn't been recorded.";
                }
                else if (num==COMMAND_WEARER)
                {
                    i = llListFindList(wearermacronames,[macroname]);
                    if (i!=-1) out += llDumpList2String(llParseString2List(llList2String(wearermacrocontents,i),["|"],[]),", ");
                    else out = "Sorry, this macro hasn't been recorded.";
                }
                else out="Sorry, only the primary owner and the wearer have macros.";
                llInstantMessage(id, out);
            }
            else if (str == "listmacros")
            {
                string out="Your macros are: ";
                integer i;
                if (num==COMMAND_OWNER)
                {
                    out+=llList2String(ownermacronames,0);
                    for (i=1;i<llGetListLength(ownermacronames);i++)
                    {
                        out+=", "+llList2String(ownermacronames,i);
                    }
                }
                else if (num==COMMAND_WEARER)
                {
                    out+=llList2String(wearermacronames,0);
                    for (i=1;i<llGetListLength(wearermacronames);i++)
                    {
                        out+=", "+llList2String(wearermacronames,i);
                    }
                }
                else out="Sorry, only the primary owner and the wearer have macros.";
                llInstantMessage(id, out);
            }
            else if (curmacroname!=""&&id==curuser)
            {
                curmacrocontent+="|"+str;
                llInstantMessage(id, "Adding "+str+" to macro "+curmacroname+".");
            }

        }

    }

    // listener for menu
/*    listen(integer channel, string name, key id, string message)
    {
        // get rid of the listener
        llListenRemove(listener);
        llSetTimerEvent(0.0);
        if (channel == menuchannel)
        {
            // request to change to parrent menu
            if (message == UPMENU)
            {
                //give id the parent menu
                llMessageLinked(LINK_THIS, SUBMENU, parentmenu, id);
            }
            else if (~llListFindList(localbuttons, [message]))
            {
                //we got a response for something we handle locally
                if (message == "Command 1")
                {
                    // do What has to be Done
                    Debug("Command 1");
                    // and restart the menu if wantend/needed
                    DoMenu(id);
                }
                else if (message == "Command 2")
                {
                    // do What has to be Done
                    Debug("Command 2");
                    // and restart the meuu if wantend/needed
                    DoMenu(id);
                }
            }
            else if (~llListFindList(buttons, [message]))
            {
                //we got a command which another command pluged into our menu
                llMessageLinked(LINK_THIS, SUBMENU, message, id);
            }
        }
    }

    timer()
    {
        // timeou for the menu, so remove timer and listener
        llListenRemove(listener);
        llSetTimerEvent(0.0);
    }
*/
}

