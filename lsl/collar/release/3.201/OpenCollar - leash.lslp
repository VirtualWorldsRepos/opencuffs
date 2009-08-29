//leash script for the Open Collar Project (c)
//Licensed under the GPLv2, with the additional requirement that these scripts remain "full perms" in Second Life.  See "OpenCollar License" for details.

integer targethandle;
vector pos = ZERO_VECTOR;
integer stay = FALSE;
integer listenhandle;

float length = 3.0;
string part_texture = "chain";
key part_target = NULL_KEY;
integer holderchannel = -8888;
key leasher = NULL_KEY;

integer lastrank;
integer stayrank;
// string dbtoken = "leashtexture"; a more general dbtoken is needed as we now save not only leash texture
string dbtoken = "leash";
list leashSettings; 

//help
string parentmenu = "Main";
string submenu = "Leash";
list menulist;
integer menutimeout = 60;
integer menulistener;
integer menuchannel = -1908789;
string currentmenu = "";

//MESSAGE MAP
integer COMMAND_NOAUTH = 0;
integer COMMAND_OWNER = 500;
integer COMMAND_SECOWNER = 501;
integer COMMAND_GROUP = 502;
integer COMMAND_WEARER = 503;
integer COMMAND_EVERYONE = 504;
//integer CHAT = 505;
integer COMMAND_SAFEWORD = 510;  // new for safeword

//integer SEND_IM = 1000; deprecated.  each script should send its own IMs now.  This is to reduce even the tiny bt of lag caused by having IM slave scripts
integer POPUP_HELP = 1001;

integer HTTPDB_SAVE = 2000;//scripts send messages on this channel to have settings saved to httpdb
                            //str must be in form of "token=value"
integer HTTPDB_REQUEST = 2001;//when startup, scripts send requests for settings on this channel
integer HTTPDB_RESPONSE = 2002;//the httpdb script will send responses on this channel
integer HTTPDB_DELETE = 2003;//delete token from DB
integer HTTPDB_EMPTY = 2004;//sent when a token has no value in the httpdb

integer MENUNAME_REQUEST = 3000;
integer MENUNAME_RESPONSE = 3001;
integer SUBMENU = 3002;

//string UPMENU = "↑";
//string MORE = "→";
string UPMENU = "^";
string MORE = ">";
string LEASH = "Grab";
string UNLEASH = "Unleash";
string STAY = "Stay";
string UNSTAY = "UnStay";
string L_LENGTH = "Length";
string GIVE_HOLDER = "give Holder";
string GIVE_POST = "give Post";
string REZ_POST = "Rez Post";
string L_POST = "Post";
string L_YANK = "Yank";
string LEASH_TO = "LeashTo";

float scanrange = 10.0;
list postbuttons;
list postkeys;
string postprompt;
integer postchannel = 834531;
string menuuser;
integer postlistener;
integer danglecount = -1;
integer menucount = -1;
key leash_holder;

string sensormode;
list leashers;
string tmpname;
key cmdgiver;

list lengths = ["1", "2", "3", "4", "5", "8","10" , "15", "20", "25", "30"];

debug(string str)
{
    //llOwnerSay(llGetScriptName() + ": " + str);
}

LeashMenu(key id)
{
    currentmenu = "leash";
    list buttons;
    buttons += [LEASH, L_YANK, L_LENGTH];
    buttons += [LEASH_TO, UNLEASH, GIVE_HOLDER];
    buttons += [L_POST, REZ_POST, GIVE_POST ];
    buttons += [STAY, UNSTAY, UPMENU];
    buttons = RestackMenu(buttons);
    string prompt = "Leash Options";
    prompt += "\n(Menu will time out in " + (string)menutimeout + " seconds.)";        
    menulistener = llListen(menuchannel, "", id, "");
    menucount = 60;
    llSetTimerEvent(1.0);
    llDialog(id, prompt, buttons, menuchannel);
}

