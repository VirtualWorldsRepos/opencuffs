//Licensed under the GPLv2, with the additional requirement that these scripts remain "full perms" in Second Life.  See "OpenCollar License" for details.
//Collar Cuff Menu

//=============================================================================
//== OC Bell Plugin - Adds bell sounds while moving to the collar, allows to adjust vol, sound and timing
//== as well to switch them off and hide the bell
//==
//== Note to Designers
//== Plugin offers option to show/hide the bell if there are prims named "Bell"
//== Plugin has a few default sounds, you can add more by putting them in the collar. The plugin scan for sounds starting with "bell_", f.i. "bell_kitty1"
//==
//== 2009-01-30 Cleo Collins - 1. draft
//==
//==
//=============================================================================

integer g_nDebugging=FALSE;

string submenu = "Bell";
string parentmenu = "AddOns";
integer menuchannel = 3907345;//we'll randomize this later
integer listener;
integer timeout = 60;

list localbuttons = ["Vol +","Vol -","Delay +","Delay -","Next Sound","~Chat Help","Ring It"];

float g_fVolume=0.5; // volume of the bell
float g_fVolumeStep=0.1; // stepping for volume
string g_szVolToken="bellvolume"; // token for saving bell volume

float g_fSpeed=1.0; // Speed of the bell
float g_fSpeedStep=0.5; // stepping for Speed adjusting
float g_fSpeedMin=0.5; // stepping for Speed adjusting
float g_fSpeedMax=5.0; // stepping for Speed adjusting

string g_szSubPrefix;

string g_szSpeedToken="bellspeed"; // token for saving bell volume

integer g_nBellOn=0; // are we ringing. Off is 0, On = Auth of person which enabled
string g_szBellOn="*Bell On*"; // menu text of bell on
string g_szBellOff="*Bell Off*"; // menu text of bell on
string g_szBellOnOffToken="bellon"; // token for saving bell volume
integer g_nBellAvailable=FALSE;

integer g_nBellShow=TRUE; // is the bell visible
string g_szBellShow="Bell Show"; //menu text of bell visible
string g_szBellHide="Bell Hide"; //menu text of bell hidden
string g_szBellShowToken="bellshow"; // token for saving bell volume

list g_listBellSounds=["7b04c2ee-90d9-99b8-fd70-8e212a72f90d","b442e334-cb8a-c30e-bcd0-5923f2cb175a","1acaf624-1d91-a5d5-5eca-17a44945f8b0","5ef4a0e7-345f-d9d1-ae7f-70b316e73742","da186b64-db0a-bba6-8852-75805cb10008","d4110266-f923-596f-5885-aaf4d73ec8c0","5c6dd6bc-1675-c57e-0847-5144e5611ef9","1dc1e689-3fd8-13c5-b57f-3fedd06b827a"]; // list with bell sounds
key g_keyCurrentBellSound ; // curent bell sound key
integer g_nCurrentBellSound; // curent bell sound sumber
integer g_nBellSoundCount; // number of avail bell sounds
string g_szBellSoundIdentifier="bell_"; // use this to find additional sounds in the inventory
string g_szBellSoundNumberToken="bellsoundnum"; // token to save number of the used sound
string g_szBellSoundKeyToken="bellsoundkey"; // token to save key of the used sound

string g_szBellSaveToken="bell"; // token to save settings of the bell on the http
    
string g_szBellPrimName="Bell"; // Description for Bell elements

list g_lstBellElements; // list with number of prims related to the bell

float g_fNextRing; // store time for the next ringing here;

string g_szBellChatPrefix="bell"; // prefix for chat commands

key g_keyWearer; // key of the current wearer to reset only on owner changes

integer g_nHasControl=FALSE; // dow we have control over the keyboard?

list buttons;

integer g_nLocalMenuCall=FALSE;

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


string UPMENU = "^";//when your menu hears this, give the parent menu



