// ZHAO-II-core - Ziggy Puff, 07/07

/////////////////////////////////////////////////////////////////////////////////////////////////////
// Main engine script - receives link messages from any interface script. Handles the core AO work
//
// Interface definition: The following link_message commands are handled by this script. All of 
// these are sent in the string field. All other fields are ignored
//
// ZHAO_RESET                          Reset script
// ZHAO_LOAD|<notecardName>            Load specified notecard
// ZHAO_NEXTSTAND                      Switch to next stand
// ZHAO_STANDTIME|<time>               Time between stands. Specified in seconds, expects an integer.
//                                     0 turns it off
// ZHAO_AOON                           AO On
// ZHAO_AOOFF                          AO Off
// ZHAO_STANDON                        Stand On  //added by Nandana Singh
// ZHAO_STANDOFF                       Stand Off //added by Nandana Singh
// ZHAO_SITON                          Sit On
// ZHAO_SITOFF                         Sit Off
// ZHAO_RANDOMSTANDS                   Stands cycle randomly
// ZHAO_SEQUENTIALSTANDS               Stands cycle sequentially
// ZHAO_SETTINGS                       Prints status
// ZHAO_SITS                           Select a sit
// ZHAO_GROUNDSITS                     Select a ground sit
// ZHAO_WALKS                          Select a walk
//
// ZHAO_SITANYWHERE_ON                 Sit Anywhere mod On //added to OC sub AO hud by melanie Burnstein
// ZHAO_SITANYWHERE_OFF                Sit Anywhere mod Off //added to OC sub AO hud by melanie Burnstein




// Added for OCCuffs:
// ZHAO_PAUSE                           Stops the AO temporary, AO gets reactivated on next rez if needed
// ZHAO_UNPAUSE                         Restart the AO if it was paused
// End of add OCCuffs




//
// So, to send a command to the ZHAO-II engine, send a linked message:
//
//   llMessageLinked(LINK_SET, 0, "ZHAO_AOON", NULL_KEY);
//
// This script uses a listener on channel -91234. If other scripts are added to the ZHAO, make sure 
// they don't use the same channel
/////////////////////////////////////////////////////////////////////////////////////////////////////

/////////////////////////////////////////////////////////////////////////////////////////////////////
// New notecard format
//
/////////////////////////////////////////////////////////////////////////////////////////////////////
// Lines starting with a / are treated as comments and ignored. Blank lines are ignored. Valid lines 
// look like this:
//
// [ Walking ]SexyWalk1|SexyWalk2|SexyWalk3
//
// The token (in this case, [ Walking ]) identifies the animation to be overridden. The rest is a 
// list of animations, separated by the '|' (pipe) character. You can specify multiple animations 
// for Stands, Walks, Sits, and GroundSits. Multiple animations on any other line will be ignored. 
// You can have up to 12 animations each for Walks, Sits and GroundSits. There is no hard limit 
// on the number of stands, but adding too many stands will make the script run out of memory and 
// crash, so be careful. You can repeat tokens, so you can split the Stands up across multiple lines. 
// Use the [ Standing ] token in each line, and the script will add the animation lists together.
//
// Advanced: Each 'animation name' can be a comma-separated list of animations, which will be played 
// together. For example:
//
// [ Walking ]SexyWalk1UpperBody,SexyWalk1LowerBody|SexyWalk2|SexyWalk3
//
// Note the ',' between SexyWalk1UpperBody and SexyWalk1LowerBody - this tells ZHAO-II to treat these 
// as a single 'animation' and play them together. The '|' between this 'animation' and SexyWalk2 tells 
// ZHAO-II to treat SexyWalk2 and SexyWalk3 as separate walk animations. You can use this to layer 
// animations on top of each other.
//
// Do not add any spaces around animation names!!!
//
// The token can be one of the following:
//
// [ Standing ]
// [ Walking ]
// [ Sitting ]
// [ Sitting On Ground ]
// [ Crouching ]
// [ Crouch Walking ]
// [ Landing ]
// [ Standing Up ]
// [ Falling ]
// [ Flying Down ]
// [ Flying Up ]
// [ Flying ]
// [ Flying Slow ]
// [ Hovering ]
// [ Jumping ]
// [ Pre Jumping ]
// [ Running ]
// [ Turning Right ]
// [ Turning Left ]
// [ Floating ]
// [ Swimming Forward ]
// [ Swimming Up ]
// [ Swimming Down ]
//
/////////////////////////////////////////////////////////////////////////////////////////////////////

// Ziggy, 07/16/07 - Warning instead of error on 'no animation in inventory', that way SL's built-in
//                   anims can be used
//
// Ziggy, 07/14/07 - 2 bug fixes. Listens aren't being reset on owner change, and a typo in the 
//                   ground sit animation code
//
// Ziggy, 06/07:
//          Reduce script count, since idle scripts take up scheduler time
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
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Default notecard we read on script_entry
string defaultNoteCard = "Default";

// List of all the animation states
list animState = [ "Sitting on Ground", "Sitting", "Striding", "Crouching", "CrouchWalking",
                   "Soft Landing", "Standing Up", "Falling Down", "Hovering Down", "Hovering Up",
                   "FlyingSlow", "Flying", "Hovering", "Jumping", "PreJumping", "Running",
                   "Turning Right", "Turning Left", "Walking", "Landing", "Standing" ];

