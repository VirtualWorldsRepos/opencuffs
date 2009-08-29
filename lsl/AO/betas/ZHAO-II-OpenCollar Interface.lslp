//Nandana Singh mod for OpenCollar compatibility.

// ZHAO-II-interface - Ziggy Puff, 06/07

////////////////////////////////////////////////////////////////////////
// Interface script - handles all the UI work, sends link
// messages to the ZHAO-II 'engine' script
//
// Interface definition: The following link_message commands are
// handled by the core script. All of these are sent in the string
// field. All other fields are ignored
//
// ZHAO_RESET                          Reset script
// ZHAO_LOAD|<notecardName>            Load specified notecard
// ZHAO_NEXTSTAND                      Switch to next stand
// ZHAO_STANDTIME|<time>               Time between stands. Specified
//                                     in seconds, expects an integer.
//                                     0 turns it off
// ZHAO_AOON                           AO On
// ZHAO_AOOFF                          AO Off
// ZHAO_SITON                          Sit On
// ZHAO_SITOFF                         Sit Off
// ZHAO_RANDOMSTANDS                   Stands cycle randomly
// ZHAO_SEQUENTIALSTANDS               Stands cycle sequentially
// ZHAO_SETTINGS                       Prints status
// ZHAO_SITS                           Select a sit
// ZHAO_GROUNDSITS                     Select a ground sit
// ZHAO_WALKS                          Select a walk
//



// Added for OCCuffs:
// ZHAO_PAUSE                           Stops the AO temporary, AO gets reactivated on next rez if needed
// ZHAO_UNPAUSE                         Restart the AO if it was paused
// End of add OCCuffs




// So, to send a command to the ZHAO-II engine, send a linked message:
//
//   llMessageLinked(LINK_SET, 0, "ZHAO_AOON", NULL_KEY);
//
////////////////////////////////////////////////////////////////////////

// Ziggy, 07/16/07 - Single script to handle touches, position changes, etc., since idle scripts take up
//
// Ziggy, 06/07:
//          Single script to handle touches, position changes, etc., since idle scripts take up
//          scheduler time
//          Tokenize notecard reader, to simplify notecard setup
//          Remove scripted texture changes, to simplify customization by animation sellers

// Fennec Wind, January 18th, 2007:
//          Changed Walk/Sit/Ground Sit dialogs to show animation name (or partial name if too long)
//          and only show buttons for non-blank entries.
//          Fixed minor bug in the state_entry, ground sits were not being initialized.
//

// Dzonatas Sol, 09/06: Fixed forward walk override (same as previous backward walk fix).


// Based on Francis Chung's Franimation Overrider v1.8

// This program is free software; you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation; either version 2 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307, USA.

// CONSTANTS
//////////////////////////////////////////////////////////////////////////////////////////////////////////

// integer disabled = FALSE;//used to prevent manually turning AO on when collar has turned it off
// key disabler;//the key of th eobject that turned us off.  will be needed for a workaround later

// Help notecard
string helpNotecard = "READ ME FIRST- OpenCollar Sub AO";

// How long before flipping stand animations
integer standTimeDefault = 30;

// Listen channel for pop-up menu...
// should be different from channel used by ZHAO engine (-91234)
integer listenChannel = -91235;

integer listenHandle;                          // Listen handlers - only used for pop-up menu, then turned off
integer listenState = 0;                       // What pop-up menu we're handling now

// Overall AO state
integer zhaoOn = TRUE;

list attachPoints = [
    ATTACH_HUD_TOP_RIGHT,
    ATTACH_HUD_TOP_CENTER,
    ATTACH_HUD_TOP_LEFT,
    ATTACH_HUD_BOTTOM_RIGHT,
    ATTACH_HUD_BOTTOM,
    ATTACH_HUD_BOTTOM_LEFT
        ];

// For the on/off (root) prim
list rootPrimOffsets = [
    <0.0,  0.025, -0.05>,    // Top right
    <0.0,  0.025, -0.05>,    // Top middle
    <0.0, -0.025, -0.05>,    // Top left
    <0.0,  0.025,  0.10>,    // Bottom right
    <0.0,  0.00,  0.10>,    // Bottom middle
    <0.0, -0.025,  0.10>    // Bottom left
        ];