string AutoPrefix()
{
    list name = llParseString2List(llKey2Name(llGetOwner()), [" "], []);
    return llToLower(llGetSubString(llList2String(name, 0), 0, 0)) + llToLower(llGetSubString(llList2String(name, 1), 0, 0));
}

//===============================================================================
//= parameters   :    key keyID   Target for the message
//=                string szMsg   Message to SEND
//=                integer nAlsoNotifyWearer Boolean to notify the wearer as well
//=
//= return        :    none
//=
//= description  :    send a message to a receiver and if needed to the wearer as well
//=
//===============================================================================



Notify(key keyID, string szMsg, integer nAlsoNotifyWearer)
{
    Debug((string)keyID);
    if (keyID == g_keyWearer)
    {
        llOwnerSay(szMsg);
    }
    else
    {
        llInstantMessage(keyID,szMsg);
        if (nAlsoNotifyWearer)
        {
            llOwnerSay(szMsg);
        }
    }
}


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
    if (g_nDebugging)
    {
        llOwnerSay(llGetScriptName() + ": " + szMsg);
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

//===============================================================================
//= parameters   :   none
//=
//= return        :    string prefix for the object in the form of "oc_"
//=
//= description  :    generate the prefix from the object desctiption
//=
//===============================================================================


string szGetDBPrefix()
{//get db prefix from list in object desc
    return llList2String(llParseString2List(llGetObjectDesc(), ["~"], []), 2);
}

//===============================================================================
//= parameters   :   key keyID   ID of talking person
//=
//= return        :    none
//=
//= description  :    generate the menu for the bell
//=
//===============================================================================

DoMenu(key keyID)
{
    string prompt = "Pick an option.\n";
    prompt += "(Menu will time out in " + (string)timeout + " seconds.)\n";
    list mybuttons = localbuttons + buttons;

    //fill in your button list here

    // Show buton for ringing the bell and add a text for it
    if (g_nBellOn>0) // the bell rings currently
    {
        mybuttons+= g_szBellOff;
        prompt += "Bell is ringing";
    }
    else
    {
        mybuttons+= g_szBellOn;
        prompt += "Bell is NOT ringing";
    }

    // Show button for showing/hidding the bell and add a text for it, if there is a bell
    if (g_nBellAvailable)
    {
        if (g_nBellShow) // the bell is hidden
        {
            mybuttons+= g_szBellHide;
            prompt += " and shown.\n";
        }
        else
        {
            mybuttons+= g_szBellShow;
            prompt += " and NOT shown.\n";
        }
    }
    else
    {  // no bell, so no text or sound
        prompt += ".\n";
    }

    // and show the volume and timing of the bell sound
    prompt += "The volume of the bell is now: "+(string)((integer)(g_fVolume*10))+"/10.\n";
    prompt += "The bell rings every "+llGetSubString((string)g_fSpeed,0,2)+" seconds when moving.\n";
    prompt += "Currently used sound: "+(string)(g_nCurrentBellSound+1)+"/"+(string)g_nBellSoundCount;

    mybuttons = llListSort(mybuttons, 1, TRUE);

    mybuttons += [UPMENU];//make sure there's a button to return to the parent menu
    mybuttons = RestackMenu(mybuttons);//re-order buttons to start at the top left of the dialog instead of bottom left
    llSetTimerEvent(timeout);
    menuchannel = llRound(llFrand(999999)) + 1;
    llListenRemove(listener);
    listener = llListen(menuchannel, "", keyID, "");
    llDialog(keyID, prompt, mybuttons, menuchannel);
}

//===============================================================================
//= parameters   :   list in   list of menu options
//=
//= return        :    formated list of menu options
//=
//= description  :    adds empty buttons until the list length is multiple of 3, to max of 12, re-orders a list so dialog buttons start in the top row and
// puts menu navigation buttons <^> into their dedicated place
//=
//===============================================================================

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


//===============================================================================
//= parameters   :   float fAlpha   alphaing for the prims
//=
//= return        :    none
//=
//= description  :    loop through stored links of prims of the bell and set the alpha for it
//=
//===============================================================================

SetBellElementAlpha(float fAlpha)
{
    //loop through stored links, setting color if element type is bell
    integer n;
    integer linkelements = llGetListLength(g_lstBellElements);
    for (n = 0; n < linkelements; n++)
    {
        llSetLinkAlpha(llList2Integer(g_lstBellElements,n), fAlpha, ALL_SIDES);
    }
}

//===============================================================================
//= parameters   :   none
//=
//= return        :    none
//=
//= description  :    loop throug elements and find all Bell Elements, store their prim number in a list
//=
//===============================================================================

BuildBellElementList()
{
    integer n;
    integer linkcount = llGetNumberOfPrims();
    list params;

    // clear list just in case
    g_lstBellElements = [];

    //root prim is 1, so start at 2
    for (n = 2; n <= linkcount; n++)
    {
        // read description
        params=llParseString2List((string)llGetObjectDetails(llGetLinkKey(n), [OBJECT_DESC]), ["~"], []);
        // check inf name is baell name
        if (llList2String(params, 0)==g_szBellPrimName)
        {
            // if so store the number of the prim
            g_lstBellElements += [n];
            // debug("added " + (string)n + " to elements");
        }
    }
    if (llGetListLength(g_lstBellElements)>0)
    {
        g_nBellAvailable=TRUE;
    }
    else
    {
        g_nBellAvailable=FALSE;
    }

}

//===============================================================================
//= parameters   :   none
//=
//= return        :    none
//=
//= description  :    prepare the list of bell sound, parse sounds in the collar and use when they begin with "bell_"
//=
//===============================================================================


PrepareSounds()
{
    // parse names of sounds in inventiory if those are for the bell
    integer i;
    integer m=llGetInventoryNumber(INVENTORY_SOUND);
    string s;
    for (i=0;i<m;i++)
    {
        s=llGetInventoryName(INVENTORY_SOUND,i);
        if (nStartsWith(s,g_szBellSoundIdentifier))
        {
            // sound found, add key to list
            g_listBellSounds+=llGetInventoryKey(s);
        }
    }
    // and set the current sound
    g_nBellSoundCount=llGetListLength(g_listBellSounds);
    g_nCurrentBellSound=0;
    g_keyCurrentBellSound=llList2Key(g_listBellSounds,g_nCurrentBellSound);
}

//===============================================================================
//= parameters   :   keyID receiver of the help
//=
//= return        :    none
//=
//= description  :    show help for shat commands
//=
//===============================================================================


ShowHelp(key keyID)
{

    string prompt = "Help for bell chat command:\n";
    prompt += "All commands for the bell of the collar of "+llKey2Name(g_keyWearer)+" start with \""+g_szSubPrefix+g_szBellChatPrefix+"\" followed by the command and the value, if needed.\n";
    prompt += "Examples: \""+g_szSubPrefix+g_szBellChatPrefix+" show\" or \""+g_szSubPrefix+g_szBellChatPrefix+" volume 10\"\n\n";
    prompt += "Commands:\n";
    prompt += "on: Enable bell sound.\n";
    prompt += "off: Disable bell sound.\n";
    prompt += "show: Show prims of bell.\n";
    prompt += "hide: Hide prims of bell.\n";
    prompt += "volume X: Set the volume for the bell, X=1-10\n";
    prompt += "delay X.X: Set the delay between rings, X=0.5-5.0\n";
    prompt += "help or ?: Show this help text.\n";

    llInstantMessage(keyID,prompt);
}

//===============================================================================
//= parameters   :   szSettings setting received from http
//=
//= return        :    none
//=
//= description  :    Restore settings from 1 string at the httpdb
//=
//= order of settings in the string:
//= g_nBellOn (integer),  g_nBellShow (integer), g_nCurrentBellSound (integer), g_szVolToken (integer/10), g_szSpeedToken (integer/10)
//=
//===============================================================================


RestoreBellSettings(string szSettings)
{
    list lstSettings=llParseString2List(szSettings,[","],[]);

    // should the bell ring
    g_nBellOn=(integer)llList2String(lstSettings,0);
    if (g_nBellOn & !g_nHasControl)
    {
        llRequestPermissions(g_keyWearer,PERMISSION_TAKE_CONTROLS);
    }
    else if (!g_nBellOn & g_nHasControl)
    {
        llReleaseControls();
        g_nHasControl=FALSE;

    }


    // is the bell visible?
    g_nBellShow=(integer)llList2String(lstSettings,1);
    if (g_nBellShow)
    {// make sure it can be seen
        SetBellElementAlpha(1.0);
    }
    else
    {// or is hidden
        SetBellElementAlpha(0.0);
    }

    // the number of the sound for ringing
    g_nCurrentBellSound=(integer)llList2String(lstSettings,2);
    g_keyCurrentBellSound=llList2Key(g_listBellSounds,g_nCurrentBellSound);
    
    // bell volume
    g_fVolume=((float)llList2String(lstSettings,3))/10;

    // ring speed
    g_fSpeed=((float)llList2String(lstSettings,4))/10;
}

//===============================================================================
//= parameters   :   none
//=
//= return        :    none
//=
//= description  :    Save settings in 1 string at the httpdb
//=
//= order of settings in the string:
//= g_nBellOn (integer),  g_nBellShow (integer), g_nCurrentBellSound (integer), g_szVolToken (integer/10), g_szSpeedToken (integer/10)
//=
//===============================================================================

SaveBellSettings()
{
    string szSettings=g_szBellSaveToken+"=";

    // should the bell ring
    szSettings += (string)g_nBellOn+",";
    
    // is the bell visible?
    szSettings+=(string)g_nBellShow+",";

    // the number of the sound for ringing
    szSettings+=(string)g_nCurrentBellSound+",";

    // bell volume
    szSettings+=(string)llFloor(g_fVolume*10)+",";

    // ring speed
    szSettings+=(string)llFloor(g_fSpeed*10);

    llMessageLinked(LINK_THIS, HTTPDB_SAVE,szSettings,NULL_KEY);
}
                

default
{
    state_entry()
    {
        // key of the owner
        g_keyWearer=llGetOwner();
        g_szSubPrefix=AutoPrefix();
        // update tokens for httpdb_saving
        string s=szGetDBPrefix();
        g_szBellSaveToken = s + g_szBellSaveToken;

        // out of date token, just in by now to delete them, can be removed in 3.4
        g_szVolToken = s + g_szVolToken;
        g_szSpeedToken = s + g_szSpeedToken;
        g_szBellOnOffToken = s + g_szBellOnOffToken;
        g_szBellShowToken = s + g_szBellShowToken;
        g_szBellSoundNumberToken=s + g_szBellSoundNumberToken;
        g_szBellSoundKeyToken=s + g_szBellSoundKeyToken;

        // reset script time used for ringing the bell in intervalls
        llResetTime();

        // bild up list of prims with bell elements
        BuildBellElementList();

        PrepareSounds();
//not needed anymore as we request menus already
        // now wait  to be sure al other scripts reseted and init the menu system into the collar
/*
        llSleep(1.0);
        llMessageLinked(LINK_THIS, MENUNAME_REQUEST, submenu, NULL_KEY);
        llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + submenu, NULL_KEY);
    */
    }

//dangerous as g_ketWearer may have changed and we dont have the new yet here! besides not needed anyway
/*
    on_rez(integer param)
    {
        llRequestPermissions(g_keyWearer,PERMISSION_TAKE_CONTROLS);
    }
*/
    link_message(integer sender, integer num, string str, key id)
    {
        if (num == SUBMENU && str == submenu)
        {
            //someone asked for our menu
            //give this plugin's menu to id
            DoMenu(id);
        }
        else if (num == MENUNAME_REQUEST && str == parentmenu)
        {
            // the menu structure is to be build again, so make sure we get recognized
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
        else if (num == HTTPDB_RESPONSE)
        {
            // some responses from the DB are coming in, check if it is about bell values
            list params = llParseString2List(str, ["="], []);
            string token = llList2String(params, 0);
            string value = llList2String(params, 1);
            
            if (token == g_szBellSaveToken )
            // line with bell settings received
            {
                // so we restore them
                RestoreBellSettings(value);
            }
            else if (token == "prefix")
            // prefix of chat for examples
            {
                g_szSubPrefix=value;
            }
            // from here old tokens are only restored and deleted from http to save room. This section can be removed at a later stage (3.4 for instance)
            else if (token == g_szVolToken )
            {
                // bell volume
                g_fVolume=(float)value;
                llMessageLinked(LINK_THIS,HTTPDB_DELETE,g_szVolToken,NULL_KEY);
                SaveBellSettings();
            }
            else if (token == g_szSpeedToken)
            {
                // ring speed
                g_fSpeed=(float)value;
                llMessageLinked(LINK_THIS,HTTPDB_DELETE,g_szSpeedToken,NULL_KEY);
                SaveBellSettings();
            }
            else if (token == g_szBellOnOffToken)
            {
                // should the bell ring
                g_nBellOn=(integer)value;
                llMessageLinked(LINK_THIS,HTTPDB_DELETE,g_szBellOnOffToken,NULL_KEY);
                SaveBellSettings();
            }
            else if (token == g_szBellSoundNumberToken)
            {
                // the number of the sound for ringing
                g_nCurrentBellSound=(integer)value;
                g_keyCurrentBellSound=llList2Key(g_listBellSounds,g_nCurrentBellSound);
                llMessageLinked(LINK_THIS,HTTPDB_DELETE,g_szBellSoundNumberToken,NULL_KEY);
                SaveBellSettings();
            }
            else if (token == g_szBellShowToken)
            {
                // is the bell visioble?
                g_nBellShow=(integer)value;
                if (g_nBellShow)
                {// make sure it can be seen
                    SetBellElementAlpha(1.0);
                }
                else
                {// or is hidden
                    SetBellElementAlpha(0.0);
                }
                llMessageLinked(LINK_THIS,HTTPDB_DELETE,g_szBellShowToken,NULL_KEY);
                SaveBellSettings();
            }
        }
        else if (num>=COMMAND_OWNER && num<=COMMAND_WEARER)
        {
            string test=llToLower(str);
            if (str == "refreshmenu")
            {
                buttons = [];
                llMessageLinked(LINK_SET, MENUNAME_REQUEST, submenu, NULL_KEY);
            }
            else if (str == g_szBellChatPrefix)
            {// the command prefix + bell without any extentsion is used in chat
                //give this plugin's menu to id
                DoMenu(id);
            }
            // we now chekc for chat commands
            else if (nStartsWith(test,g_szBellChatPrefix))
            {
                // it is a chat commad for the bell so process it
                list params = llParseString2List(test, [" "], []);
                string token = llList2String(params, 1);
                string value = llList2String(params, 2);

                if (token=="volume")
                {
                    integer n=(integer)value;
                    if (n<1) n=1;
                    if (n>10) n=10;
                    g_fVolume=(float)n/10;
                    SaveBellSettings();
                    Notify(id,"Bell volume set to "+(string)n, TRUE);
                }
                else if (token=="delay")
                {
                    g_fSpeed=(float)value;
                    if (g_fSpeed<g_fSpeedMin) g_fSpeed=g_fSpeedMin;
                    if (g_fSpeed>g_fSpeedMax) g_fSpeed=g_fSpeedMax;
                    SaveBellSettings();
                    llWhisper(0,"Bell delay set to "+llGetSubString((string)g_fSpeed,0,2)+" seconds.");
                }
                else if (token=="show" || token=="hide")
                {
                    if (token=="show")
                    {
                        g_nBellShow=TRUE;
                        SetBellElementAlpha(1.0);
                        Notify(id,"The bell is now visible.",TRUE);
                    }
                    else
                    {
                        g_nBellShow=FALSE;
                        SetBellElementAlpha(0.0);
                        Notify(id,"The bell is now invisible.",TRUE);
                    }
                    SaveBellSettings();

                }
                else if (token=="on")
                {
                    if (num!=COMMAND_GROUP)
                    {
                        if (g_nBellOn==0)
                        {
                            g_nBellOn=num;
                            if (!g_nHasControl)
                                llRequestPermissions(g_keyWearer,PERMISSION_TAKE_CONTROLS);


                            SaveBellSettings();
                            Notify(id,"The bell rings now.",TRUE);
                            if (g_nLocalMenuCall)
                            {
                                g_nLocalMenuCall=FALSE;
                                DoMenu(id);
                            }
                        }
                    }
                    else
                    {
                        Notify(id,"Group users or Open Acces users cannot change the ring status of the bell.",TRUE);
                    }
                }
                else if (token=="off")
                {
                    if ((g_nBellOn>0)&&(num!=COMMAND_GROUP))
                    {
                        g_nBellOn=0;

                        if (g_nHasControl)
                        {
                            llReleaseControls();
                            g_nHasControl=FALSE;

                        }
                
                        SaveBellSettings();
                        Notify(id,"The bell is now quiet.",TRUE);
                    }
                    else
                    {
                        Notify(id,"Group users or Open Acces users cannot change the ring status of the bell.",TRUE);
                    }
                    if (g_nLocalMenuCall)
                    {
                        g_nLocalMenuCall=FALSE;
                        DoMenu(id);
                    }
                }
                else if (token=="nextsound")
                {
                    g_nCurrentBellSound++;
                    if (g_nCurrentBellSound>=g_nBellSoundCount)
                    {
                        g_nCurrentBellSound=0;
                    }
                    g_keyCurrentBellSound=llList2Key(g_listBellSounds,g_nCurrentBellSound);
                    Notify(id,"Bell sound changed, now using "+(string)(g_nCurrentBellSound+1)+" of "+(string)g_nBellSoundCount+".",TRUE);
                }
                // show the help
                else if (token=="help" || token=="?")
                {
                    ShowHelp(id);
                }
                // let the bell ring one time
                else if (token=="ring")
                {
                    // update variable for time check
                    g_fNextRing=llGetTime()+g_fSpeed;
                    // and play the sound
                    llPlaySound(g_keyCurrentBellSound,g_fVolume);
                    //Debug("Bing");
                }

            }
        }
    }

    listen(integer channel, string name, key id, string message)
    {
        llListenRemove(listener);
        llSetTimerEvent(0.0);
        if (channel == menuchannel)
        {
            integer nRemenu=FALSE;
            if (message == UPMENU)
            {
                //give id the parent menu
                llMessageLinked(LINK_THIS, SUBMENU, parentmenu, id);
            }
            else if (~llListFindList(localbuttons, [message]))
            {
                // usually we want to reopen the menu
                nRemenu=TRUE;
                //we got a response for something we handle locally
                if (message == "Vol +")
                    // pump up the volume and store the value
                {
                    g_fVolume+=g_fVolumeStep;
                    if (g_fVolume>1.0)
                    {
                        g_fVolume=1.0;
                    }
                    SaveBellSettings();
                }
                else if (message == "Vol -")
                    // be more quiet, and store the value
                {
                    g_fVolume-=g_fVolumeStep;
                    if (g_fVolume<0.1)
                    {
                        g_fVolume=0.1;
                    }
                    SaveBellSettings();
                }
                else if (message == "Delay +")
                    // dont annoy people and ring slower
                {
                    g_fSpeed+=g_fSpeedStep;
                    if (g_fSpeed>g_fSpeedMax)
                    {
                        g_fSpeed=g_fSpeedMax;
                    }
                    SaveBellSettings();
                }
                else if (message == "Delay -")
                    // annoy the hell out of the, ring plenty, ring often
                {
                    g_fSpeed-=g_fSpeedStep;
                    if (g_fSpeed<g_fSpeedMin)
                    {
                        g_fSpeed=g_fSpeedMin;
                    }
                    SaveBellSettings();
                }
                else if (message == "Next Sound")
                    // choose another sound for the bell
                {
                    g_nCurrentBellSound++;
                    if (g_nCurrentBellSound>=g_nBellSoundCount)
                    {
                        g_nCurrentBellSound=0;
                    }
                    g_keyCurrentBellSound=llList2Key(g_listBellSounds,g_nCurrentBellSound);

                    SaveBellSettings();
                }
                // show help
                else if (message=="~Chat Help")
                {
                    ShowHelp(id);
                }
                //added a button to ring the bell. same call as when walking.
                else if (message == "Ring It")
                {
                    // update variable for time check
                    g_fNextRing=llGetTime()+g_fSpeed;
                    // and play the sound
                    llPlaySound(g_keyCurrentBellSound,g_fVolume);
                    //Debug("Bing");
                }

            }
            else if (message == g_szBellOff || message == g_szBellOn)
                // someone wants to change ioif the bell rings or not
            {
                string s;
                if (g_nBellOn>0)
                {
                    s="bell off";
                }
                else
                {
                    s="bell on";
                }
                llMessageLinked(LINK_THIS,COMMAND_NOAUTH,s,id);

                // LM listerer wil tkae care of showing the menua
                g_nLocalMenuCall=TRUE;
                nRemenu=FALSE;
            }
            else if (message == g_szBellShow || message == g_szBellHide)
                // someone wants to hide or show the bell
            {
                g_nBellShow=!g_nBellShow;
                if (g_nBellShow)
                {
                    SetBellElementAlpha(1.0);
                }
                else
                {
                    SetBellElementAlpha(0.0);
                }
                SaveBellSettings();
                nRemenu=TRUE;
            }
            else if (~llListFindList(buttons, [message]))
            {
                //we got a submenu selection
                llMessageLinked(LINK_THIS, SUBMENU, message, id);
            }
            // do we want to see the menu again?
            if (nRemenu) DoMenu(id);

        }
    }

    timer()
        // save a sim, stop the lafg by removing the listner
    {
        llListenRemove(listener);
        llSetTimerEvent(0.0);
    }

    control( key keyID, integer nHeld, integer nChange )
        // we watch for movement from
    {
        // we dont want the bell to ring, so just exit
        if (!g_nBellOn) return;
        // Is the user holding down a movement key
        if ( nHeld & (CONTROL_LEFT|CONTROL_RIGHT|CONTROL_DOWN|CONTROL_UP|CONTROL_ROT_LEFT|CONTROL_ROT_RIGHT|CONTROL_FWD|CONTROL_BACK) )
        {
            // check if the time is ready for the next ring
            if (llGetTime()>g_fNextRing)
            {
                // update variable for time check
                g_fNextRing=llGetTime()+g_fSpeed;
                // and play the sound
                llPlaySound(g_keyCurrentBellSound,g_fVolume);
                //Debug("Bing");
            }
        }
    }

    run_time_permissions(integer nParam)
        // we requested permissions, now we take control
    {
        if( nParam & PERMISSION_TAKE_CONTROLS)
        {
            //Debug("Bing");
            llTakeControls( CONTROL_DOWN|CONTROL_UP|CONTROL_FWD|CONTROL_BACK|CONTROL_LEFT|CONTROL_RIGHT|CONTROL_ROT_LEFT|CONTROL_ROT_RIGHT, TRUE, TRUE);
            g_nHasControl=TRUE;
        
        }
    }
}

