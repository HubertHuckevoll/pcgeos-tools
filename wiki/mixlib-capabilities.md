# MixLib mixer capabilities

- CInclude/mixlib.goh defines the public API and MixerValue descriptor.
  BSMixerGetCap returns the control count and DSP version; enumerate indices
  0 through count-1 with BSMixerSpecValue. Honor valVisible, valStereoFlag,
  valType and valRange rather than treating every defined token as supported.
  valTarget groups controls into mixer (1), recording (2) and other (3).
- Driver/Sound/BSD16/bsmixer.asm and BSD8ST/bsmixer.asm select valTab1745
  for DSP >= 0x0400, valTab1345 for >= 0x0201, valTab1335 for >= 0x0200,
  otherwise valTabDum (GetOffToValTab). The SB16 table contains master,
  FM, WAV, CD, line, mic, bass, treble, playback/record routing, input/output
  gain and AGC. Its PC-speaker entry exists but is marked invisible.
  The Pro table has master/FM/WAV/CD/line/mic, input/lowpass filters and
  recording-source selection. The SB2 table has master/FM/WAV/CD only.
- Library/Audio/MixLib/Main/mixlib.goc: BSMixerSetValue dataType 1 accepts
  volume/balance; dataType 2 accepts left/right levels. BSMixerGetValue
  dataType 1 returns volume, 2 balance, 3 raw low-byte left/high-byte right.
  BSMixerGetSubToken and BSMixerGetTokenText supply option labels.
- Library/Audio/MixLib/mixlib.gp exports no level-meter, change-notification,
  preset-storage or dedicated mute function. Muting/restoring a level and
  saving settings therefore require application logic.
- Subtoken identifiers are bit selectors (1, 2, 4, ..., 128), even for
  exclusive item controls. Their hardware values are zero-based indices;
  Boolean controls use the corresponding bits. Zero subtokens mark unused
  options. Evidence: BSMixerGetSubToken, BSMixerGetRegister and
  subTab1745/subTab1345 in the two bsmixer.asm files above.
- For mono descriptors, use only the low raw byte. BSMixerGetValue in the
  drivers skips assembling the second channel when the descriptor's second
  register is zero. Do not average raw bytes without checking valStereoFlag.

- MixerControlClass, MSG_MIXER_CONTROL_INITIALIZE in
  Appl/Audio/Mixer/Main/mixer.goc copies token labels into a 32-byte buffer.
  MixLib STRINGRESOURCE labels therefore have @localize limits of 31
  characters, excluding the terminator. BSMixerGetTokenText has no buffer-size
  parameter; callers must provide enough space.