// For the menu (child)
list menuPrimOffsets = [
    <0.0, 0.0, -0.057>,
    <0.0, -0.057, 0.0>,
    <0.0, 0.0, -0.057>,
    <0.0, 0.0,  0.057>,
    <0.0, 0.0,  0.057>,
    <0.0, 0.0,  0.057>
        ];

// For the SitAnywhere Button (child)
list sitAWPrimOffsets = [
    <0.0, 0.0, -0.114>,
    <0.0, -0.114, 0.0>,
    <0.0, 0.0, -0.114>,
    <0.0, 0.0,  0.114>,
    <0.0, 0.0,  0.114>,
    <0.0, 0.0,  0.114>
        ];

vector onColor = <1.0, 1.0, 1.0>;
vector offColor = <0.5, 0.5, 0.5>;

string AO_LOCKED = "773b306e-f344-ef87-b911-4d961bc8a38b"; //AO locked texture
string AO_UNLOCKED = "7d57bca0-90ee-466a-cead-602d85754fb1"; //standard AO menu texture

// Interface script now keeps track of these states. The defaults
// match what the core script starts out with
integer sitOverride = TRUE;
integer sitAnywhere = FALSE;
integer StandAO = TRUE; // store state of standing ao
integer randomStands = FALSE;

//Left here for backwards compatiblity... to be removed sooner than later
integer collarchannel = -782690;
integer oldCollarHandle;

key Owner = NULL_KEY;

integer collarIntegration;
integer isLocked = FALSE;
string UNLOCK = "*unlock*";
string LOCK = "*lock*";

string COLLAR_OFF = "NoCollar";
string COLLAR_ON = "CollarInt";


//Added for the collar auth system:
integer COMMAND_NOAUTH = 0;
integer COMMAND_AUTH = 42; //used to send authenticated commands to be executed in the core script
integer COMMAND_COLLAR = 499; //added for collar or cuff commands to put ao to pause or standOff and SAFEWORD
integer COMMAND_OWNER = 500;
integer COMMAND_SECOWNER = 501;
integer COMMAND_GROUP = 502;
integer COMMAND_WEARER = 503;
integer COMMAND_EVERYONE = 504;
integer COLLAR_INT_REQ = 610;
integer COLLAR_INT_REP = 611;
integer COMMAND_UPDATE = 10001;

//need to detect RLV for locking...
integer rlvChannel = 1904204;
integer rlvHandle;
integer rlvDetected;
key lockerID;

// CODE
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// Initialize listeners, and reset some status variables
Initialize() {
    Owner = llGetOwner();
    //check for rlv
    rlvHandle = llListen(rlvChannel, "", Owner, "");
    llOwnerSay("@version=" + (string)rlvChannel);
    llSetTimerEvent(10.0);
    SetListener(Owner);
}

DoMenu(key rcpt)
{
    // The rows are inverted in the actual dialog box. This must match
    // the checks in the listen() handler
    list mainMenu = ["Sit On/Off","Load",">", "Settings", "Next Stand","Help", "Reset", "Update"];
    string prompt = "Please select an option:\n";
    prompt += "To have the AO intergrated with OpenCollar work properly you need an OpenCollar Version 3.236 or higher.\nCollarIntegration is currently: ";
    //new for locking feature 
    if(collarIntegration)
    {
        prompt += "ON";
        
        //mainMenu += [COLLAR_OFF];
        if (isLocked)
        {
            mainMenu += [UNLOCK];
        }
        else
        {
            mainMenu += [LOCK];
        }
        
    }
    else
    {
        prompt += "OFF";
        //mainMenu += [COLLAR_ON];
    }
    if (sitAnywhere)
    {
        mainMenu += ["SitAnyOFF"];
    }
    else
    {
        mainMenu += ["SitAnyON"];
    }
    if (zhaoOn)
    {
        mainMenu += ["AO OFF"];
    }
    else
    {
        mainMenu += ["AO ON"];
    }
    listenState = 0;
    llListenControl(listenHandle, TRUE);
    llDialog( rcpt, prompt, mainMenu, listenChannel );
}
DoSecMenu(key id)
{
    list buttons = ["<", "Walks", "Sits", "Ground Sits", "Rand/Seq", "Stand Time"];
    listenState = 0;
    llListenControl(listenHandle, TRUE);
    llDialog( id, "Please select an option:", buttons, listenChannel );
}