LengthMenu(key id)
{
    currentmenu = "length";
    list buttons;
    buttons += lengths;
    buttons += [UPMENU];
    buttons = RestackMenu(FillMenu(buttons));     
    string prompt = "Set a leash length in meter:";
    prompt += "\n(Menu will time out in " + (string)menutimeout + " seconds.)";        
    menulistener = llListen(menuchannel, "", id, "");
    menucount = 60;
    llSetTimerEvent(1.0);
    llDialog(id, prompt, buttons, menuchannel);
}

LeashToMenu(key id, list leashto)
{
    currentmenu = "leashto";
    string prompt = "Pick someone to leash to.";
    prompt += "  (Menu will time out in 45 seconds.)";
    if (llGetListLength(leashto) > 11)
    {
        leashto= llList2List(leashto, 0, 10);
    }
    list buttons = leashto;//we're limiting this to 11 avs
    buttons += [UPMENU];
    buttons = RestackMenu(FillMenu(buttons));
    menucount = 60;
    llSetTimerEvent(1.0);
    menulistener = llListen(menuchannel, "", id, "");
    llDialog(id, prompt, buttons, menuchannel);   
}

list FillMenu(list in)
{ //adds empty buttons until the list length is multiple of 3, to max of 12
    while (llGetListLength(in) != 3 && llGetListLength(in) != 6 && llGetListLength(in) != 9 && llGetListLength(in) < 12)
    {
        in += [" "];
    }
    return in;
}

list RestackMenu(list in)
{    //re-orders a list so dialog buttons start in the top row
    list out = llList2List(in, 9, 11);
    out += llList2List(in, 6, 8);
    out += llList2List(in, 3, 5);    
    out += llList2List(in, 0, 2);    
    return out;
}

SetTexture(string newtex)
{
    part_texture = newtex;
    //tell wearer
    string message = "Leash texture set to " + part_texture;
    if (leasher != NULL_KEY)
        llInstantMessage(leasher, message);
    llOwnerSay(message);
    //save leash texture to db
//    llMessageLinked(LINK_THIS, HTTPDB_SAVE, dbtoken + "=" + part_texture, NULL_KEY);
    if(llListFindList(leashSettings, ["texture"]) == -1)
    {
        leashSettings += ["texture", (string)part_texture];
    }
    else
    {
        integer index = llListFindList(leashSettings, ["texture"]) + 1;
        leashSettings = llListReplaceList(leashSettings, [(string)part_texture], index, index);
    }
    llMessageLinked(LINK_THIS, HTTPDB_SAVE, dbtoken + "=" + llDumpList2String(leashSettings, ","), NULL_KEY);
//    llMessageLinked(LINK_THIS, HTTPDB_SAVE, dbtoken + "=" + "texture," + part_texture + ",", NULL_KEY);
}

SetLength(float newlength, key id)
{
    length = newlength;
    // llTarget needs to be changed to the new length if leashed
    if(leasher != NULL_KEY)
    {
        llTargetRemove(targethandle);
        targethandle = llTarget(pos, length);
    }
    //tell wearer
    string message = "Leash length set to " + (string)length;
//########### save leash lentgh to httpdb
    if(llListFindList(leashSettings, ["length"]) == -1)
    {
        leashSettings += ["length", (string)length];
    }
    else
    {
        integer index = llListFindList(leashSettings, ["length"]) + 1;
        leashSettings = llListReplaceList(leashSettings, [(string)length], index, index);
    }
    llMessageLinked(LINK_THIS, HTTPDB_SAVE, dbtoken + "=" + llDumpList2String(leashSettings, ","), NULL_KEY);
//###########    
    if(id != llGetOwner());
    {
        llOwnerSay(message);
    }
    llInstantMessage(id, message);
}