// Animations in which we automatically disable animation overriding
// Try to keep this list short, the longer it is the worse it affects our runtime
// (Note: This is *almost* constant. We have to type-convert this to keys instead of strings
// on initialization - blargh)
list autoDisableList = [
    "3147d815-6338-b932-f011-16b56d9ac18b", // aim_R_handgun
    "ea633413-8006-180a-c3ba-96dd1d756720", // aim_R_rifle
    "b5b4a67d-0aee-30d2-72cd-77b333e932ef", // aim_R_bazooka
    "46bb4359-de38-4ed8-6a22-f1f52fe8f506", // aim_l_bow
    "9a728b41-4ba0-4729-4db7-14bc3d3df741", // Launa's hug
    "f3300ad9-3462-1d07-2044-0fef80062da0", // punch_L
    "c8e42d32-7310-6906-c903-cab5d4a34656", // punch_r
    "85428680-6bf9-3e64-b489-6f81087c24bd", // sword_strike_R
    "eefc79be-daae-a239-8c04-890f5d23654a"  // punch_onetwo
];

// Logic change - we now have a list of tokens. The 'overrides' list is the same length as this, 
// i.e. it has one entry per token, *not* one entry per animation. Multiple options for a token 
// are stored as | separated strings in a single list entry. This was done to save memory, and 
// allow a larger number of stands etc. All the xxxIndex variables now refer to the token index, 
// since that's how long 'overrides' is.

// List of internal tokens. This *must* be in the same sequence as the animState list. Note that
// we combine some tokens after the notecard is read (striding/walking, landing/soft landing), etc.
// The publicized tokens list only contains one entry for each pair, but we'll accept both, and
// combine them later
list tokens = [
    "[ Sitting On Ground ]",    // 0
    "[ Sitting ]",              // 1
    "",                         // 2 - We don't allow Striding as a token
    "[ Crouching ]",            // 3
    "[ Crouch Walking ]",       // 4
    "",                         // 5 - We don't allow Soft Landing as a token
    "[ Standing Up ]",          // 6
    "[ Falling ]",              // 7
    "[ Flying Down ]",          // 8
    "[ Flying Up ]",            // 9
    "[ Flying Slow ]",          // 10
    "[ Flying ]",               // 11
    "[ Hovering ]",             // 12
    "[ Jumping ]",              // 13
    "[ Pre Jumping ]",          // 14
    "[ Running ]",              // 15
    "[ Turning Right ]",        // 16
    "[ Turning Left ]",         // 17
    "[ Walking ]",              // 18
    "[ Landing ]",              // 19
    "[ Standing ]",             // 20
    "[ Swimming Down ]",        // 21
    "[ Swimming Up ]",          // 22
    "[ Swimming Forward ]",     // 23
    "[ Floating ]"              // 24
];

// The tokens for which we allow multiple animations
list multiAnimTokenIndexes = [
    0,  // "[ Sitting On Ground ]"
    1,  // "[ Sitting ]"
    18, // "[ Walking ]"
    20  // "[ Standing ]"
];

// Index of interesting animations
integer noAnimIndex     = -1;
integer sitgroundIndex  = 0;
integer sittingIndex    = 1;
integer stridingIndex   = 2;
integer standingupIndex = 6;
integer hoverdownIndex  = 8;
integer hoverupIndex    = 9;
integer flyingslowIndex = 10;
integer flyingIndex     = 11;
integer hoverIndex      = 12;
integer walkingIndex    = 18;
integer standingIndex   = 20;
integer swimdownIndex   = 21;
integer swimupIndex     = 22;
integer swimmingIndex   = 23;
integer waterTreadIndex = 24;

// list of animations that have a different value when underwater
list underwaterAnim = [ hoverIndex, flyingIndex, flyingslowIndex, hoverupIndex, hoverdownIndex ];

// corresponding list of animations that we override the overrider with when underwater
list underwaterOverride = [ waterTreadIndex, swimmingIndex, swimmingIndex, swimupIndex, swimdownIndex];

// This is an ugly hack, because the standing up animation doesn't work quite right
// (SL is borked, this has been bug reported)
// If you play a pose overtop the standing up animation, your avatar tends to get
// stuck in place.
// This is a list of anims that we'll stop automatically
list autoStop = [ 5, 6, 19 ];
// Amount of time we'll wait before autostopping the animation (set to 0 to turn off autostopping)
float autoStopTime = 1.5;

// How long before flipping stand animations
integer standTimeDefault = 30;

// How fast we should poll for changed anims (as fast as possible)
// In practice, you will not poll more than 8 times a second.
float timerEventLength = 0.25;

// The minimum time between events.
// While timerEvents are scaled automatically by the server, control events are processed
// much more aggressively, and needs to be throttled by this script
float minEventDelay = 0.25;

// The key for the typing animation
key typingAnim = "c541c47f-e0c0-058b-ad1a-d6ae3a4584d9";

// Inline check for hackGetAnimList to save a few bytes