DoPosition()
{
    // Using 2 for the child prim's link number... if you
    // want to add prims that need to be moved, you'll
    // have to do work here

    integer position = llListFindList(attachPoints, [llGetAttached()]);
    if (position != -1) {
        llSetPos((vector)llList2String(rootPrimOffsets, position));
        llSetLinkPrimitiveParams(2, [PRIM_POSITION, (vector)llList2String(menuPrimOffsets, position)]);
        llSetLinkPrimitiveParams(3, [PRIM_POSITION, (vector)llList2String(sitAWPrimOffsets, position)]);
    }
}

TurnOn()
{
    zhaoOn = TRUE;
    llMessageLinked(LINK_SET, COMMAND_AUTH, "ZHAO_AOON", "");
    llSetColor(onColor, ALL_SIDES);
}

TurnOff()
{
    llSetColor(offColor, ALL_SIDES);
    if (sitAnywhere)
    {
        ToggleSitAnywhere();
    }
    zhaoOn = FALSE;
    llSetLinkColor(3, offColor, ALL_SIDES);
    llMessageLinked(LINK_THIS, COMMAND_AUTH, "ZHAO_AOOFF", "");
}

ToggleSitAnywhere()
{
    if (!StandAO)
    {
        llOwnerSay("SitAnywhere is not possible while you are in a collar pose.");
        return; // only allow changed if StandAO is enabled
    }
    if (zhaoOn)
    {
        if (sitAnywhere == TRUE) 
        {
            llSetLinkColor(3, offColor, ALL_SIDES);
            llMessageLinked(LINK_THIS, COMMAND_AUTH, "ZHAO_SITANYWHERE_OFF", NULL_KEY);
        } 
        else 
        {
            llSetLinkColor(3, onColor, ALL_SIDES);
            llMessageLinked(LINK_THIS, COMMAND_AUTH, "ZHAO_SITANYWHERE_ON", NULL_KEY);
        }
        sitAnywhere = !sitAnywhere;
    }
}

SetListener(key speaker)
{
    //randomize listenchannel to prevent crosstalk
    listenChannel = llRound(llFrand(999999) + 1);
    // On init, open a new listener...
    if ( listenHandle )
        llListenRemove( listenHandle );
    listenHandle = llListen( listenChannel, "", speaker, "" );
    // ... And turn it off
    llListenControl(listenHandle, FALSE);
    //Left here for backwards compatiblity to be removed more sooner than later....
    llListen(collarchannel, "", NULL_KEY, "");
}

integer isAttachedToHUD()
{
    if (llGetAttached() > 30)
    {
        return TRUE;
    }
    else
    {
        return FALSE;
    }
}


Notify(key id, string msg, integer alsoNotifyWearer) {
    if (id == Owner) {
        llOwnerSay(msg);
    } else {
        llInstantMessage(id,msg);
        if (alsoNotifyWearer) {
            llOwnerSay(msg);
        }
    }    
}

// STATE
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

debug(string str)
{
    //llOwnerSay(llGetScriptName() + "-Debug: " + str);
}