LeashTo(key holder, integer rank, list leashpoints)
{
    danglecount = -1;
    // remove old handle/post listener first 
    llListenRemove(listenhandle);
    leash_holder = NULL_KEY;
    lastrank = rank;
    integer leashpointcount = llGetListLength(leashpoints);    
    //only listen for a leash holder if we've been passed at least one leash point
    if (leashpointcount)
    {   //if more than one leashpoint, listen for all strings, else listen just for that point        
        string listenfor = "";    
        if (leashpointcount == 1)
        {
            listenfor = (string)holder + llList2String(leashpoints, 0) + " ok";
        }        
        listenhandle = llListen(holderchannel, "", NULL_KEY, listenfor);
    }
    //set up movement and particle targets.
    leasher = holder;    
    part_target = leasher;//send leash particles to leasher av until we hear from a leash holder prim
    LeashParticles(part_target);
    
//####### need to store the leasher to the httpdb to releash on relog
    if(llListFindList(leashSettings, ["leasher"]) == -1)
    {
        leashSettings += ["leasher", (string)leasher, (string)rank];
    }
    else
    {
        integer index = llListFindList(leashSettings, ["leasher"]) + 1;
        leashSettings = llListReplaceList(leashSettings, [(string)leasher, (string)rank], index, index);
    }
    llMessageLinked(LINK_THIS, HTTPDB_SAVE, dbtoken + "=" + llDumpList2String(leashSettings, ","), NULL_KEY);
//##########    
    debug("leasher: " + (string)leasher);
    // change to llTarget events by Lulu Pink    
    pos = llList2Vector(llGetObjectDetails(leasher, [OBJECT_POS]), 0);
    //to prevent multiple target events and llMoveToTargets
    llTargetRemove(targethandle);
    llStopMoveToTarget();
    targethandle = llTarget(pos, length);
    llMoveToTarget(pos, 1.0);
    //announce to leash holder prims
    integer n;
    debug("leashpoints: " + (string)leashpointcount);
    for (n = 0; n < leashpointcount; n++)
    {
        llSay(holderchannel, (string)holder + llList2String(leashpoints, n));
    }   
}

StayPut(key id, integer rank)
{
//    if(leasher != NULL_KEY)
//    {
//        Unleash();
//    }
    stayrank = rank;
    stay = TRUE;
    llRequestPermissions(llGetOwner(), PERMISSION_TAKE_CONTROLS);
    llOwnerSay(llKey2Name(id) + " commanded you to stay in place, you cannot move until the command is revoked again.");
    llInstantMessage(id,"You commanded " + llKey2Name(llGetOwner()) + " to stay in place, to allow to move again, either leash the slave with the grab command or use unstay to enable movement again.");
    
}

Unleash()
{
    llStopMoveToTarget();
    danglecount = -1;
    llListenRemove(listenhandle);
    llTargetRemove(targethandle);
    llParticleSystem([]);
    leasher = NULL_KEY;
    //added for issue 253 where the leash dangles without real reason. should have no negative effect and just ensures a more cean unleash i think
    leash_holder = NULL_KEY;
    part_target = NULL_KEY;
    lastrank = COMMAND_EVERYONE;
//####### remove leasher from httpdb
    if(llListFindList(leashSettings, ["leasher"]) == -1)
    {
        leashSettings += ["leasher", (string)NULL_KEY];
    }
    else
    {
        integer index = llListFindList(leashSettings, ["leasher"]) + 1;
        leashSettings = llListReplaceList(leashSettings, [(string)NULL_KEY, "0"], index, index);
    }
    llMessageLinked(LINK_THIS, HTTPDB_SAVE, dbtoken + "=" + llDumpList2String(leashSettings, ","), NULL_KEY);

}