// Listen channel for pop-up menu
integer listenChannel = -91234;

// GLOBALS
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

integer numStands;                          // Number of stands - needed for auto cycle
integer randomStands = FALSE;               // Whether stands cycle randomly
integer curStandIndex;                      // Current stand - needed for cycling
string curStandAnim = "";                   // Current Stand animation
string curSitAnim = "";                     // Current sit animation
string curWalkAnim = "";                    // Current walk animation
string curGsitAnim = "";                    // Current ground sit animation

list overrides = [];                        // List of animations we override
key notecardLineKey;                        // notecard reading keys
integer notecardIndex;                      // current line being read from notecard
integer numOverrides;                       // # of overrides

string  lastAnim = "";                      // last Animation we ever played
string  lastAnimSet = "";                   // last set of animations we ever played
integer lastAnimIndex = 0;                  // index of the last animation we ever played
string  lastAnimState = "";                 // last thing llGetAnimation() returned

integer standTime = standTimeDefault;       // How long before flipping stand animations
integer animOverrideOn = TRUE;              // Is the animation override on?

// Added for OCCuffs
integer animOverridePause = FALSE;          // Is the animation override in sleep mode?
// end adding

integer gotPermission  = FALSE;             // Do we have animation permissions?

integer listenHandle;                       // Listen handlers - only used for pop-up menu, then turned off

integer haveWalkingAnim = FALSE;            // Hack to get it so we face the right way when we walk backwards

integer sitOverride = TRUE;                 // Whether we're overriding sit or not

integer standOverride = TRUE;                 // Whether we're overriding stand or not
/// Sit Anywhere mod by Marcus Gray
/// just one var to overrider stands... let's see how this works out 0o
integer sitAnywhereOn = FALSE;

integer listenState = 0;                    // What pop-up menu we're handling now

integer loadInProgress = FALSE;             // Are we currently loading a notecard
string notecardName = "";                   // The notecard we're currently reading

key Owner = NULL_KEY;

// String constants to save a few bytes
string EMPTY = "";
string SEPARATOR = "|";
string TRYAGAIN = "Please correct the notecard and try again.";
string S_SIT_AW = "Sit anywhere: ";


//////////////////////////////////////////////////////////////////////////
/// Seamless Sit mod by Moeka Kohime
///
integer em;
list temp;
key sit = "1a5fe8ac-a804-8a5d-7cbd-56bd83184568";

//Who did the last command
key whoid;

// CODE
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// Find if two lists/sets share any elements in common
integer hasIntersection( list _list1, list _list2 ) {
    list bigList;
    list smallList;
    integer smallListLength;
    integer i;

    if (  llGetListLength( _list1 ) <= llGetListLength( _list2 ) ) {
        smallList = _list1;
        bigList = _list2;
    }
    else {
        bigList = _list1;
        smallList = _list2;
    }
    smallListLength = llGetListLength( smallList );

    for ( i=0; i<smallListLength; i++ ) {
        if ( llListFindList( bigList, llList2List(smallList,i,i) ) != -1 ) {
            return TRUE;
        }
    }

    return FALSE;
}

//////////////////////////////////////////////////////////////////////////
/// Seamless Sit mod by Moeka Kohime
integer CheckSit()
{
    if(!sitOverride)
        return FALSE;
    llSleep(0.5);
    temp = llGetAnimationList(llGetOwner());
    if (temp==[])
        return FALSE;
    if (llListFindList(temp,[sit])!=-1)
        return TRUE;
    return FALSE;
}

startAnimationList( string _csvAnims ) {
    list anims = llCSV2List( _csvAnims );
    integer i;
    for( i=0; i<llGetListLength(anims); i++ )
        llStartAnimation( llList2String(anims,i) );
}

stopAnimationList( string _csvAnims ) {
    list anims = llCSV2List( _csvAnims );
    integer i;
    for( i=0; i<llGetListLength(anims); i++ )
        llStopAnimation( llList2String(anims,i) );
}

startNewAnimation( string _anim, integer _animIndex, string _state ) {
    if ( _anim != lastAnimSet ) {
        string newAnim;
        if ( lastAnim != EMPTY )
            stopAnimationList( lastAnim );
        if ( _anim != EMPTY ) {   // Time to play a new animation
             list newAnimSet = llParseStringKeepNulls( _anim, [SEPARATOR], [] );
             newAnim = llList2String( newAnimSet, (integer)llFloor(llFrand(llGetListLength(newAnimSet))) );

             startAnimationList( newAnim );

            if ( llListFindList( autoStop, [_animIndex] ) != -1 ) {
                // This is an ugly hack, because the standing up animation doesn't work quite right
                // (SL is borked, this has been bug reported)
                // If you play a pose overtop the standing up animation, your avatar tends to get
                // stuck in place.
                if ( lastAnim != EMPTY ) {
                   stopAnimationList( lastAnim );
                   lastAnim = EMPTY;
                }
                llSleep( autoStopTime );
                stopAnimationList( _anim );
            }
        }
        lastAnim = newAnim;
        lastAnimSet = _anim;
    }
    lastAnimIndex = _animIndex;
    lastAnimState = _state;
}

