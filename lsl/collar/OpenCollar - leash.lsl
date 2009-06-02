//leash script for the Open Collar Project (c)
// "Copyright 2008 Open Collar Projec" 
//  Distributed under the term of the GNU General Public License

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

//help
string parentmenu = "Main";
string submenu = "Leash";
list menulist;
integer menutimeout = 45; //i think it should be at least 45 seconds here if not for the post 60...
integer menulistener;
integer menuchannel = 1908789;
string currentmenu = "";

//MESSAGE MAP
integer COMMAND_NOAUTH = 0;
integer COMMAND_OWNER = 500;
integer COMMAND_SECOWNER = 501;
integer COMMAND_GROUP = 502;
integer COMMAND_WEARER = 503;
integer COMMAND_EVERYONE = 504;
//integer CHAT = 505;

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

string UPMENU = "~PrevMenu~";
string LEASH = "Grab";
string UNLEASH = "Unleash";
string STAY = "Stay";
string UNSTAY = "UnStay";
string L_LENGTH = "Length";
string GIVE_HOLDER = "give Holder";
string GIVE_POST = "give Post";
string L_POST = "Post";
string L_YANK = "Yank";

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

list lengths = ["1", "2", "3", "4", "5", "8","10" , "15", "20", "25", "30"];

DeliverObject(key id, string object)
{
    string version = "0.0";
    
    string url = "http://collardata.appspot.com/updater/check?";
    url += "object=" + llEscapeURL(object);
    url += "&version=" + llEscapeURL(version);
    llHTTPRequest(url, [HTTP_METHOD, "GET",HTTP_MIMETYPE,"text/plain;charset=utf-8"], "");     
    llInstantMessage(id, "Queuing delivery of " + object + ".  It should be delivered in about 30 seconds.");
}

LeashMenu(key id)
{
    currentmenu = "leash";
    menuchannel = -(integer)llFrand(999950.0) + 30;
    list buttons;
    buttons += [L_YANK];
    buttons += [LEASH, STAY, L_LENGTH];
    buttons += [UNLEASH, UNSTAY, GIVE_POST];
    buttons += [GIVE_HOLDER, L_POST, UPMENU];
    buttons = RestackMenu(FillMenu(buttons));     
    string prompt = "Leash Options";
    prompt += "\n(Menu will time out in " + (string)menutimeout + " seconds.)";        
    menulistener = llListen(menuchannel, "", id, "");
    menucount = 45;
    llSetTimerEvent(1.0);
    llDialog(id, prompt, buttons, menuchannel);
}