LeashParticles(key target)
{
    debug("sending particles to " + (string)target);
    string texture = part_texture;
    integer flags = 0;
    flags = flags | PSYS_PART_EMISSIVE_MASK;
    flags = flags | PSYS_PART_FOLLOW_SRC_MASK;
    flags = flags | PSYS_PART_FOLLOW_VELOCITY_MASK;
    integer pattern = PSYS_SRC_PATTERN_DROP;
    
    if (target != NULL_KEY)
        flags = flags | PSYS_PART_TARGET_POS_MASK;
    
    list sys = [                        
        PSYS_PART_MAX_AGE,6.0,
        PSYS_PART_START_COLOR, <1,1,1>,
        PSYS_PART_END_COLOR, <0,0,1>,
        PSYS_PART_START_ALPHA, 1.0,
        PSYS_PART_END_ALPHA, 0.5,
        PSYS_PART_START_SCALE,<.07,.07,.1>,
        PSYS_PART_END_SCALE,<0.1,0.1,0.1>,
        PSYS_SRC_BURST_RATE, 0.03,
        PSYS_SRC_BURST_PART_COUNT,1,
        PSYS_SRC_BURST_RADIUS,0.1,
        PSYS_SRC_BURST_SPEED_MIN,1.0,
        PSYS_SRC_BURST_SPEED_MAX,1.0,
        PSYS_SRC_ACCEL, <0,0,-0.4>,
        PSYS_SRC_ANGLE_BEGIN,0.0,
        PSYS_SRC_ANGLE_END,PI,
        PSYS_SRC_OMEGA, <0,0,1>,
        PSYS_SRC_MAX_AGE, 0.0,
        PSYS_PART_FLAGS,flags,
        PSYS_SRC_PATTERN, pattern,
        PSYS_SRC_TARGET_KEY,target,
        PSYS_SRC_TEXTURE, texture
                            ];
    llParticleSystem(sys);     
}

integer isInSim(vector v)
{
    if(v == ZERO_VECTOR || v.x < 0 || v.x > 256 || v.y < 0 || v.y > 256)
        return FALSE;
    else
        return TRUE;
}

integer KeyIsAv(key id)
{
    return llGetAgentSize(id) != ZERO_VECTOR;
}

integer startswith(string haystack, string needle) // http://wiki.secondlife.com/wiki/llSubStringIndex
{
    return llDeleteSubString(haystack, llStringLength(needle), -1) == needle;
}
/* //silly to make this a own function somehow???
integer isKey(string id)
{   // verifying the string is a key
    if((key)id)
    {
        return TRUE;
    }
    return FALSE;
}
*/
LeashToHelp(key id)
{
    llMessageLinked(LINK_THIS, POPUP_HELP, llKey2Name(llGetOwner()) + " has been leashed to you.  Say _PREFIX_unleash to unleash them.  Say _PREFIX_giveholder to get a leash holder.", id);
}

YankTo(key id)
{
    vector dest = (vector)llList2String(llGetObjectDetails(id, [OBJECT_POS]), 0);
    llMoveToTarget(dest, 0.5);
    llSleep(2.0);
    llStopMoveToTarget();    
}