// Figure out what animation we should be playing right now
animOverride() {
    string  curAnimState = llGetAnimation( Owner );
    integer curAnimIndex;
    integer underwaterAnimIndex;

    // Convert the ones we don't handle
    if ( curAnimState == "Striding" ) {
        curAnimState = "Walking";
    } else if ( curAnimState == "Soft Landing" ) {
        curAnimState = "Landing";
    }

    // Remove the list check, since it only contains one element
    // Check if we need to work around any bugs in llGetAnimation
    // Hack, because, SL really likes to switch between crouch and crouchwalking for no reason
    if ( curAnimState == "CrouchWalking" ) {
      if ( llVecMag(llGetVel()) < .5 )
         curAnimState = "Crouching";
    }

    if ( curAnimState == lastAnimState ) {
        // This conditional not absolutely necessary (In fact it's better if it's not here)
        // But it's good for increasing performance.
        // One of the drawbacks of this performance hack is the underwater animations
        // If you fly up, it will keep playing the "swim up" animation even after you've
        // left the water.
        return;
    }

    curAnimIndex        = llListFindList( animState, [curAnimState] );
    underwaterAnimIndex = llListFindList( underwaterAnim, [curAnimIndex] );

    // For all the multi-anims, we know the animation name to play. Send
    // in the actual overrides index, since that's what this function 
    // expects, not the index into the multi-anim list
    if ( curAnimIndex == standingIndex ) {
        if (( standOverride == FALSE ) && !sitAnywhereOn ) {
            startNewAnimation( EMPTY, noAnimIndex, curAnimState );
        }        
        else if (!sitAnywhereOn) { // Sity Anywhere is ON
            startNewAnimation( curStandAnim, standingIndex, curAnimState );
             
        }
        else if (sitAnywhereOn) {
            startNewAnimation( curGsitAnim, sitgroundIndex, curAnimState );
        }
    }
    else if ( curAnimIndex == sittingIndex ) {
        // Check if sit override is turned off
        if (( sitOverride == FALSE ) && ( curAnimState == "Sitting" )&&(CheckSit()!=TRUE)) {// Seamless Sit 
            startNewAnimation( EMPTY, noAnimIndex, curAnimState );
        }
        else {
            if(CheckSit()==TRUE){// Seamless Sit
            startNewAnimation( curSitAnim, sittingIndex, curAnimState );
            } else {
            startNewAnimation( EMPTY, noAnimIndex, curAnimState );
            }
        }
    }
    else if ( curAnimIndex == walkingIndex ) {
        startNewAnimation( curWalkAnim, walkingIndex, curAnimState );
    }
    else if ( curAnimIndex == sitgroundIndex ) {
        startNewAnimation( curGsitAnim, sitgroundIndex, curAnimState );
    }
    else {
        if ( underwaterAnimIndex != -1 ) {
            // Only call llGetPos if we care about underwater anims
            vector curPos = llGetPos();
            if ( llWater(ZERO_VECTOR) > curPos.z ) {
                curAnimIndex = llList2Integer( underwaterOverride, underwaterAnimIndex );
            }
        }
        startNewAnimation( llList2String(overrides, curAnimIndex), curAnimIndex, curAnimState );
    }
}

// Switch to the next stand anim
doNextStand(integer fromUI) {
    if ( numStands > 0 ) {
        if ( randomStands ) {
            curStandIndex = llFloor( llFrand(numStands) );
        } else {
            curStandIndex = (curStandIndex + 1) % numStands;
        }

        curStandAnim = findMultiAnim( standingIndex, curStandIndex );
        if ( lastAnimState == "Standing" && standOverride)        
            startNewAnimation( curStandAnim, standingIndex, lastAnimState );

        if ( fromUI == TRUE ) {
            Notify(whoid, "Switching to stand '" + curStandAnim + "'.", FALSE );
        }
    } else {
        if ( fromUI == TRUE ) {
            Notify(whoid, "No stand animations configured.", FALSE );
        }
    }

    llResetTime();
}

// Displays menu of animation choices
doMultiAnimMenu(key _id, integer _animIndex, string _animType, string _currentAnim )
{
    // Dialog enhancement - Fennec Wind
    // Fix - a no-mod anim with a long name will break this

    list anims = llParseString2List( llList2String(overrides, _animIndex), [SEPARATOR], [] );
    integer numAnims = llGetListLength( anims );
    if ( numAnims > 12 ) {
        Notify(whoid, "Too many animations, cannot generate menu. " + TRYAGAIN, FALSE );
        return;
    }

    list buttons = [];
    integer i;
    string animNames = EMPTY;
    for ( i=0; i<numAnims; i++ ) {
        animNames += "\n" + (string)(i+1) + ". " + llList2String( anims, i );
        buttons += [(string)(i+1)];
    }
    // If no animations were configured, say so and just display an "OK" button
    if ( animNames == EMPTY ) {
        animNames = "\n\nNo overrides have been configured.";
    }
    //llListenControl(listenHandle, TRUE);
    llListenRemove(listenHandle);
    listenHandle = llListen(listenChannel, "", _id, "");
    llDialog( _id, "Select the " + _animType + " animation to use:\n\nCurrently: " + _currentAnim + animNames, 
              buttons, listenChannel );
}

