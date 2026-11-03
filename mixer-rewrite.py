from pathlib import Path
p=Path('/home/konstantinmeyer/pcgeos/Appl/Audio/Mixer/Main/mixer.goc')
b=p.read_bytes()
assert b'\r' not in b
header=b[:b.index(b'@include')].decode('ascii')
s=header+r'''@include <stdapp.goh>

#include <geos.h>
#include <mixlib.goh>

/* Implemented with ChatGPT Codex, prompted by MeyerK */
#define MIXER_VOLUME_MAX 255
#define MIXER_MUTE_IDENTIFIER 1

@class MixerProcessClass, GenProcessClass;
@message (GEN_ITEM_GROUP_STATUS_MSG) MSG_MIXER_ADVANCED_PAGE;
@endc;
@classdecl MixerProcessClass, neverSaved;

@class MixerControlClass, GenInteractionClass;
@instance word MCI_token;
@instance word MCI_range;
@instance byte MCI_type;
@instance Boolean MCI_stereo;
@instance Boolean MCI_muted;
@instance word MCI_levels;
@instance optr MCI_value;
@instance optr MCI_balance;
@instance optr MCI_mute;
@instance word MCI_mask;
@message void MSG_MIXER_CONTROL_INITIALIZE(MixerValue *descriptionP);
@message void MSG_MIXER_CONTROL_UPDATE();
@message (GEN_VALUE_STATUS_MSG) MSG_MIXER_VOLUME_CHANGED;
@message (GEN_VALUE_STATUS_MSG) MSG_MIXER_BALANCE_CHANGED;
@message (GEN_BOOLEAN_GROUP_STATUS_MSG) MSG_MIXER_MUTE_CHANGED;
@message (GEN_ITEM_GROUP_STATUS_MSG) MSG_MIXER_ITEM_CHANGED;
@message (GEN_BOOLEAN_GROUP_STATUS_MSG) MSG_MIXER_SWITCHES_CHANGED;
@endc;
@classdecl MixerControlClass, neverSaved;

static word _pascal MixerToPercent(word volume);
static word _pascal MixerFromPercent(word volume);
static word _pascal MixerPeak(word levels);
static word _pascal MixerScaleLevels(word levels, word volume);
static int _pascal MixerBalance(word levels);
static word _pascal MixerSetBalance(word volume, int balance);
static optr _pascal MixerCopy(optr template, optr parent);
static void _pascal MixerClear(optr parent);
static Boolean _pascal MixerDescribe(MixerValue *descriptionP);

@start AppResource;
@visMoniker MixerTextMoniker = "Mixer";
@object GenApplicationClass MixerApp = {
    GI_visMoniker = list {
        @MixerTextMoniker, @MixerVGAMoniker, @MixerHGAMoniker,
        @MixerEGAMoniker, @MixerHGCMoniker, @MixerCGAMoniker,
        @MixerTCMoniker, @MixerTMMoniker, @MixerTCGAMoniker
    };
    GI_comp = @MixerPrimary;
    gcnList(MANUFACTURER_ID_GEOWORKS, GAGCNLT_WINDOWS) = @MixerPrimary;
}
@end AppResource;

@start MonikerRes, data;
@include "token.goh"
@end MonikerRes;

@start Interface;
@object GenPrimaryClass MixerPrimary = {
    GI_comp = @MixerMainGroup, @MixerAdvanced;
    HINT_SIZE_WINDOW_AS_DESIRED;
}
@object GenInteractionClass MixerMainGroup = {
    GI_comp = @MixerStatus, @MixerPlayback, @MixerBalanceHelp,
              @MixerAdvancedTrigger;
    HINT_ORIENT_CHILDREN_VERTICALLY;
    HINT_CENTER_CHILDREN_HORIZONTALLY;
}
@object GenGlyphClass MixerStatus = {
    GI_visMoniker = "No supported mixer controls are available.";
}
@object GenInteractionClass MixerPlayback = {
    HINT_ORIENT_CHILDREN_HORIZONTALLY;
    HINT_ALLOW_CHILDREN_TO_WRAP;
    HINT_WRAP_AFTER_CHILD_COUNT = 4;
    HINT_TOP_JUSTIFY_CHILDREN;
}
@object GenGlyphClass MixerBalanceHelp = {
    GI_states = @default & ~GS_USABLE;
    GI_visMoniker = "Balance: -100 left, 0 center, +100 right.";
}
@object GenTriggerClass MixerAdvancedTrigger = {
    GI_visMoniker = 'A', "Advanced...";
    GI_states = @default & ~GS_ENABLED;
    GTI_destination = @MixerAdvanced;
    GTI_actionMsg = MSG_GEN_INTERACTION_INITIATE;
}
@end Interface;

@start AdvancedResource;
@object GenInteractionClass MixerAdvanced = {
    GI_visMoniker = "Advanced mixer settings";
    GII_visibility = GIV_DIALOG;
    GII_type = GIT_COMMAND;
    GI_comp = @MixerAdvancedHelp, @MixerPages, @MixerTone,
              @MixerRecording, @MixerOther;
    HINT_ORIENT_CHILDREN_VERTICALLY;
}
@object GenGlyphClass MixerAdvancedHelp = {
    GI_visMoniker = "Changes take effect immediately.";
}
@object GenItemGroupClass MixerPages = {
    GI_comp = @MixerToneItem, @MixerRecordingItem, @MixerOtherItem;
    GIGI_destination = process;
    ATTR_GEN_ITEM_GROUP_STATUS_MSG = MSG_MIXER_ADVANCED_PAGE;
    HINT_ORIENT_CHILDREN_HORIZONTALLY;
}
@object GenItemClass MixerToneItem = {
    GI_visMoniker = "Tone";
    GII_identifier = 0;
}
@object GenItemClass MixerRecordingItem = {
    GI_visMoniker = "Recording";
    GII_identifier = 1;
}
@object GenItemClass MixerOtherItem = {
    GI_visMoniker = "Other";
    GII_identifier = 2;
}
@object GenInteractionClass MixerTone = {
    GI_states = @default & ~GS_USABLE;
    HINT_ORIENT_CHILDREN_HORIZONTALLY;
    HINT_ALLOW_CHILDREN_TO_WRAP;
    HINT_WRAP_AFTER_CHILD_COUNT = 2;
    HINT_TOP_JUSTIFY_CHILDREN;
}
@object GenInteractionClass MixerRecording = {
    GI_states = @default & ~GS_USABLE;
    HINT_ORIENT_CHILDREN_HORIZONTALLY;
    HINT_ALLOW_CHILDREN_TO_WRAP;
    HINT_WRAP_AFTER_CHILD_COUNT = 2;
    HINT_TOP_JUSTIFY_CHILDREN;
}
@object GenInteractionClass MixerOther = {
    GI_states = @default & ~GS_USABLE;
    HINT_ORIENT_CHILDREN_HORIZONTALLY;
    HINT_ALLOW_CHILDREN_TO_WRAP;
    HINT_WRAP_AFTER_CHILD_COUNT = 2;
    HINT_TOP_JUSTIFY_CHILDREN;
}
@end AdvancedResource;

@start Templates;
@object MixerControlClass MixerControlTemplate = {
    GI_states = @default & ~GS_USABLE;
    HINT_ORIENT_CHILDREN_VERTICALLY;
    HINT_CENTER_CHILDREN_HORIZONTALLY;
    HINT_LEFT_JUSTIFY_MONIKERS;
}
@object GenValueClass MixerVolumeTemplate = {
    GI_visMoniker = "Volume";
    GI_states = @default & ~GS_USABLE;
    GVLI_minimum = MakeWWFixed(0.0);
    GVLI_maximum = MakeWWFixed(100.0);
    GVLI_increment = MakeWWFixed(1.0);
    GVLI_displayFormat = GVDF_PERCENTAGE;
    ATTR_GEN_VALUE_DECIMAL_PLACES = 0;
    ATTR_GEN_VALUE_STATUS_MSG = MSG_MIXER_VOLUME_CHANGED;
    HINT_VALUE_ANALOG_DISPLAY;
    HINT_VALUE_ORIENT_VERTICALLY;
    HINT_VALUE_IMMEDIATE_DRAG_NOTIFICATION;
    HINT_VALUE_DISPLAY_INTERVALS = {10, 0};
}
@object GenValueClass MixerBalanceTemplate = {
    GI_visMoniker = "Balance";
    GI_states = @default & ~GS_USABLE;
    GVLI_minimum = MakeWWFixed(-100.0);
    GVLI_maximum = MakeWWFixed(100.0);
    GVLI_increment = MakeWWFixed(1.0);
    ATTR_GEN_VALUE_STATUS_MSG = MSG_MIXER_BALANCE_CHANGED;
}
@object GenBooleanGroupClass MixerMuteTemplate = {
    GI_states = @default & ~GS_USABLE;
    GI_comp = @MixerMuteBooleanTemplate;
    ATTR_GEN_BOOLEAN_GROUP_STATUS_MSG = MSG_MIXER_MUTE_CHANGED;
}
@object GenBooleanClass MixerMuteBooleanTemplate = {
    GI_visMoniker = "Mute";
    GBI_identifier = MIXER_MUTE_IDENTIFIER;
}
@object GenItemGroupClass MixerItemsTemplate = {
    GI_states = @default & ~GS_USABLE;
    ATTR_GEN_ITEM_GROUP_STATUS_MSG = MSG_MIXER_ITEM_CHANGED;
    HINT_ORIENT_CHILDREN_HORIZONTALLY;
}
@object GenBooleanGroupClass MixerSwitchesTemplate = {
    GI_states = @default & ~GS_USABLE;
    ATTR_GEN_BOOLEAN_GROUP_STATUS_MSG = MSG_MIXER_SWITCHES_CHANGED;
}
@object GenItemClass MixerItemTemplate = {
    GI_states = @default & ~GS_USABLE;
}
@object GenBooleanClass MixerBooleanTemplate = {
    GI_states = @default & ~GS_USABLE;
}
@end Templates;

static word _pascal MixerToPercent(word volume)
{
    if (volume > MIXER_VOLUME_MAX) {
        volume = MIXER_VOLUME_MAX;
    }
    volume = (volume * 100 + 127) / MIXER_VOLUME_MAX;
    return volume;
}

static word _pascal MixerFromPercent(word volume)
{
    if (volume > 100) {
        volume = 100;
    }
    volume = (volume * MIXER_VOLUME_MAX + 50) / 100;
    return volume;
}

static word _pascal MixerPeak(word levels)
{
    word left = levels & 255;
    word right = levels >> 8;

    return left > right ? left : right;
}

/* Preserve the exact channel ratio, including a fully silent side. */
static word _pascal MixerScaleLevels(word levels, word volume)
{
    word peak = MixerPeak(levels);
    word left;
    word right;

    if (!peak) {
        return volume | (volume << 8);
    }
    left = ((levels & 255) * volume + peak / 2) / peak;
    right = ((levels >> 8) * volume + peak / 2) / peak;
    return left | (right << 8);
}

static int _pascal MixerBalance(word levels)
{
    word left = levels & 255;
    word right = levels >> 8;

    if (left > right) {
        return -(int)(((left - right) * 100 + left / 2) / left);
    }
    if (right > left) {
        return ((right - left) * 100 + right / 2) / right;
    }
    return 0;
}

static word _pascal MixerSetBalance(word volume, int balance)
{
    word left = volume;
    word right = volume;

    if (balance < -100) {
        balance = -100;
    }
    if (balance > 100) {
        balance = 100;
    }
    if (balance < 0) {
        right = (volume * (100 + balance) + 50) / 100;
    } else {
        left = (volume * (100 - balance) + 50) / 100;
    }
    return left | (right << 8);
}

static optr _pascal MixerCopy(optr template, optr parent)
{
    return @call template::MSG_GEN_COPY_TREE(OptrToHandle(parent),
                    OptrToChunk(parent), CCF_MARK_DIRTY | CCO_LAST);
}

static void _pascal MixerClear(optr parent)
{
    optr child;

    while ((child = @call parent::MSG_GEN_FIND_CHILD_AT_POSITION(0)) != 0) {
        @call child::MSG_GEN_DESTROY(VUM_NOW, CCF_MARK_DIRTY);
    }
}

static Boolean _pascal MixerDescribe(MixerValue *descriptionP)
{
    if (!descriptionP->valVisible || !descriptionP->valRange ||
        !descriptionP->valToken || descriptionP->valToken > BSMX_TOKEN_INACT ||
        descriptionP->valTarget < 1 || descriptionP->valTarget > 3) {
        return FALSE;
    }
    /* ATTENTION: only built-in labels fit our 32-byte buffer. Private
     * driver tokens need a length-bounded MixLib text API first. */
    if (descriptionP->valType == VAL_TYPE_SLIDER) {
        return descriptionP->valRange == MIXER_VOLUME_MAX;
    }
    return (descriptionP->valType == VAL_TYPE_ITEM ||
            descriptionP->valType == VAL_TYPE_BOOL) &&
            descriptionP->valRange <= 8;
}

/***********************************************************************
 * MESSAGE:     MSG_GEN_PROCESS_OPEN_APPLICATION
 * DESCRIPTION: Enumerate advertised controls and build the appropriate UI.
 * PARAMETERS:  Standard application launch parameters.
 * STRATEGY:    Copy only supported controls; rebuild saved UI on reopening.
 * KNOWN BUGS/SIDE EFFECTS/CAVEATS/IDEAS:
 *              Never write mixer registers during initialization.
 * REVISION HISTORY:
 *      MeyerK  11/03/26  Implemented with ChatGPT Codex
 ***********************************************************************/
@method MixerProcessClass, MSG_GEN_PROCESS_OPEN_APPLICATION
{
    word state;
    word count;
    word dsp;
    word i;
    word page;
    word firstPage = 3;
    word playback = 0;
    Boolean stereo = FALSE;
    MixerValue description;
    optr parent;
    optr control;
    optr pages[3];
    optr items[3];

    @callsuper();
    pages[0] = @MixerTone;
    pages[1] = @MixerRecording;
    pages[2] = @MixerOther;
    items[0] = @MixerToneItem;
    items[1] = @MixerRecordingItem;
    items[2] = @MixerOtherItem;
    MixerClear(@MixerPlayback);
    for (page = 0; page < 3; page++) {
        MixerClear(pages[page]);
        @call pages[page]::MSG_GEN_SET_NOT_USABLE(VUM_NOW);
        @call items[page]::MSG_GEN_SET_NOT_ENABLED(VUM_NOW);
    }
    @call MixerAdvancedTrigger::MSG_GEN_SET_NOT_ENABLED(VUM_NOW);
    @call MixerBalanceHelp::MSG_GEN_SET_NOT_USABLE(VUM_NOW);
    @call MixerStatus::MSG_GEN_SET_USABLE(VUM_NOW);
    state = BSMixerGetState();
    if (state) {
        @call MixerStatus::MSG_GEN_REPLACE_VIS_MONIKER_TEXT(
            state & 0x8000 ?
            "No mixer driver is configured or could be loaded." :
            "The sound driver does not support mixer controls.", VUM_NOW);
        return;
    }
    count = BSMixerGetCap(&dsp);
    for (i = 0; i < count; i++) {
        BSMixerSpecValue(i, &description);
        if (!MixerDescribe(&description)) {
            continue;
        }
        if (description.valType == VAL_TYPE_SLIDER &&
            description.valTarget == 1 &&
            description.valToken <= BSMX_TOKEN_SPEAKER) {
            parent = @MixerPlayback;
            playback++;
            stereo |= description.valStereoFlag;
        } else {
            page = description.valTarget == 2 ? 1 :
                (description.valToken == BSMX_TOKEN_BASS ||
                 description.valToken == BSMX_TOKEN_TREBLE ? 0 : 2);
            parent = pages[page];
            @call items[page]::MSG_GEN_SET_ENABLED(VUM_NOW);
            if (page < firstPage) {
                firstPage = page;
            }
        }
        control = MixerCopy(@MixerControlTemplate, parent);
        @call control::MSG_MIXER_CONTROL_INITIALIZE(&description);
        @call control::MSG_GEN_SET_USABLE(VUM_NOW);
    }
    if (playback) {
        @call MixerStatus::MSG_GEN_SET_NOT_USABLE(VUM_NOW);
    } else {
        @call MixerStatus::MSG_GEN_REPLACE_VIS_MONIKER_TEXT(
            "No supported playback volume controls are available.", VUM_NOW);
    }
    if (stereo) {
        @call MixerBalanceHelp::MSG_GEN_SET_USABLE(VUM_NOW);
    }
    if (firstPage < 3) {
        @call MixerPages::MSG_GEN_ITEM_GROUP_SET_SINGLE_SELECTION(firstPage, FALSE);
        @call pages[firstPage]::MSG_GEN_SET_USABLE(VUM_NOW);
        @call MixerAdvancedTrigger::MSG_GEN_SET_ENABLED(VUM_NOW);
    }
}

/***********************************************************************
 * MESSAGE:     MSG_MIXER_ADVANCED_PAGE
 * DESCRIPTION: Show one advanced category at a time to fit small displays.
 * PARAMETERS:  selection - tone (0), recording (1), or other (2).
 * STRATEGY:    Change only group visibility, preserving all control values.
 * KNOWN BUGS/SIDE EFFECTS/CAVEATS/IDEAS: Changes are immediate.
 * REVISION HISTORY:
 *      MeyerK  11/03/26  Implemented with ChatGPT Codex
 ***********************************************************************/
@method MixerProcessClass, MSG_MIXER_ADVANCED_PAGE
{
    optr pages[3];
    word i;

    if (selection > 2) {
        return;
    }
    pages[0] = @MixerTone;
    pages[1] = @MixerRecording;
    pages[2] = @MixerOther;
    for (i = 0; i < 3; i++) {
        if (i != selection) {
            @call pages[i]::MSG_GEN_SET_NOT_USABLE(VUM_NOW);
        }
    }
    @call pages[selection]::MSG_GEN_SET_USABLE(VUM_NOW);
}

/***********************************************************************
 * MESSAGE:     MSG_MIXER_CONTROL_INITIALIZE
 * DESCRIPTION: Build a slider, exclusive choice, or bit-switch group.
 * PARAMETERS:  descriptionP - synchronous pointer to the driver descriptor.
 * STRATEGY:    Keep state on the control object and wire status messages.
 * KNOWN BUGS/SIDE EFFECTS/CAVEATS/IDEAS:
 *              Item identifiers are indices; subtoken identifiers are bits.
 * REVISION HISTORY:
 *      MeyerK  11/03/26  Implemented with ChatGPT Codex
 ***********************************************************************/
@method MixerControlClass, MSG_MIXER_CONTROL_INITIALIZE
{
    MixerValue description = *descriptionP;
    optr field;
    optr child;
    word raw;
    word index;
    word token;
    word mask = 0;
    char text[32];
    Boolean playback;

    pself->MCI_token = description.valToken;
    pself->MCI_range = description.valRange;
    pself->MCI_type = description.valType;
    pself->MCI_stereo = description.valStereoFlag != 0;
    BSMixerGetTokenText(description.valToken, text);
    @call oself::MSG_GEN_REPLACE_VIS_MONIKER_TEXT(text, VUM_NOW);
    raw = BSMixerGetValue(description.valToken, 3);
    if (description.valType == VAL_TYPE_SLIDER) {
        if (!description.valStereoFlag) {
            raw = (raw & 255) * 257;
        }
        pself->MCI_muted = raw == 0;
        pself->MCI_levels = raw ? raw : 0xffff;
        field = MixerCopy(@MixerVolumeTemplate, oself);
        pself = ObjDerefGen(oself);
        pself->MCI_value = field;
        @call field::MSG_GEN_VALUE_SET_DESTINATION(oself);
        playback = description.valTarget == 1 &&
                   description.valToken <= BSMX_TOKEN_SPEAKER;
        if (!playback) {
            @call field::MSG_GEN_REPLACE_VIS_MONIKER_TEXT("Level", VUM_NOW);
        }
        @call field::MSG_GEN_SET_USABLE(VUM_NOW);
        if (playback && description.valStereoFlag) {
            field = MixerCopy(@MixerBalanceTemplate, oself);
            pself = ObjDerefGen(oself);
            pself->MCI_balance = field;
            @call field::MSG_GEN_VALUE_SET_DESTINATION(oself);
            @call field::MSG_GEN_SET_USABLE(VUM_NOW);
        }
        if (playback) {
            field = MixerCopy(@MixerMuteTemplate, oself);
            pself = ObjDerefGen(oself);
            pself->MCI_mute = field;
            @call field::MSG_GEN_BOOLEAN_GROUP_SET_DESTINATION(oself);
            @call field::MSG_GEN_SET_USABLE(VUM_NOW);
        }
        @call oself::MSG_MIXER_CONTROL_UPDATE();
        return;
    }
    field = MixerCopy(description.valType == VAL_TYPE_ITEM ?
                      @MixerItemsTemplate : @MixerSwitchesTemplate, oself);
    pself = ObjDerefGen(oself);
    pself->MCI_value = field;
    for (index = 0; index < description.valRange; index++) {
        token = BSMixerGetSubToken(description.valToken, 1 << index);
        /* Zero denotes a reserved/unused option, not a selectable item. */
        if (!token || token > BSMX_TOKEN_INACT) {
            continue;
        }
        BSMixerGetTokenText(token, text);
        child = MixerCopy(description.valType == VAL_TYPE_ITEM ?
                          @MixerItemTemplate : @MixerBooleanTemplate, field);
        @call child::MSG_GEN_REPLACE_VIS_MONIKER_TEXT(text, VUM_NOW);
        if (description.valType == VAL_TYPE_ITEM) {
            @call child::MSG_GEN_ITEM_SET_IDENTIFIER(index);
        } else {
            @call child::MSG_GEN_BOOLEAN_SET_IDENTIFIER(1 << index);
        }
        mask |= 1 << index;
        @call child::MSG_GEN_SET_USABLE(VUM_NOW);
    }
    pself = ObjDerefGen(oself);
    pself->MCI_mask = mask;
    if (description.valType == VAL_TYPE_ITEM) {
        @call field::MSG_GEN_ITEM_GROUP_SET_DESTINATION(oself);
        if ((raw & 255) < description.valRange && (mask & (1 << (raw & 255)))) {
            @call field::MSG_GEN_ITEM_GROUP_SET_SINGLE_SELECTION(raw & 255, FALSE);
        }
    } else {
        @call field::MSG_GEN_BOOLEAN_GROUP_SET_DESTINATION(oself);
        @call field::MSG_GEN_BOOLEAN_GROUP_SET_GROUP_STATE(raw & mask, 0);
    }
    if (!mask) {
        @call field::MSG_GEN_SET_NOT_ENABLED(VUM_NOW);
    }
    @call field::MSG_GEN_SET_USABLE(VUM_NOW);
}

/***********************************************************************
 * MESSAGE:     MSG_MIXER_CONTROL_UPDATE
 * DESCRIPTION: Display the current level, balance and mute state.
 * PARAMETERS:  None.
 * STRATEGY:    Programmatic setters do not send user status messages.
 * KNOWN BUGS/SIDE EFFECTS/CAVEATS/IDEAS: Does not reread or write hardware.
 * REVISION HISTORY:
 *      MeyerK  11/03/26  Implemented with ChatGPT Codex
 ***********************************************************************/
@method MixerControlClass, MSG_MIXER_CONTROL_UPDATE
{
    optr field;
    word volume;

    volume = pself->MCI_muted ? 0 : MixerToPercent(MixerPeak(pself->MCI_levels));
    field = pself->MCI_value;
    @call field::MSG_GEN_VALUE_SET_INTEGER_VALUE(volume, FALSE);
    field = pself->MCI_balance;
    if (field) {
        @call field::MSG_GEN_VALUE_SET_INTEGER_VALUE(
            MixerBalance(pself->MCI_levels), FALSE);
    }
    field = pself->MCI_mute;
    if (field) {
        @call field::MSG_GEN_BOOLEAN_GROUP_SET_BOOLEAN_STATE(
            MIXER_MUTE_IDENTIFIER, pself->MCI_muted);
    }
}

/***********************************************************************
 * MESSAGE:     MSG_MIXER_VOLUME_CHANGED
 * DESCRIPTION: Change level while preserving the channel ratio.
 * PARAMETERS:  value - level in percent.
 * STRATEGY:    Keep the last nonzero pair for mute/restore and zero volume.
 * KNOWN BUGS/SIDE EFFECTS/CAVEATS/IDEAS: Tone sliders have no mute checkbox.
 * REVISION HISTORY:
 *      MeyerK  11/03/26  Implemented with ChatGPT Codex
 ***********************************************************************/
@method MixerControlClass, MSG_MIXER_VOLUME_CHANGED
{
    word volume;
    word levels;

    volume = MixerFromPercent(WWFixedToInt(value));
    if (volume) {
        pself->MCI_levels = MixerScaleLevels(pself->MCI_levels, volume);
    }
    pself->MCI_muted = volume == 0;
    levels = volume ? pself->MCI_levels : 0;
    BSMixerSetValue(pself->MCI_token, 2, (byte)levels, (byte)(levels >> 8));
    @call oself::MSG_MIXER_CONTROL_UPDATE();
}

/***********************************************************************
 * MESSAGE:     MSG_MIXER_BALANCE_CHANGED
 * DESCRIPTION: Set left/right balance without changing peak volume.
 * PARAMETERS:  value - signed balance from -100 (left) to +100 (right).
 * STRATEGY:    A muted control updates its remembered pair and stays silent.
 * KNOWN BUGS/SIDE EFFECTS/CAVEATS/IDEAS: Only stereo playback has this field.
 * REVISION HISTORY:
 *      MeyerK  11/03/26  Implemented with ChatGPT Codex
 ***********************************************************************/
@method MixerControlClass, MSG_MIXER_BALANCE_CHANGED
{
    word levels;

    if (!pself->MCI_stereo || !pself->MCI_balance) {
        return;
    }
    pself->MCI_levels = MixerSetBalance(MixerPeak(pself->MCI_levels),
                                      (int)WWFixedToInt(value));
    levels = pself->MCI_muted ? 0 : pself->MCI_levels;
    BSMixerSetValue(pself->MCI_token, 2, (byte)levels, (byte)(levels >> 8));
    @call oself::MSG_MIXER_CONTROL_UPDATE();
}

/***********************************************************************
 * MESSAGE:     MSG_MIXER_MUTE_CHANGED
 * DESCRIPTION: Mute or restore the remembered left/right levels.
 * PARAMETERS:  selectedBooleans - mute checkbox state.
 * STRATEGY:    Retain both channels, including their exact balance.
 * KNOWN BUGS/SIDE EFFECTS/CAVEATS/IDEAS: Mute is implemented by zero levels.
 * REVISION HISTORY:
 *      MeyerK  11/03/26  Implemented with ChatGPT Codex
 ***********************************************************************/
@method MixerControlClass, MSG_MIXER_MUTE_CHANGED
{
    word levels;

    pself->MCI_muted = (selectedBooleans & MIXER_MUTE_IDENTIFIER) != 0;
    levels = pself->MCI_muted ? 0 : pself->MCI_levels;
    BSMixerSetValue(pself->MCI_token, 2, (byte)levels, (byte)(levels >> 8));
    @call oself::MSG_MIXER_CONTROL_UPDATE();
}

/***********************************************************************
 * MESSAGE:     MSG_MIXER_ITEM_CHANGED
 * DESCRIPTION: Apply one driver-defined recording or gain option.
 * PARAMETERS:  selection - hardware option index.
 * STRATEGY:    Reject reserved choices; item values are not percentages.
 * KNOWN BUGS/SIDE EFFECTS/CAVEATS/IDEAS: None.
 * REVISION HISTORY:
 *      MeyerK  11/03/26  Implemented with ChatGPT Codex
 ***********************************************************************/
@method MixerControlClass, MSG_MIXER_ITEM_CHANGED
{
    if (selection < pself->MCI_range && (pself->MCI_mask & (1 << selection))) {
        BSMixerSetValue(pself->MCI_token, 2, (byte)selection, 0);
    }
}

/***********************************************************************
 * MESSAGE:     MSG_MIXER_SWITCHES_CHANGED
 * DESCRIPTION: Apply the advertised playback or recording routing switches.
 * PARAMETERS:  selectedBooleans - hardware bit selections.
 * STRATEGY:    Preserve bits without advertised options using a fresh read.
 * KNOWN BUGS/SIDE EFFECTS/CAVEATS/IDEAS: None.
 * REVISION HISTORY:
 *      MeyerK  11/03/26  Implemented with ChatGPT Codex
 ***********************************************************************/
@method MixerControlClass, MSG_MIXER_SWITCHES_CHANGED
{
    word raw;

    raw = BSMixerGetValue(pself->MCI_token, 3) & 255;
    raw = (raw & ~pself->MCI_mask) | (selectedBooleans & pself->MCI_mask);
    BSMixerSetValue(pself->MCI_token, 2, (byte)raw, 0);
}
'''
p.write_bytes(s.join([header,'']).encode('ascii'))