default
{
    state_entry()
    {  //prefix the "leashtexture" token
        dbtoken = llList2String(llParseString2List(llGetObjectDesc(), ["~"], []), 2) + dbtoken;
        Unleash();
        menuchannel = -(integer)llFrand(999950.0) - 99999;
        llSleep(1.0);
        llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + submenu, NULL_KEY);
    }
    
    on_rez(integer param)
    {
        llResetScript();
    }
    
    link_message(integer sender, integer auth, string str, key id)
    {  //only respond to owner, secowner, group, wearer
        if (auth >= COMMAND_OWNER && auth <= COMMAND_WEARER)
        {
            list params = llParseString2List(str, [" "], []);
            string command = llList2String(params, 0);
            if ((str == "grab" || str == "leash") && id != llGetOwner())
            {
                if (leasher != NULL_KEY && auth <= lastrank)
                { //if leashed, only move leash if commander's authority greater than current leasher's
                    LeashTo(id, auth, ["handle"]);
                }
                else
                { //if unleashed, then leash if commander authorized, only owner, secowner, and group may "grab"
                    if (auth >= COMMAND_OWNER && auth <= COMMAND_GROUP)
                    {
                        LeashTo(id, auth, ["handle"]);
                    }
                }
            }
            else if(command == "leashto")
            {
                tmpname = llList2String(params, 1);
                debug("leashing to " + tmpname);
                lastrank = auth;         
                if((key)tmpname)
                {
                    list leashpoints = llList2List(params, 2, -1);
                    debug("leash target is key");//could be a post, or could be we specified an av key
                    key leashingto = (key)tmpname;
                    LeashTo(leashingto, auth, leashpoints);
                        //need to notify target how to unleash.  only do if:
                        //they're an avatar
                        //they didn't send the command
                        //they don't own the object that sent the command
                    if (KeyIsAv(leashingto) && id != leashingto && llGetOwnerKey(id) != leashingto)
                    {
                        LeashToHelp(leashingto);
                    }
                }
                else
                {
                    debug(tmpname + " isn't key");
                    sensormode = "chatleashto";
                    if(llStringLength(tmpname) > 1)
                    {
                        llSensor("", "", AGENT, scanrange, PI);
                        cmdgiver = id;
                    }
                }
            }
            else if (str == "giveholder")
            {
                llGiveInventory(id, "Leash Holder");
            }
            else if (str == "givepost")
            {
                llGiveInventory(id, "OC_Leash_Post");
            }  
            else if (str == "rezpost")
            {
                vector position = llGetPos();
                rotation angle = llGetRot();
                vector posta = <0,90,0>;
                posta *= DEG_TO_RAD;
                rotation quat = llEuler2Rot(posta);
                vector offset = <1.0, 0, 0.5>;
                llRezObject( "OC_Leash_Post", position + (offset * angle), ZERO_VECTOR, quat, 0 );
            }           
            else if (str == "unleash")
            {   //allow if from leasher or someone outranking them
                if (id == leasher || auth <= lastrank)
                    Unleash();
            }
            else if (str == "yank" && id == leasher)
            {
                YankTo(id);
            }
            else if (llList2String(params, 0) == "length")
            {
                float newlength = (float)llList2String(params, 1);
                if(newlength > 0.0)
                {
                    if (leasher == NULL_KEY)
                    {  //if unleashed, any authorized person can change length
                        SetLength(newlength, id);
                    }
                    else if (id == leasher)
                    {  //leasher can change length
                        SetLength(newlength, id);
                    }
                    else if (auth <= lastrank)
                    {  //people outranking the leasher can change length
                        SetLength(newlength, id);
                    }
                }
                else
                {
                    if(id != llGetOwner())
                    {
                        llOwnerSay("The current leash length is " + (string)length + "m.");
                    }
                    llInstantMessage(id, "The current leash length is " + (string)length + "m.");
                }
            }
            else if (str == "reset")
            {
                if (auth == COMMAND_WEARER || auth == COMMAND_OWNER)
                {   //only owner and wearer may reset
                    llResetScript();
                }
            }
            else if (str == "post")
            {// changed from auth <= COMMAND_GROUP to COMMAND_WEARER
                if (auth >= COMMAND_OWNER && auth <= COMMAND_WEARER)
                {
                    menuuser = id;
                    sensormode = "post";
                    llSensor("", NULL_KEY, SCRIPTED, scanrange, PI);
                }
            }
            else if(command == "post")
            {
                if (auth <= lastrank || lastrank == 0)
                {
                    LeashTo((key)llList2String(params, 1), auth, []);
                }
                else
                {
                    string wearer = llKey2Name( llGetOwner() );
                    string swearer = llList2String( llParseString2List( llKey2Name( llGetOwner() ), [" "], [] ), 0 );
                    llInstantMessage(id, "Sorry, someone who outranks you on " + wearer +"'s collar leashed " + swearer + " already.");
                }    
            }
            else if (str == "stay")
            {
                if (auth >= COMMAND_OWNER && auth <= COMMAND_GROUP)
//                if ((id != llGetOwner()) && (auth >= COMMAND_OWNER && auth <= COMMAND_GROUP))
                    StayPut(id, auth);
            }
            else if ((str == "unstay" || str == "move") && stay)
            {
                if (auth <= stayrank)
                {
                    stay = FALSE;
                    llReleaseControls();
                    llOwnerSay("You are free to move again.");
                    llInstantMessage(id,"You allowed " + llKey2Name(llGetOwner()) + " to move freely again.");
                }   
            }
            else if (llGetInventoryType(str) == INVENTORY_TEXTURE)
            {   //use the new texture.  check hierarchy though
                if (leasher == NULL_KEY)
                {    //if unleashed, then any authorized person can changed texture, including wearer
                    SetTexture(str);
                }
                else if (id == leasher)
                {   //leasher can change texture
                    SetTexture(str);
                    LeashParticles(part_target);
                }
                else if (auth <= lastrank)
                {   //people outranking or equal to the leasher can change texture
                    SetTexture(str);
                    LeashParticles(part_target);
                }
            }
        }
        else if (auth == COMMAND_EVERYONE)
        {
            if (id == leasher)
            {
                if (str == "unleash")
                {
                    //TODO: implement this for secowners and group members too if they get leashed to
                    Unleash();                    
                }
                else if (str == "giveholder")
                {
                    llGiveInventory(id, "Leash Holder");
                }
                else if (str == "yank")
                {
                    YankTo(id);
                }
            }
        }
        else if (auth == MENUNAME_REQUEST)
        {
            llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + submenu, NULL_KEY);
        }
        else if (auth == SUBMENU && str == UPMENU)
        {
            llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + submenu, NULL_KEY);
        }
        else if (auth == SUBMENU && str == submenu)
        {
            LeashMenu(id);
        }
        else if (auth == COMMAND_SAFEWORD)
        {
            if(stay)
            {
                stay = FALSE;
                llReleaseControls();
            }
            Unleash();
        }
        else if (auth == HTTPDB_RESPONSE)
        {
            if (llSubStringIndex(str, dbtoken + "=") == 0)
            {//supposedly substring slicing is quicker and cheaper than list parsing, so I'm trying it here
                str = llGetSubString(str, llStringLength(dbtoken + "="), -1);
                leashSettings = llParseString2List(str, [","], []);
                integer i;
                for( i = 0; i < llGetListLength(leashSettings); i++)
                {
                    if(llList2String(leashSettings, i) == "texture")
                    {
                        part_texture = llList2String(leashSettings, i + 1);
                    }
                    if(llList2String(leashSettings, i ) == "length")
                    {
                        length = (integer)llList2String(leashSettings, i + 1);
                    }
                    if(llList2String(leashSettings, i) == "leasher")
                    {
                        leasher = (key)llList2String(leashSettings, i + 1);
                        if(leasher != NULL_KEY)
                        {
                            if(KeyIsAv(leasher))
                            {
                                LeashTo(leasher, (integer)llList2String(leashSettings, i +2), ["handle"]);
                            }
                            else
                            {
                                LeashTo(leasher, (integer)llList2String(leashSettings, i +2), []);
                            }
                        }
                    }
                }
            }
        }
    }

    sensor(integer num)
    {
        //give menuuser a list of things to choose from, loop the list off at 12 so we don't need multipage menu
        if (num > 12)
        {
            num = 12;
        }
        if (sensormode == "menuleashto")
        {
            leashers = [];
            list avs;//just used for menu building
            integer n;
            for (n = 0; n < num; n++)
            {
                string tmpName = llDetectedName(n);
                if(llStringLength(tmpName) > 24)
                {
                    tmpName = llGetSubString(tmpName, 0, 23);
                }
                leashers += [llDetectedKey(n), tmpName];
                avs += [tmpName];
            }
            LeashToMenu(menuuser, avs);
        }
        else if (sensormode == "chatleashto")
        {   //loop through detected avs, seeing if one matches tmpname
            integer n;
            for (n = 0; n < num; n++)
            {
                string name = llDetectedName(n);
                if (startswith(llToLower(name), llToLower(tmpname)))
                {
                    leasher = llDetectedKey(n);
                    LeashTo(leasher, lastrank, ["handle", "collar"]);   
                    //need to notify target how to unleash.  only do if:
                        //they're an avatar
                        //they didn't send the command
                        //they don't own the object that sent the command
                    if (KeyIsAv(leasher) && cmdgiver != leasher && llGetOwnerKey(cmdgiver) != leasher)
                    {
                        LeashToHelp(leasher);
                    }                                     
                    return;
                }
            }
            //if we got to this point, then no one matched
            llInstantMessage(cmdgiver, "Could not find '" + tmpname + "' to leash to.");             
        } 
        else if(sensormode == "post")
        {
            postbuttons = [];
            postprompt = "Pick the object on which you want the sub to be leashed to.  If it's not in the list, have the sub move closer and try again.\n";
            postkeys = [];
            integer n;
            for (n = 0; n < num; n ++)
            {
                string name = llDetectedName(n);
                if(name != "Object")
                {
                    postbuttons += [(string)(n + 1)];
                    if (llStringLength(name) > 44)
                    {   //added to prevent errors due to 512 char limit in poup prompt text
                        name = llGetSubString(name, 0, 40) + "...";
                    }
                    postprompt += "\n" + (string)(n + 1) + " - " + name;
                    postkeys += [llDetectedKey(n)];
                }
            }
            //prompt can only have 512 chars
            while (llStringLength(postprompt) >= 512)
            {   //pop the last item off the buttons, keys, and prompt
                postbuttons = llDeleteSubList(postbuttons, -1, -1);
                postkeys = llDeleteSubList(postkeys, -1, -1);
                postprompt = llDumpList2String(llDeleteSubList(llParseString2List(postprompt, ["\n"], []), -1, -1), "\n");
            }
            postbuttons = RestackMenu(FillMenu(postbuttons));
            postlistener = llListen(menuchannel, "", menuuser, "");
            menucount = 60;
            llSetTimerEvent(1.0);
            currentmenu = "post";
            llDialog(menuuser, postprompt, postbuttons, menuchannel);
        }
    }
    
    no_sensor()
    {   //nothing close by to leash on, tell menuuser
        llInstantMessage(menuuser, "Unable to find targets to leash to.");
    }        
    at_target(integer num, vector position, vector ourpos)
    {
        llStopMoveToTarget();
        llTargetRemove(targethandle);
        pos = llList2Vector(llGetObjectDetails(leasher,[OBJECT_POS]),0);
        targethandle = llTarget(pos, length);
        if(leasher != part_target)
        {
            if(llKey2Name(part_target) == "")
            {
                part_target = leasher;
                LeashParticles(part_target);
            }
        }
        else if(llKey2Name(leash_holder) != "")
        {
            debug("test1");
            part_target = leash_holder;
            LeashParticles(part_target);
        }        
    }
    timer()
    {
        if(leasher != NULL_KEY)
        {
            vector newpos = llList2Vector(llGetObjectDetails(leasher,[OBJECT_POS]),0);
            //if the leasher is gone we remove the target
            if(!isInSim(newpos) && danglecount == -1)
            {
                llStopMoveToTarget();
                llTargetRemove(targethandle);
                llParticleSystem([]);
                llListenRemove(listenhandle);
                danglecount = 120;
            }
            else if(isInSim(newpos) && danglecount != -1)
            {
                llStopMoveToTarget();
                LeashParticles(part_target);
                llTargetRemove(targethandle);
                targethandle = llTarget(newpos, length);
                llMoveToTarget(newpos, 1.0);
                danglecount = -1;
            }
        }
        if((menucount == 0 && danglecount == 0) || (menucount == 0 && danglecount == -1) || (menucount == -1 && danglecount == 0))
        {
            llSetTimerEvent(0.0);
        }
        if(danglecount == 0)
        {
            danglecount = -1;
        }
        else if(danglecount > 0)
            danglecount--;
        if(menucount == 0)
        {
            menucount = -1;
            llListenRemove(menulistener);
        }
        else if(menucount > 0)
            menucount--;
    }
    not_at_target()
    {
        vector newpos;
        newpos = llList2Vector(llGetObjectDetails(leasher,[OBJECT_POS]),0);
        if (pos != newpos)
        {
            pos = newpos;
            llTargetRemove(targethandle);
            targethandle = llTarget(pos, length);
        }
        llMoveToTarget(pos,0.7);
        //if the leasher is gone we remove the target and stop following
        if(!isInSim(newpos) && danglecount == -1)
        {
            llStopMoveToTarget();
            llTargetRemove(targethandle);
            danglecount = 120;
            llParticleSystem([]);
            llSetTimerEvent(1.0);
        }
        if(leasher != part_target)
        {
            if(llKey2Name(part_target) == "")
            {
                part_target = leasher;
                LeashParticles(part_target);
            }
        }
        else if(llKey2Name(leash_holder) != "")
        {
            debug("is here the bug?" + llKey2Name(leash_holder) + " " + llKey2Name(leasher));
            part_target = leash_holder;
            LeashParticles(part_target);
        }
}
    changed(integer change)
    {
        if(change & CHANGED_TELEPORT)
        {
            if(leasher != NULL_KEY)
            {   //wait a moment after teleporting...
                llSleep(3.0);
                vector newpos;
                newpos = llList2Vector(llGetObjectDetails(leasher,[OBJECT_POS]),0);
                if(newpos != ZERO_VECTOR)
                {
                    LeashParticles(part_target);
                    llTargetRemove(targethandle);
                    targethandle = llTarget(pos, length);
                }
            }
        }
    }   