// Returns an animation from the multiAnims
string findMultiAnim( integer _animIndex, integer _multiAnimIndex )
{
    list animsList = llParseString2List( llList2String(overrides, _animIndex), [SEPARATOR], [] );
    return llList2String( animsList, _multiAnimIndex );
}

// Checks for too many animations - can't do menus with > 12 animations
checkMultiAnim( integer _animIndex, string _animName )
{
    list animsList = llParseString2List( llList2String(overrides, _animIndex), [SEPARATOR], [] );
    if ( llGetListLength(animsList) > 12 )
        Notify(whoid, "You have more than 12 " + _animName + " animations. Please correct this.", FALSE );
}

checkAnimInInventory( string _csvAnims )
{
    list anims = llCSV2List( _csvAnims );
    integer i;
    for( i=0; i<llGetListLength(anims); i++ ) {
        string animName = llList2String( anims, i );
        if ( llGetInventoryType( animName ) != INVENTORY_ANIMATION ) {
            // Only a warning, so built-in anims can be used
            Notify(whoid, "Warning: Couldn't find animation '" + animName + "' in inventory.", FALSE );
        }
    }
}

// Print free memory. Separate function to save a few bytes
printFreeMemory()
{
// Added for OCCuffs:
// Changed to be comatible to mono
    float memory = (float)llGetFreeMemory() * 100.0 / 65536.0;
// end of changes
    Notify(whoid, (string)((integer)memory) + "% memory free", FALSE );
}

// Returns true if we should override the current animation
integer checkAndOverride() {
    // Changed for OCCuffs to make sure Pause mode is respected
    if ( animOverrideOn && gotPermission && (animOverridePause==FALSE)) {
        // Check if we should explicitly NOT override a playing animation
        if ( hasIntersection( autoDisableList, llGetAnimationList(Owner) ) ) {
            startNewAnimation( EMPTY, noAnimIndex, EMPTY );
            return FALSE;
        }

        animOverride();
        return TRUE;
    }

    return FALSE;
}

// Load all the animation names from a notecard
loadNoteCard() {

    if ( llGetInventoryKey(notecardName) == NULL_KEY ) {
        Notify(whoid, "Notecard '" + notecardName + "' does not exist, or does not have full permissions.", FALSE );
        loadInProgress = FALSE;
        notecardName = EMPTY;
        return;
    }

    Notify(whoid, "Loading notecard '" + notecardName + "'...", FALSE );

    // Faster events while processing our notecard
    llMinEventDelay( 0 );

    // Clear out saved override information, since we now allow sparse notecards
    overrides = [];
    integer i;
    for ( i=0; i<numOverrides; i++ )
        overrides += [EMPTY];

    // Clear out multi-anim info as well, since we may end up with fewer options
    // that the last time
    curStandIndex = 0;
    curStandAnim = EMPTY;
    curSitAnim = EMPTY;
    curWalkAnim = EMPTY;
    curGsitAnim = EMPTY;

    // Start reading the data
    notecardIndex = 0;
    notecardLineKey = llGetNotecardLine( notecardName, notecardIndex );
}

// Stop loading notecard
endNotecardLoad()
{
    loadInProgress = FALSE;
    notecardName = EMPTY;

    // Restore the minimum event delay
    llMinEventDelay( minEventDelay );
}

// Initialize listeners, and reset some status variables
initialize() {
    Owner = llGetOwner();
    whoid=Owner;

// Added for OCCuffs: Changed 1 line
    if ( animOverrideOn && (animOverridePause==FALSE) )
        llSetTimerEvent( timerEventLength );
    else
        llSetTimerEvent( 0 );

    lastAnim = EMPTY;
    lastAnimSet = EMPTY;
    lastAnimIndex = noAnimIndex;
    lastAnimState = EMPTY;
    gotPermission = FALSE;

    // Create new listener, and turn it off
    if ( listenHandle )
        llListenRemove( listenHandle );
    
    //we'll start our listener when we need it, and know who to listen to
    //listenHandle = llListen( listenChannel, EMPTY, Owner, EMPTY );
    //llListenControl( listenHandle, FALSE );

    printFreeMemory();
}

Notify(key id, string msg, integer alsoNotifyWearer) {
    if(id)
    {
        if (id != Owner) {
            llInstantMessage(id,msg);
            if (alsoNotifyWearer) {
                llOwnerSay(msg);
            }
        }
        else {
            llOwnerSay(msg);
        }  
    }
    else {
        llOwnerSay(msg+"\n whoid:"+(string)whoid+"\n There was an error sending a message. Please report it at http://code.google.com/p/opencollar/issues/list");
    }    
}

// STATE
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