default {
    state_entry() {
        integer i;
        Initialize();
        DoPosition();

        // Sleep a little to let other script reset (in case this is a reset)
        llSleep(2.0);

        // We start out as AO ON
        TurnOn();
        //sit anywhere OFF by default
        llMessageLinked(LINK_THIS, COMMAND_AUTH, "ZHAO_SITANYWHERE_OFF", NULL_KEY);
        sitAnywhere = FALSE;
    }

    on_rez( integer _code ) {
        Initialize();
        if (isLocked)
            {
                if (rlvDetected)
                {
                    llOwnerSay("@detach=n");
                }
            }
    }

    link_message(integer sender, integer num, string str, key id)
    {
        debug("lnkMsg: " + str + " auth=" + (string)num + "id= " + (string)id);
        if (num >= COMMAND_OWNER && num <= COMMAND_WEARER)
        {
            if (isLocked && num == COMMAND_WEARER)
            {
                Notify(id, "You cannot change the AO while it is locked. You could use your collar's safeword which will also unlock the AO.", FALSE);
                return;
            }
            else if (str == "ZHAO_AOON")
            {
                //make sure button is bright, on is TRUE
                TurnOn();
            }
            else if (str == "ZHAO_AOOFF")
            {
                TurnOff();
            }
            else if (str == "ZHAO_MENU")
            {
                SetListener(id);
                DoMenu(id);
            }
            else if (str == "ZHAO_LOCK")
            {
                if(num >= COMMAND_OWNER && num <= COMMAND_WEARER && collarIntegration)
                {
                    isLocked = TRUE;
                    if (rlvDetected)
                    {
                        llOwnerSay("@detach=n");
                    }
                    lockerID = id;
                    Notify(id, "The AO has been locked.", TRUE);
                    llSetLinkTexture(2, AO_LOCKED, ALL_SIDES);
                }
                else if (!collarIntegration)
                {
                    Notify(id, "The AO can only be locked if Collar Integration is turned on.", FALSE);
                }
                else
                {
                    Notify(id, "Only the Owner can lock the AO.", FALSE);
                }
            }
            else if (str == "ZHAO_UNLOCK")
            {
                if (num == COMMAND_OWNER)
                {
                    isLocked = FALSE;
                    if (rlvDetected)
                    {
                        llOwnerSay("@detach=y");
                    }
                    Notify(id, "The AO has been unlocked.", TRUE);
                    llSetLinkTexture(2, AO_UNLOCKED, ALL_SIDES);
                }
                else
                {
                    Notify(id, "Only the Owner can unlock the AO.", FALSE);
                }
            }
        }
        else if (num == COLLAR_INT_REP)
        {
            if (id == NULL_KEY && str == "CollarOn")
            {
                llOwnerSay("I could not detect a compatible OpenCollar, full Collar Intergration not possible. OpenCollar 3.3 or higher is required.");
            }
            else if (str == "CollarOn")
            {
                collarIntegration = TRUE;
                llOwnerSay("Collar found full Collar Integration on.");
            }
            else if (str == "CollarOff")
            {
                collarIntegration = FALSE;
                llOwnerSay("Collar not found full Collar Integration off.");
            }
        }
        else if (num == COMMAND_COLLAR && str == "safeword")
        {
            if (isLocked)
            {
                isLocked = FALSE;
                if (rlvDetected)
                {
                    llOwnerSay("@detach=y");
                }
                Notify(id, "The AO has been unlocked due to safeword usage.", TRUE);
                llSetLinkTexture(2, AO_UNLOCKED, ALL_SIDES);
            }
        }
    }

    touch_start( integer _num ) 
    {//ignore touches when attached not at the hud and touches by others but the wearer
        
        if( (isAttachedToHUD() || llGetAttached() ) && ( llDetectedKey(0) == Owner) ) 
        {
            string message = "";
            if (llDetectedLinkNumber(0) == 2) 
            {   // Menu prim... use number instead of name
                //DoMenu();
                message = "ZHAO_MENU";
            } 
            else if (llDetectedLinkNumber(0) == 3) 
            {
                if (!isLocked)
                {
                    ToggleSitAnywhere();
                }
            }
            else if (zhaoOn) 
            {
                message = "ZHAO_AOOFF";
            } 
            else
            {
                message = "ZHAO_AOON";
            }
            if (isLocked)
            {
                if (message == "")
                {
                    message == "SitAny";
                }
                llMessageLinked(LINK_THIS, COMMAND_NOAUTH, message, Owner);
            }
            else if (message != "")
            {
                llMessageLinked(LINK_THIS, COMMAND_OWNER, message, Owner);
            }
        }
        else if (!llGetAttached() && llDetectedKey(0) == Owner)
        {
            llMessageLinked(LINK_THIS, COMMAND_OWNER, "ZHAO_MENU", Owner);
        }
    }

    listen( integer _channel, string _name, key _id, string _message) {
        if (_channel == listenChannel)
        {
            // Turn listen off. We turn it on again if we need to present
            // another menu
            llListenControl(listenHandle, FALSE);

            if ( _message == "Help" ) 
            {
                if (llGetInventoryType(helpNotecard) == INVENTORY_NOTECARD)
                    llGiveInventory(_id, helpNotecard);
                else
                    llOwnerSay("No help notecard found.");
            }
            else if (_message == "Update")
            {
                llMessageLinked(LINK_THIS, COMMAND_UPDATE, "Update", _id);
            }
            else if (_message == "AO ON")
            {
                llMessageLinked(LINK_THIS, COMMAND_NOAUTH, "ZHAO_AOON", _id);
            }
            else if (_message == "AO OFF")
            {
                llMessageLinked(LINK_THIS, COMMAND_NOAUTH, "ZHAO_AOOFF", _id);
            }
            else if ( _message == "Reset" ) 
            {
                llMessageLinked(LINK_THIS, COMMAND_AUTH, "ZHAO_RESET", NULL_KEY);
                llSleep(1.0);
                llResetScript();
            }
            else if ( _message == "Settings" ) 
            {
                llMessageLinked(LINK_THIS, COMMAND_AUTH, "ZHAO_SETTINGS", _id);
            }
            else if ( _message == "Sit On/Off" ) 
            {
                if (sitOverride == TRUE) 
                {
                    llMessageLinked(LINK_THIS, COMMAND_AUTH, "ZHAO_SITOFF", _id);
                    sitOverride = FALSE;
                } 
                else 
                {
                    llMessageLinked(LINK_THIS, COMMAND_AUTH, "ZHAO_SITON", _id);
                    sitOverride = TRUE;
                }
            }
            else if ( _message == "SitAnyON" || _message == "SitAnyOFF" ) 
            {
                //toggleSitAnywhere() by Marcus Gray
                ToggleSitAnywhere();
            }
            else if ( _message == "Rand/Seq" ) 
            {
                if (randomStands == TRUE) 
                {
                    llMessageLinked(LINK_THIS, COMMAND_AUTH, "ZHAO_SEQUENTIALSTANDS", _id);
                    randomStands = FALSE;
                } 
                else 
                {
                    llMessageLinked(LINK_THIS, COMMAND_AUTH, "ZHAO_RANDOMSTANDS", _id);
                    randomStands = TRUE;
                }
            }
            else if ( _message == "Next Stand" ) 
            {
                llMessageLinked(LINK_THIS, COMMAND_AUTH, "ZHAO_NEXTSTAND", _id);
            }
            else if ( _message == "Load" ) 
            {
                integer n = llGetInventoryNumber( INVENTORY_NOTECARD );
                // Can only have 12 buttons in a dialog box
                if ( n > 12 ) {
                    llOwnerSay( "You cannot have more than 12 animation notecards." );
                    return;
                }

                integer i;
                list animSets = [];

                // Build a list of notecard names and present them in a dialog box
                for ( i = 0; i < n; i++ ) {
                    string notecardName = llGetInventoryName( INVENTORY_NOTECARD, i );
                    if ( notecardName != helpNotecard )
                        animSets += [ notecardName ];
                }

                llListenControl(listenHandle, TRUE);
                llDialog( _id, "Select the notecard to load:", animSets, listenChannel );
                listenState = 1;
            }
            else if ( _message == "Stand Time" ) 
            {
                // Pick stand times
                list standTimes = ["0", "5", "10", "15", "20", "30", "40", "60", "90", "120", "180", "240"];
                llListenControl(listenHandle, TRUE);
                llDialog( _id, "Select stand cycle time (in seconds). \n\nSelect '0' to turn off stand auto-cycling.",
                    standTimes, listenChannel);
                listenState = 2;
            }
            else if ( _message == "Sits" ) 
            {
                llMessageLinked(LINK_THIS, COMMAND_AUTH, "ZHAO_SITS", _id);
            }
            else if ( _message == "Walks" ) 
            {
                llMessageLinked(LINK_THIS, COMMAND_AUTH, "ZHAO_WALKS", _id);
            }
            else if ( _message == "Ground Sits" ) 
            {
                llMessageLinked(LINK_THIS, COMMAND_AUTH, "ZHAO_GROUNDSITS", _id);
            }
            //added for lock
            else if ( _message == LOCK || _message == UNLOCK)
            {
                if (_message == LOCK)
                {
                    llMessageLinked(LINK_THIS, COMMAND_NOAUTH, "ZHAO_LOCK", _id);
                }
                else
                {
                    llMessageLinked(LINK_THIS, COMMAND_NOAUTH, "ZHAO_UNLOCK", _id);
                }
            }
            else if (_message == ">")
            {
                DoSecMenu(_id);
            }
            else if (_message == "<")
            {
                DoMenu(_id);
            }
            /*
            else if (_message == COLLAR_ON)
            {
                if (_id == Owner)
                {
                    llMessageLinked(LINK_THIS, COLLAR_INT_REQ, "CollarOn", "");
                }
                else
                {
                    llInstantMessage(_id, "Sorry only the AO wearer can toggle the Collar integration on or off.");
                }
            }
            else if(_message == COLLAR_OFF)
            {
                if (_id == Owner)
                {
                    llMessageLinked(LINK_THIS, COLLAR_INT_REQ, "CollarOff", "");
                }
                else
                {
                    llInstantMessage(_id, "Sorry only the AO wearer can toggle the Collar integration on or off.");
                }
            }
            */
            else if ( listenState == 1 ) 
            {
                // Load notecard
                llMessageLinked(LINK_THIS, COMMAND_AUTH, "ZHAO_LOAD|" + _message, _id);
            }
            else if ( listenState == 2 ) 
            {
                // Stand time change
                llMessageLinked(LINK_THIS, COMMAND_AUTH, "ZHAO_STANDTIME|" + _message, _id);
            }
        }
        //Left here for backwards compatiblity... to be removed sooner than later
        else if (_channel == collarchannel)
        {
            //only accept commands from owner's objects,
            //or from the object that disabled us
            //this is needed because the collar sends a ZHAO_STANDON message when it detaches
            //but because it's no longer rezzed, llgetownerkey doesn't work
            if (llGetOwnerKey(_id) == Owner)
            {
                list params = llParseString2List(_message, ["|"], []);
                string command = llList2String(params, 0);
                string userID = llList2String(params, 1);
                // Added for OCCuffs
                //else 
                if (_message == "ZHAO_PAUSE")
                {
                    llMessageLinked(LINK_THIS, COMMAND_COLLAR, _message, NULL_KEY);
                }
                else if (_message == "ZHAO_UNPAUSE")
                {
                    llMessageLinked(LINK_THIS, COMMAND_COLLAR, _message, NULL_KEY);
                }
                // End of change
                else if (_message == "ZHAO_STANDOFF")
                {
                    if (sitAnywhere) ToggleSitAnywhere(); // SitAnyWhere is On, so disable it first
                    StandAO=FALSE; // and store that we are in off mode
                    llMessageLinked(LINK_SET, COMMAND_COLLAR, _message, NULL_KEY);
                }
                else if (_message == "ZHAO_STANDON")
                {
                    StandAO=TRUE; // set state of Stand AO to TRUE
                    llMessageLinked(LINK_THIS, COMMAND_COLLAR, _message, NULL_KEY);
                }
                else if (_message == "ZHAO_AOSHOW")
                {
                    if(!isAttachedToHUD())
                    {
                        llSetLinkAlpha(LINK_SET, 1.0, ALL_SIDES);
                    }
                }
                else if (_message == "ZHAO_AOHIDE")
                {
                    if(!isAttachedToHUD())
                    {
                        llSetLinkAlpha(LINK_SET, 0.0, ALL_SIDES);
                    }
                    else
                    {
                        llOwnerSay("You can only hide the AO when it is not attached to the HUD.");
                    }
                }
                else
                {
                    if (!collarIntegration)
                    {
                        llMessageLinked(LINK_SET, COMMAND_OWNER, command, (key)userID);
                    }
                }
            }
        }
        else if (_channel == rlvChannel)
        {
            llListenRemove(rlvHandle);
            llSetTimerEvent(0.0);
            if (llGetSubString(_message, 0, 20)  == "RestrainedLife viewer")
            {
                rlvDetected = TRUE;
            }
        }
    }
    timer()
    {
        llListenRemove(rlvHandle);
        llSetTimerEvent(0.0);
    }
    
    attach( key _k ) {
        if ( _k != NULL_KEY )
        {
            if( isAttachedToHUD() )
            {
                llSetLinkAlpha(LINK_SET, 1.0, ALL_SIDES);
                DoPosition();
            }
            else
            {
                llSetLinkAlpha(LINK_SET, 0.0, ALL_SIDES);
            }
            if (isLocked)
            {
                Notify(lockerID, llKey2Name(Owner) + " has attached the AO again after it was detached while locked.", TRUE);
            }
            
        }
        else
        {
            if (isLocked)
            {
                Notify(lockerID, llKey2Name(Owner) + " has detached the AO while it was locked.", TRUE);
            }
        }
    }
}