//##########################################################             
    listen(integer channel, string name, key id, string message)
    {
        if(channel == holderchannel)
        {   //we heard from a leash holder. re-direct particles
            if (llGetOwnerKey(id) == leasher)
            {
                leash_holder = id;
                part_target = id;
                LeashParticles(part_target);            
            }
        }
        else if(channel == menuchannel)
        {
            llListenRemove(menulistener);
            menuuser = id;
            if(message == L_LENGTH)
            {
                LengthMenu(id);
            }
            else if(message == UPMENU)
            {
                if(currentmenu == "length")
                {
                    LeashMenu(id);
                }
                else
                {
                    llMessageLinked(LINK_THIS, SUBMENU, parentmenu, id);
                }
            }
            else if(message == LEASH_TO)
            {
                sensormode = "menuleashto";
                llSensor("", "", AGENT, scanrange, PI);
            }
            else if(currentmenu == "leashto")
            {
                integer index = llListFindList(leashers, [message]);
                if (index != -1)
                {
                    leasher = (key)llList2String(leashers, index -1);
                    LeashTo(leasher, lastrank, ["handle", "collar"]);
                    
                    if (id != leasher)
                    {
                        LeashToHelp(leasher);
                    }                       
                }
            }
            else if(currentmenu == "post")
            {
                integer postnum = (integer)message - 1;
                if (postnum >= 0)
                {
                    llMessageLinked(LINK_THIS, COMMAND_NOAUTH, "post " + llList2String(postkeys, postnum), id);
                }
                debug("post " + llList2String(postkeys, postnum) + (string)id);
            }
            else if(message == GIVE_HOLDER)
            {
                llMessageLinked(LINK_THIS, COMMAND_NOAUTH, "giveholder", id);
                LeashMenu(id);
            }
            else if(message == GIVE_POST)
            {
                llMessageLinked(LINK_THIS, COMMAND_NOAUTH, "givepost", id);
                LeashMenu(id);
            }
            else if(message == REZ_POST)
            {
                llMessageLinked(LINK_THIS, COMMAND_NOAUTH, "rezpost", id);
                LeashMenu(id);
            }
            else if(llListFindList(lengths,[message]) != -1)
            {
                llMessageLinked(LINK_THIS, COMMAND_NOAUTH, "length " + message, id);
                LeashMenu(id);
            }
            else
            {
                llMessageLinked(LINK_THIS, COMMAND_NOAUTH, llToLower(message), id);
            }
            menucount = -1;
        }
    }
    run_time_permissions(integer perm)
    {
        if (PERMISSION_TAKE_CONTROLS & perm)
        {//disbale all controls but left mouse button
            llTakeControls( CONTROL_ROT_LEFT | CONTROL_ROT_RIGHT | CONTROL_LBUTTON | CONTROL_ML_LBUTTON, FALSE, FALSE); 
        }
    }
}