default {
    state_entry() {
        integer i;

        Owner = llGetOwner();

        // Just a precaution, this shouldn't be on after a reset
        if ( listenHandle )
            llListenRemove( listenHandle );

        listenHandle = llListen( listenChannel, EMPTY, Owner, EMPTY );

        if ( llGetAttached() )
            llRequestPermissions( llGetOwner(), PERMISSION_TRIGGER_ANIMATION|PERMISSION_TAKE_CONTROLS );

        numOverrides = llGetListLength( tokens );

        // Type convert strings to keys :P
        for ( i=0; i<llGetListLength(autoDisableList); i++ ) {
            key k = llList2Key( autoDisableList, i );
            autoDisableList = llListReplaceList ( autoDisableList, [ k ], i, i );
        }

        // populate override list with blanks
        overrides = [];
        for ( i=0; i<numOverrides; i++ ) {
            overrides += [ EMPTY ];
        }
        randomStands = FALSE;
        initialize();
        notecardName = defaultNoteCard;
        loadInProgress = TRUE;
        whoid=Owner;
        loadNoteCard();

        // turn off the auto-stop anim hack
        if ( autoStopTime == 0 )
            autoStop = [];

        llResetTime();
    }

    on_rez( integer _code ) {
        // added for OCCuffs
        animOverridePause=FALSE;
        initialize();
    }

    attach( key _k ) {
        if ( _k != NULL_KEY )
            llRequestPermissions( llGetOwner(), PERMISSION_TRIGGER_ANIMATION|PERMISSION_TAKE_CONTROLS );
    }

    run_time_permissions( integer _perm ) {
      if ( _perm != (PERMISSION_TRIGGER_ANIMATION|PERMISSION_TAKE_CONTROLS) )
         gotPermission = FALSE;
      else {
         llTakeControls( CONTROL_BACK|CONTROL_FWD, TRUE, TRUE );
         gotPermission = TRUE;
      }
    }

    link_message( integer _sender, integer _num, string _message, key _id) {
        if (_id) whoid = _id;
        // Coming from an interface script
        if ( _message == "ZHAO_RESET" ) {
            Notify(whoid, "Resetting...", FALSE );
            llSleep(1);
            llResetScript();
        
        } else if ( _message == "ZHAO_AOON" && _num == 42) {
            // AO On
            llSetTimerEvent( timerEventLength );
            animOverrideOn = TRUE;
            checkAndOverride();
        
        } else if ( _message == "ZHAO_AOOFF" && _num == 42 ) {
            llSetTimerEvent( 0 );
            animOverrideOn = FALSE;
            startNewAnimation( EMPTY, noAnimIndex, lastAnimState );
            lastAnim = EMPTY;
            lastAnimSet = EMPTY;
            lastAnimIndex = noAnimIndex;
            lastAnimState = EMPTY;
            
        // Added for OCCuffs: Pause mode to wake AO from sleep
        } else if ( _message == "ZHAO_UNPAUSE" ) {
            animOverridePause=FALSE;
            if (animOverrideOn)
            {
                llSetTimerEvent( timerEventLength );
                checkAndOverride();
            }
            animOverridePause=FALSE;
        
        } else if ( _message == "ZHAO_PAUSE" ) {
        // Added for OCCuffs: Pause mode to wake AO from sleep
            animOverridePause=TRUE;
            if (animOverrideOn)
            {
                llSetTimerEvent( 0 );
                startNewAnimation( EMPTY, noAnimIndex, lastAnimState );
                lastAnim = EMPTY;
                lastAnimSet = EMPTY;
                lastAnimIndex = noAnimIndex;
                lastAnimState = EMPTY;
            }
        // end of OCCuffs            

        } else if ( _message == "ZHAO_STANDON" ) {
            // Turning on sit override
            standOverride = TRUE;
            if ( lastAnimState == "Standing" )
                startNewAnimation( curStandAnim, sittingIndex, lastAnimState );            
                
        } else if ( _message == "ZHAO_STANDOFF" ) {
            // Turning off sit override
            standOverride = FALSE;
            if (sitAnywhereOn)
            {
                sitAnywhereOn = FALSE;
            }
            if ( lastAnimState == "Standing" )
                startNewAnimation( EMPTY, noAnimIndex, lastAnimState );            
      
        } else if ( _message == "ZHAO_SITON" ) {
            // Turning on sit override
            sitOverride = TRUE;
            Notify(whoid, "Sit override: On", FALSE );
            if ( lastAnimState == "Sitting" )
                startNewAnimation( curSitAnim, sittingIndex, lastAnimState );
        
        } else if ( _message == "ZHAO_SITOFF" ) {
            // Turning off sit override
            sitOverride = FALSE;
            Notify(whoid, "Sit override: Off", FALSE );
            if ( lastAnimState == "Sitting" )
                startNewAnimation( EMPTY, noAnimIndex, lastAnimState );
       
         } else if ( _message == "ZHAO_SITANYWHERE_ON" ) {
            // Turning on sit anywhre mod
            sitAnywhereOn = TRUE;
            standOverride = FALSE;
            //llOwnerSay( S_SIT_AW + "On" );
            if ( lastAnimState == "Standing" )
                startNewAnimation( curGsitAnim, sitgroundIndex, lastAnimState );
        
        } else if ( _message == "ZHAO_SITANYWHERE_OFF" ) {
            // Turning off sit anywhere mod
            sitAnywhereOn = FALSE;
            standOverride = TRUE;
            //llOwnerSay( S_SIT_AW + "Off" );
            if ( lastAnimState == "Standing" )
                startNewAnimation( curStandAnim, standingIndex, lastAnimState );
        
        } else if ( _message == "ZHAO_RANDOMSTANDS" ) {
            // Cycling to next stand - sequential or random
            randomStands = TRUE;
            Notify(whoid, "Stand cycling: Random", FALSE );
        
        } else if ( _message == "ZHAO_SEQUENTIALSTANDS" ) {
            // Cycling to next stand - sequential or random
            randomStands = FALSE;
            Notify(whoid, "Stand cycling: Sequential", FALSE );
        
        } else if ( _message == "ZHAO_SETTINGS" ) {
            // Print settings
            string notifymessage;
            if ( sitOverride == TRUE ) {
                notifymessage += "Sit override: On";
            } else {
                notifymessage += "Sit override: Off";
            }
            if ( randomStands == TRUE ) {
                notifymessage += "\n" + "Stand cycling: Random";
            } else {
                notifymessage += "\n" + "Stand cycling: Sequential";
            }
            notifymessage += "\n" + "Stand cycle time: " + (string)standTime + " seconds";
            Notify(whoid, notifymessage,FALSE);

        } else if ( _message == "ZHAO_NEXTSTAND" ) {
            // Cycling to next stand - sequential or random. This is from UI, so we
            // want feedback
            whoid=_id;
            doNextStand( TRUE );
        
        } else if ( llGetSubString(_message, 0, 14) == "ZHAO_STANDTIME|" ) {
            // Stand time change
            standTime = (integer)llGetSubString(_message, 15, -1);
            Notify(whoid, "Stand cycle time: " + (string)standTime + " seconds", FALSE );
        
        } else if ( llGetSubString(_message, 0, 9) == "ZHAO_LOAD|" ) {
            // Can't load while we're in the middle of a load
            if ( loadInProgress == TRUE ) {
                Notify(whoid, "Cannot load new notecard, still reading notecard '" + notecardName + "'", FALSE );
                return;
            }

            // Notecard menu
            loadInProgress = TRUE;
            notecardName = llGetSubString(_message, 10, -1);
            whoid=_id;
            loadNoteCard();
        
        } else if ( _message == "ZHAO_SITS" ) {
            // Selecting new sit anim

            // Move these to a common function
            doMultiAnimMenu(_id, sittingIndex, "Sitting", curSitAnim );

            listenState = 1;
        
        } else if ( _message == "ZHAO_WALKS" ) {
            // Same thing for the walk

            // Move these to a common function
            doMultiAnimMenu(_id, walkingIndex, "Walking", curWalkAnim );

            listenState = 2;
        } else if ( _message == "ZHAO_GROUNDSITS" ) {
            // And the ground sit

            // Move these to a common function
            doMultiAnimMenu(_id, sitgroundIndex, "Sitting On Ground", curGsitAnim );

            listenState = 3;
        }
    }

    listen( integer _channel, string _name, key _id, string _message) {
        if (_id) whoid = _id; 
        // Turn listen off. We turn it on again if we need to present 
        // another menu
        llListenRemove(listenHandle);

        if ( listenState == 1 ) {
            // Dialog enhancement - Fennec Wind
            // Note that this is within one 'overrides' entry
            curSitAnim = findMultiAnim( sittingIndex, (integer)_message - 1 );
            if ( lastAnimState == "Sitting" ) {
                startNewAnimation( curSitAnim, sittingIndex, lastAnimState );
            }
            Notify(whoid, "New sitting animation: " + curSitAnim, FALSE );

        } else if ( listenState == 2 ) {
            // Dialog enhancement - Fennec Wind
            // Note that this is within one 'overrides' entry
            curWalkAnim = findMultiAnim( walkingIndex, (integer)_message - 1 );
            if ( lastAnimState == "Walking" ) {
                startNewAnimation( curWalkAnim, walkingIndex, lastAnimState );
            }
            Notify(whoid, "New walking animation: " + curWalkAnim, FALSE );

        } else if ( listenState == 3 ) {
            // Dialog enhancement - Fennec Wind
            // Note that this is within one 'overrides' entry
            curGsitAnim = findMultiAnim( sitgroundIndex, (integer)_message - 1 );
            // Lowercase 'on' - that's the anim name in SL
            if (( lastAnimState == "Sitting on Ground" ) || ( lastAnimState == "Standing" && sitAnywhereOn ) ) {
                startNewAnimation( curGsitAnim, sitgroundIndex, lastAnimState );
            }
            Notify(whoid, "New sitting on ground animation: " + curGsitAnim, FALSE );
        }
    }

    dataserver( key _query_id, string _data ) {

        if ( _query_id != notecardLineKey ) {
            Notify(whoid, "Error in reading notecard. Please try again.", FALSE );

            endNotecardLoad();
            return;
        }

        if ( _data == EOF ) {
            // Now the read ends when we hit EOF

            // End-of-notecard handling...

             // Do we have a walking animation?
            if ( llList2String(overrides, walkingIndex) != EMPTY ) {
                 haveWalkingAnim = TRUE;
            }

            // See how many walks/sits/ground-sits we have
            checkMultiAnim( walkingIndex, "walking" );
            checkMultiAnim( sittingIndex, "sitting" );
            checkMultiAnim( sitgroundIndex, "sitting on ground" );

            // Reset stand, walk, sit and ground-sit anims to first entry
            curStandIndex = 0;
            numStands = llGetListLength( llParseString2List(llList2String(overrides, standingIndex), 
                                         [SEPARATOR], []) );

            curStandAnim = findMultiAnim( standingIndex, 0 );
            curWalkAnim = findMultiAnim( walkingIndex, 0 );
            curSitAnim = findMultiAnim( sittingIndex, 0 );
            curGsitAnim = findMultiAnim( sitgroundIndex, 0 );

            // Clear out the currently playing anim so we play the new one on the next cycle
            startNewAnimation( EMPTY, noAnimIndex, lastAnimState );
            lastAnim = EMPTY;
            lastAnimSet = EMPTY;
            lastAnimIndex = noAnimIndex;
            lastAnimState = EMPTY;

            Notify(whoid, "Finished reading notecard '" + notecardName + "'.", FALSE );
            printFreeMemory();

            endNotecardLoad();
            return;
        }

        // We ignore blank lines and lines which start with a #
        if (( _data == EMPTY ) || ( llGetSubString(_data, 0, 0) == "#" )) {
            notecardLineKey = llGetNotecardLine( notecardName, ++notecardIndex );
            return;
        }

        // Check for a valid token
        integer i;
        integer found = FALSE;
        for ( i=0; i<numOverrides; i++ ) {
            string token = llList2String( tokens, i );
            // We have some blank entries in 'tokens' to get it to line up with animState... make
            // sure we don't match on a blank. 
            if (( token != EMPTY ) && ( llGetSubString( _data, 0, llStringLength(token) - 1 ) == token )) {
                // We found a token on this line, so we don't have to throw an error or keep
                // trying to match tokens
                found = TRUE;
                // Make sure the line has data after the token, or our sub-string calculation goes off
                if ( _data != token ) {
                    string animPart = llGetSubString( _data, llStringLength(token), -1 );

                    // See if this is a token for which we allow multiple animations
                    if ( llListFindList( multiAnimTokenIndexes, [i] ) != -1 ) {
                        list anims2Add = llParseString2List( animPart, [SEPARATOR], [] );
                        // Make sure the anims exist
                        integer j;
                        for ( j=0; j<llGetListLength(anims2Add); j++ ) {
                            checkAnimInInventory( llList2String(anims2Add,j) );
                        }

                        // Join the 2 lists and put it back into overrides
                        list currentAnimsList = llParseString2List( llList2String(overrides, i), [SEPARATOR], [] );
                        currentAnimsList += anims2Add;
                        overrides = llListReplaceList( overrides, [llDumpList2String(currentAnimsList, SEPARATOR)], i, i );
                    } else {
                        // This is an animation for which we only allow one override
                        if ( llSubStringIndex( animPart, SEPARATOR ) != -1 ) {
                            Notify(whoid, "Cannot have multiple animations for " + token + ". " + TRYAGAIN, FALSE );

                            endNotecardLoad();
                            return;
                        }

                        // Inventory check
                        checkAnimInInventory( animPart );

                        // We're good
                        overrides = llListReplaceList( overrides, [animPart], i, i );
                    } // End if-else for multi-anim vs. single-anim
                } // End if line has more than just a token

                // Break, no need to continue the search loop
                jump done;

            } // End if token matched
        } // End search for tokens

        @done;
        
        if ( !found ) {
            Notify(whoid, "Could not recognize token on line " + (string)notecardIndex + ": " + 
                        _data + ". " + TRYAGAIN, FALSE );

            endNotecardLoad();
            return;
        }

        // Wow, after all that, we read one line of the notecard
        notecardLineKey = llGetNotecardLine( notecardName, ++notecardIndex );
        return;
    }

    collision_start( integer _num ) {
        checkAndOverride();
    }

    collision( integer _num ) {
        checkAndOverride();
    }

    collision_end( integer _num ) {
        checkAndOverride();
    }

    control( key _id, integer _level, integer _edge ) {
        if ( _edge ) {
            // SL tends to mix animations together on forward or backward walk. It could be because
            // of anim priorities. This helps stop the default walking anims, so it won't mix with
            // the desired anim. This also lets the avi turn around on a backwards walk for a more natural
            // look.
            // Reverse the order of the checks, since we'll often get the control key combination, but we
            // may be flying
            if ( llGetAnimation(Owner) == "Walking" ) {
                if ( _level & _edge & ( CONTROL_BACK | CONTROL_FWD ) ) {
                    if ( haveWalkingAnim ) {
                        llStopAnimation( "walk" );
                        llStopAnimation( "female_walk" );
                    }
                }
            }

            checkAndOverride();
            }
        }

    timer() {
        if ( checkAndOverride() ) {
            // Is it time to switch stand animations?
            // Stand cycling can be turned off
            if ( (standTime != 0) && (llGetTime() > standTime) ) {
                // Don't interrupt the typing animation with a stand change. Not from
                // UI, no feedback
                if ( llListFindList(llGetAnimationList(Owner), [typingAnim]) == -1 )
                    doNextStand( FALSE );
            }
        }
    }
}