LengthMenu(key id)
{
    currentmenu = "length";
    menuchannel = -(integer)llFrand(999950.0) + 30;
    list buttons;
    buttons += lengths;
    buttons += [UPMENU];
    buttons = RestackMenu(FillMenu(buttons));     
    string prompt = "Set a leash length in meter:";
    prompt += "\n(Menu will time out in " + (string)menutimeout + " seconds.)";        
    menulistener = llListen(menuchannel, "", id, "");
    menucount = 45;
    llSetTimerEvent(1.0);
    llDialog(id, prompt, buttons, menuchannel);
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

//5000 block is reserved for IM slaves


Popup(key id, string message)
{
    //one-way popup message.  don't listen for these anywhere
    llDialog(id, message, [], 298479);
}

SetTexture(string newtex)
{
    part_texture = newtex;
    //tell wearer
    string message = "Leash texture set to " + part_texture;
    if (leasher != NULL_KEY)
        llInstantMessage(leasher, message);
    llOwnerSay(message);
}

SetLength(float newlength, key id)
{
    length = newlength;
    // llTarget needs to be changed to the new length
    if(!stay)
    {
        llTargetRemove(targethandle);
        targethandle = llTarget(pos, length);
    }
    //tell wearer
    string message = "Leash length set to " + (string)length;
    llInstantMessage(id, message);
    llOwnerSay(message);
}

Leash(key holder, integer rank)
{
    //leash removes the stay command
    danglecount = -1;
    stay = FALSE;
    lastrank = rank;
    string listenfor = (string)holder + "handle ok";
    //added listenhandle to close the listener again on unleash
    listenhandle = llListen(holderchannel, "", NULL_KEY, listenfor);
    //llSay(0, "listening on " + (string)holderchannel + " for " + listenfor);
    leasher = holder;    
    part_target = leasher;//send leash particles to leasher av until we hear from a leash holder prim
    LeashParticles();
    // change to llTarget events by Lulu Pink    
    pos = llList2Vector(llGetObjectDetails(leasher, [OBJECT_POS]), 0);
    targethandle = llTarget(pos, length);
    llMoveToTarget(pos, 1.0);
    //announce to leash holder prims
    llSay(holderchannel, (string)holder + "handle");
//    llSetTimerEvent(1.0);
}

Leash2Post(key holder, integer rank)
{
    //leash removes the stay command
    stay = FALSE;
    lastrank = rank;
    leasher = holder;
    leash_holder = NULL_KEY;
    part_target = leasher;//send leash particles to leash post until we hear from a leash holder prim
    LeashParticles();
    pos = llList2Vector(llGetObjectDetails(leasher, [OBJECT_POS]), 0);
    llMoveToTarget(pos, 0.7);
    targethandle = llTarget(pos, length);
}
StayPut(key id, integer rank)
{
    if(leasher != NULL_KEY)
    {
        llParticleSystem([]);
        leasher = NULL_KEY;
    }
    lastrank = rank;
    stay = TRUE;
    pos = llGetPos();
    llTargetRemove(targethandle);
    llMoveToTarget(pos,0.1);
    llInstantMessage(id,"You commanded " + llKey2Name(llGetOwner()) + " to stay in place, to allow to move again, either leash the slave with the grab command or use unstay to enable movement again.");
    llOwnerSay(llKey2Name(id) + " commanded you to stay in place, you cannot move until the command is revoked again.");
}

Unleash()
{
    llStopMoveToTarget();
    danglecount = -1;
    llListenRemove(listenhandle);
    llTargetRemove(targethandle);
    llParticleSystem([]);
    leasher = NULL_KEY;
}

LeashParticles()
{
    //send stream of particles toward target
    key target = part_target;
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
default
{
    state_entry()
    {
        Unleash();
        llSleep(1.0);
        llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + submenu, NULL_KEY);            
    }
    
    on_rez(integer param)
    {
        llResetScript();
    }
    
    link_message(integer sender, integer auth, string str, key id)
    {
        //only respond to owner, secowner, group, wearer
        if (auth >= COMMAND_OWNER && auth <= COMMAND_WEARER)
        {
            list params = llParseString2List(str, [" "], []);
            if (str == "grab" || str == "leash")
            {
                if (leasher != NULL_KEY && auth <= lastrank)
                {
                //if leashed, only move leash if commander's authority greater than current leasher's
                    Leash(id, auth);
                }
                else
                {
                //if unleashed, then leash if commander authorized, only owner, secowner, and group may "grab"
                    if (auth >= COMMAND_OWNER && auth <= COMMAND_GROUP)
                        Leash(id, auth);
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
            else if (str == "unleash")
            {             
                //allow if from leasher or someone outranking them
                if (id == leasher || auth <= lastrank)
                    Unleash();
            }
            else if (str == "yank" && id == leasher)
            {
                vector dest = (vector)llList2String(llGetObjectDetails(leasher, [OBJECT_POS]), 0);
                llMoveToTarget(dest, 0.5);
                llSleep(2.0);
                llStopMoveToTarget();
            }
            else if (llList2String(params, 0) == "length")
            {
                float newlength = (float)llList2String(params, 1);
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
            else if (str == "reset")
            {
                if (auth == COMMAND_WEARER || auth == COMMAND_OWNER)
                {   //only owner and wearer may reset
                    llResetScript();
                }
            }
            else if (str == "post")
            {
                if (auth >= COMMAND_OWNER && auth <= COMMAND_GROUP)
                    menuuser = id;
                    llSensor("", NULL_KEY, SCRIPTED, scanrange, PI);
            }
            else if(llList2String(params, 0) == "post")
            {
                if (auth <= lastrank || lastrank == 0)
                {
                    Leash2Post((key)llList2String(params, 1),auth);
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
                if (auth <= lastrank)
                {
                    stay = FALSE;
                    llOwnerSay("You are free to move again.");
                    llStopMoveToTarget();
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
                    LeashParticles();
                }
                else if (auth < lastrank)
                {   //people outranking the leasher can change texture
                    SetTexture(str);
                    LeashParticles();
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
    }

    sensor(integer num)
    {
        postbuttons = [];
        postprompt = "Pick the object on which you want the sub to be leashed to.  If it's not in the list, have the sub move closer and try again.\n";
        postkeys = [];
        //give menuuser a list of things to choose from, loop the list off at 12 so we don't need multipage menu
        if (num > 12)
            num = 12;
        integer n;
        for (n = 0; n < num; n ++)
        {
            string name = llDetectedName(n);
            if(name != "Object")
            {
                postbuttons += [(string)(n + 1)];
                postprompt += "\n" + (string)(n + 1) + " - " + name;
                postkeys += [llDetectedKey(n)];
            }
        }
        postbuttons = RestackMenu(FillMenu(postbuttons));
        menuchannel = -(integer)llFrand(999950.0) + 30;
        postlistener = llListen(menuchannel, "", menuuser, "");
        menucount = 60;
        llSetTimerEvent(1.0);
        currentmenu = "post";
        llDialog(menuuser, postprompt, postbuttons, menuchannel);
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
                LeashParticles();
            }
        }
        else if(llKey2Name(leash_holder) != "")
        {
            part_target = leash_holder;
            LeashParticles();
        }        
//        danglecount = 0;
    }
    timer()
    {
        if(leasher != NULL_KEY)
        {
            vector newpos = llList2Vector(llGetObjectDetails(leasher,[OBJECT_POS]),0);
            //if the leasher is gone we remove the target
            if(!isInSim(newpos) && danglecount == -1)
            {
                llTargetRemove(targethandle);
                llParticleSystem([]);
                danglecount = 120;
            }
            else if(isInSim(newpos) && danglecount != -1)
            {
                LeashParticles();
                llTargetRemove(targethandle);
                targethandle = llTarget(newpos, length);
                llMoveToTarget(newpos, 1.0);
                danglecount = -1;
            }
//            if(leasher != part_target)
//            {
//                if(llKey2Name(part_target) == "")
//                {
//                    part_target = leasher;
//                    LeashParticles();
//                }
//            }
//            else if(llKey2Name(leash_holder) != "")
//            {
//                part_target = leash_holder;
//                LeashParticles();
//            }
        }
        if((!menucount && !danglecount) || (!menucount && danglecount == -1) || (menucount == -1 && !danglecount))
        {
//            llOwnerSay((string)danglecount + (string)menucount);
            llSetTimerEvent(0.0);
        }
        if(!danglecount)
        {
            danglecount = -1;
//            llTargetRemove(targethandle);
//            llParticleSystem([]);
        }
        else if(danglecount > 0)
            danglecount--;
        if(!menucount)
        {
            menucount = -1;
            llListenRemove(menulistener);
        }
        else if(menucount > 0)
            menucount--;
    }
    not_at_target()
    {
        if(stay)
        {
            llMoveToTarget(pos,0.1);
        }
        else
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
                    LeashParticles();
                }
            }
            else if(llKey2Name(leash_holder) != "")
            {
                part_target = leash_holder;
                LeashParticles();
            }
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
                    LeashParticles();
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
                LeashParticles();            
            }
        }
        else if(channel == menuchannel)
        {
            llListenRemove(menulistener);
            if(message == L_LENGTH)
                LengthMenu(id);
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
            else if(currentmenu == "post")
            {
                integer postnum = (integer)message - 1;
                llMessageLinked(LINK_THIS, COMMAND_NOAUTH, "post " + llList2String(postkeys, postnum), id);
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
}