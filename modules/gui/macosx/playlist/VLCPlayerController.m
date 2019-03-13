/*****************************************************************************
 * VLCPlayerController.m: MacOS X interface module
 *****************************************************************************
 * Copyright (C) 2019 VLC authors and VideoLAN
 *
 * Authors: Felix Paul Kühne <fkuehne # videolan -dot- org>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/

#import "VLCPlayerController.h"

#import "main/VLCMain.h"
#import "os-integration/VLCRemoteControlService.h"
#import "os-integration/iTunes.h"
#import "os-integration/Spotify.h"
#import "windows/video/VLCVoutView.h"

#import <MediaPlayer/MediaPlayer.h>

NSString *VLCPlayerCurrentMediaItem = @"VLCPlayerCurrentMediaItem";
NSString *VLCPlayerCurrentMediaItemChanged = @"VLCPlayerCurrentMediaItemChanged";
NSString *VLCPlayerStateChanged = @"VLCPlayerStateChanged";
NSString *VLCPlayerErrorChanged = @"VLCPlayerErrorChanged";
NSString *VLCPlayerBufferFill = @"VLCPlayerBufferFill";
NSString *VLCPlayerBufferChanged = @"VLCPlayerBufferChanged";
NSString *VLCPlayerRateChanged = @"VLCPlayerRateChanged";
NSString *VLCPlayerCapabilitiesChanged = @"VLCPlayerCapabilitiesChanged";
NSString *VLCPlayerTimeAndPositionChanged = @"VLCPlayerTimeAndPositionChanged";
NSString *VLCPlayerLengthChanged = @"VLCPlayerLengthChanged";
NSString *VLCPlayerTitleSelectionChanged = @"VLCPlayerTitleSelectionChanged";
NSString *VLCPlayerTitleListChanged = @"VLCPlayerTitleListChanged";
NSString *VLCPlayerTeletextMenuAvailable = @"VLCPlayerTeletextMenuAvailable";
NSString *VLCPlayerTeletextEnabled = @"VLCPlayerTeletextEnabled";
NSString *VLCPlayerTeletextPageChanged = @"VLCPlayerTeletextPageChanged";
NSString *VLCPlayerTeletextTransparencyChanged = @"VLCPlayerTeletextTransparencyChanged";
NSString *VLCPlayerAudioDelayChanged = @"VLCPlayerAudioDelayChanged";
NSString *VLCPlayerSubtitlesDelayChanged = @"VLCPlayerSubtitlesDelayChanged";
NSString *VLCPlayerSubtitleTextScalingFactorChanged = @"VLCPlayerSubtitleTextScalingFactorChanged";
NSString *VLCPlayerRecordingChanged = @"VLCPlayerRecordingChanged";
NSString *VLCPlayerRendererChanged = @"VLCPlayerRendererChanged";
NSString *VLCPlayerInputStats = @"VLCPlayerInputStats";
NSString *VLCPlayerStatisticsUpdated = @"VLCPlayerStatisticsUpdated";
NSString *VLCPlayerFullscreenChanged = @"VLCPlayerFullscreenChanged";
NSString *VLCPlayerWallpaperModeChanged = @"VLCPlayerWallpaperModeChanged";
NSString *VLCPlayerListOfVideoOutputThreadsChanged = @"VLCPlayerListOfVideoOutputThreadsChanged";
NSString *VLCPlayerVolumeChanged = @"VLCPlayerVolumeChanged";
NSString *VLCPlayerMuteChanged = @"VLCPlayerMuteChanged";

@interface VLCPlayerController ()
{
    vlc_player_t *_p_player;
    vlc_player_listener_id *_playerListenerID;
    vlc_player_aout_listener_id *_playerAoutListenerID;
    vlc_player_vout_listener_id *_playerVoutListenerID;
    vlc_player_title_list *_currentTitleList;
    NSNotificationCenter *_defaultNotificationCenter;

    /* remote control support */
    VLCRemoteControlService *_remoteControlService;

    /* iTunes/Spotify play/pause support */
    BOOL _iTunesPlaybackWasPaused;
    BOOL _SpotifyPlaybackWasPaused;

    NSTimer *_playbackHasTruelyEndedTimer;
}

- (void)currentMediaItemChanged:(input_item_t *)newMediaItem;
- (void)stateChanged:(enum vlc_player_state)state;
- (void)errorChanged:(enum vlc_player_error)error;
- (void)newBufferingValue:(float)bufferValue;
- (void)newRateValue:(float)rateValue;
- (void)capabilitiesChanged:(int)newCapabilities;
- (void)position:(float)position andTimeChanged:(vlc_tick_t)time;
- (void)lengthChanged:(vlc_tick_t)length;
- (void)titleListChanged:(vlc_player_title_list *)p_titles;
- (void)selectedTitleChanged:(size_t)selectedTitle;
- (void)teletextAvailibilityChanged:(BOOL)hasTeletextMenu;
- (void)teletextEnabledChanged:(BOOL)teletextOn;
- (void)teletextPageChanged:(unsigned int)page;
- (void)teletextTransparencyChanged:(BOOL)isTransparent;
- (void)audioDelayChanged:(vlc_tick_t)audioDelay;
- (void)rendererChanged:(vlc_renderer_item_t *)newRendererItem;
- (void)subtitlesDelayChanged:(vlc_tick_t)subtitlesDelay;
- (void)recordingChanged:(BOOL)recording;
- (void)inputStatsUpdated:(VLCInputStats *)inputStats;
- (void)stopActionChanged:(enum vlc_player_media_stopped_action)stoppedAction;
- (void)metaDataChangedForInput:(input_item_t *)inputItem;
- (void)voutListUpdated;

/* video */
- (void)fullscreenChanged:(BOOL)isFullscreen;
- (void)wallpaperModeChanged:(BOOL)wallpaperModeValue;

/* audio */
- (void)volumeChanged:(float)volume;
- (void)muteChanged:(BOOL)mute;
@end

#pragma mark - player callback implementations

static void cb_player_current_media_changed(vlc_player_t *p_player, input_item_t *p_newMediaItem, void *p_data)
{
    VLC_UNUSED(p_player);
    dispatch_async(dispatch_get_main_queue(), ^{
        VLCPlayerController *playerController = (__bridge VLCPlayerController *)p_data;
        [playerController currentMediaItemChanged:p_newMediaItem];
    });
}

static void cb_player_state_changed(vlc_player_t *p_player, enum vlc_player_state state, void *p_data)
{
    VLC_UNUSED(p_player);
    dispatch_async(dispatch_get_main_queue(), ^{
        VLCPlayerController *playerController = (__bridge VLCPlayerController *)p_data;
        [playerController stateChanged:state];
    });
}

static void cb_player_error_changed(vlc_player_t *p_player, enum vlc_player_error error, void *p_data)
{
    VLC_UNUSED(p_player);
    dispatch_async(dispatch_get_main_queue(), ^{
        VLCPlayerController *playerController = (__bridge VLCPlayerController *)p_data;
        [playerController errorChanged:error];
    });
}

static void cb_player_buffering(vlc_player_t *p_player, float newBufferValue, void *p_data)
{
    VLC_UNUSED(p_player);
    dispatch_async(dispatch_get_main_queue(), ^{
        VLCPlayerController *playerController = (__bridge VLCPlayerController *)p_data;
        [playerController newBufferingValue:newBufferValue];
    });
}

static void cb_player_rate_changed(vlc_player_t *p_player, float newRateValue, void *p_data)
{
    VLC_UNUSED(p_player);
    dispatch_async(dispatch_get_main_queue(), ^{
        VLCPlayerController *playerController = (__bridge VLCPlayerController *)p_data;
        [playerController newRateValue:newRateValue];
    });
}

static void cb_player_capabilities_changed(vlc_player_t *p_player, int newCapabilities, void *p_data)
{
    VLC_UNUSED(p_player);
    dispatch_async(dispatch_get_main_queue(), ^{
        VLCPlayerController *playerController = (__bridge VLCPlayerController *)p_data;
        [playerController capabilitiesChanged:newCapabilities];
    });
}

static void cb_player_position_changed(vlc_player_t *p_player, vlc_tick_t time, float position, void *p_data)
{
    VLC_UNUSED(p_player);
    dispatch_async(dispatch_get_main_queue(), ^{
        VLCPlayerController *playerController = (__bridge VLCPlayerController *)p_data;
        [playerController position:position andTimeChanged:time];
    });
}

static void cb_player_length_changed(vlc_player_t *p_player, vlc_tick_t newLength, void *p_data)
{
    VLC_UNUSED(p_player);
    dispatch_async(dispatch_get_main_queue(), ^{
        VLCPlayerController *playerController = (__bridge VLCPlayerController *)p_data;
        [playerController lengthChanged:newLength];
    });
}

static void cb_player_titles_changed(vlc_player_t *p_player,
                                     vlc_player_title_list *p_titles,
                                     void *p_data)
{
    VLC_UNUSED(p_player);
    vlc_player_title_list_Hold(p_titles);
    dispatch_async(dispatch_get_main_queue(), ^{
        VLCPlayerController *playerController = (__bridge VLCPlayerController *)p_data;
        [playerController titleListChanged:p_titles];
    });
}

static void cb_player_title_selection_changed(vlc_player_t *p_player,
                                              const struct vlc_player_title *p_new_title,
                                              size_t selectedIndex,
                                              void *p_data)
{
    VLC_UNUSED(p_player);
    VLC_UNUSED(p_new_title);
    dispatch_async(dispatch_get_main_queue(), ^{
        VLCPlayerController *playerController = (__bridge VLCPlayerController *)p_data;
        [playerController selectedTitleChanged:selectedIndex];
    });
}

static void cb_player_teletext_menu_availability_changed(vlc_player_t *p_player, bool hasTeletextMenu, void *p_data)
{
    VLC_UNUSED(p_player);
    dispatch_async(dispatch_get_main_queue(), ^{
        VLCPlayerController *playerController = (__bridge VLCPlayerController *)p_data;
        [playerController teletextAvailibilityChanged:hasTeletextMenu];
    });
}

static void cb_player_teletext_enabled_changed(vlc_player_t *p_player, bool teletextEnabled, void *p_data)
{
    VLC_UNUSED(p_player);
    dispatch_async(dispatch_get_main_queue(), ^{
        VLCPlayerController *playerController = (__bridge VLCPlayerController *)p_data;
        [playerController teletextEnabledChanged:teletextEnabled];
    });
}

static void cb_player_teletext_page_changed(vlc_player_t *p_player, unsigned page, void *p_data)
{
    VLC_UNUSED(p_player);
    dispatch_async(dispatch_get_main_queue(), ^{
        VLCPlayerController *playerController = (__bridge VLCPlayerController *)p_data;
        [playerController teletextPageChanged:page];
    });
}

static void cb_player_teletext_transparency_changed(vlc_player_t *p_player, bool isTransparent, void *p_data)
{
    VLC_UNUSED(p_player);
    dispatch_async(dispatch_get_main_queue(), ^{
        VLCPlayerController *playerController = (__bridge VLCPlayerController *)p_data;
        [playerController teletextTransparencyChanged:isTransparent];
    });
}

static void cb_player_audio_delay_changed(vlc_player_t *p_player, vlc_tick_t newDelay, void *p_data)
{
    VLC_UNUSED(p_player);
    dispatch_async(dispatch_get_main_queue(), ^{
        VLCPlayerController *playerController = (__bridge VLCPlayerController *)p_data;
        [playerController audioDelayChanged:newDelay];
    });
}

static void cb_player_subtitle_delay_changed(vlc_player_t *p_player, vlc_tick_t newDelay, void *p_data)
{
    VLC_UNUSED(p_player);
    dispatch_async(dispatch_get_main_queue(), ^{
        VLCPlayerController *playerController = (__bridge VLCPlayerController *)p_data;
        [playerController subtitlesDelayChanged:newDelay];
    });
}

static void cb_player_renderer_changed(vlc_player_t *p_player,
                                       vlc_renderer_item_t *p_new_renderer,
                                       void *p_data)
{
    VLC_UNUSED(p_player);
    dispatch_async(dispatch_get_main_queue(), ^{
        VLCPlayerController *playerController = (__bridge VLCPlayerController *)p_data;
        [playerController rendererChanged:p_new_renderer];
    });
}

static void cb_player_record_changed(vlc_player_t *p_player, bool recording, void *p_data)
{
    VLC_UNUSED(p_player);
    dispatch_async(dispatch_get_main_queue(), ^{
        VLCPlayerController *playerController = (__bridge VLCPlayerController *)p_data;
        [playerController recordingChanged:recording];
    });
}

static void cb_player_stats_changed(vlc_player_t *p_player,
                                    const struct input_stats_t *p_stats,
                                    void *p_data)
{
    VLC_UNUSED(p_player);

    /* the provided structure is valid in this context only, so copy all data to our own */
    VLCInputStats *inputStats = [[VLCInputStats alloc] init];

    inputStats.inputReadPackets = p_stats->i_read_packets;
    inputStats.inputReadBytes = p_stats->i_read_bytes;
    inputStats.inputBitrate = p_stats->f_input_bitrate;

    inputStats.demuxReadPackets = p_stats->i_demux_read_packets;
    inputStats.demuxReadBytes = p_stats->i_demux_read_bytes;
    inputStats.demuxBitrate = p_stats->f_demux_bitrate;
    inputStats.demuxCorrupted = p_stats->i_demux_corrupted;
    inputStats.demuxDiscontinuity = p_stats->i_demux_discontinuity;

    inputStats.decodedAudio = p_stats->i_decoded_audio;
    inputStats.decodedVideo = p_stats->i_decoded_video;

    inputStats.displayedPictures = p_stats->i_displayed_pictures;
    inputStats.lostPictures = p_stats->i_lost_pictures;

    inputStats.playedAudioBuffers = p_stats->i_played_abuffers;
    inputStats.lostAudioBuffers = p_stats->i_lost_abuffers;

    dispatch_async(dispatch_get_main_queue(), ^{
        VLCPlayerController *playerController = (__bridge VLCPlayerController *)p_data;
        [playerController inputStatsUpdated:inputStats];
    });
}

static void cb_player_media_stopped_action_changed(vlc_player_t *p_player,
                                                   enum vlc_player_media_stopped_action newAction,
                                                   void *p_data)
{
    VLC_UNUSED(p_player);
    dispatch_async(dispatch_get_main_queue(), ^{
        VLCPlayerController *playerController = (__bridge VLCPlayerController *)p_data;
        [playerController stopActionChanged:newAction];
    });
}

static void cb_player_item_meta_changed(vlc_player_t *p_player,
                                        input_item_t *p_mediaItem,
                                        void *p_data)
{
    VLC_UNUSED(p_player);
    input_item_Hold(p_mediaItem);
    dispatch_async(dispatch_get_main_queue(), ^{
        VLCPlayerController *playerController = (__bridge VLCPlayerController *)p_data;
        [playerController metaDataChangedForInput:p_mediaItem];
    });
}

static void cb_player_vout_list_changed(vlc_player_t *p_player,
                                        enum vlc_player_list_action action,
                                        vout_thread_t *p_vout,
                                        void *p_data)
{
    VLC_UNUSED(p_player);
    VLC_UNUSED(p_vout);
    dispatch_async(dispatch_get_main_queue(), ^{
        VLCPlayerController *playerController = (__bridge VLCPlayerController *)p_data;
        [playerController voutListUpdated];
    });
}

static const struct vlc_player_cbs player_callbacks = {
    cb_player_current_media_changed,
    cb_player_state_changed,
    cb_player_error_changed,
    cb_player_buffering,
    cb_player_rate_changed,
    cb_player_capabilities_changed,
    cb_player_position_changed,
    cb_player_length_changed,
    NULL, //cb_player_track_list_changed,
    NULL, //cb_player_track_selection_changed,
    NULL, //cb_player_program_list_changed,
    NULL, //cb_player_program_selection_changed,
    cb_player_titles_changed,
    cb_player_title_selection_changed,
    NULL, //cb_player_chapter_selection_changed,
    cb_player_teletext_menu_availability_changed,
    cb_player_teletext_enabled_changed,
    cb_player_teletext_page_changed,
    cb_player_teletext_transparency_changed,
    cb_player_audio_delay_changed,
    cb_player_subtitle_delay_changed,
    NULL, //cb_player_associated_subs_fps_changed,
    cb_player_renderer_changed,
    cb_player_record_changed,
    NULL, //cb_player_signal_changed,
    cb_player_stats_changed,
    NULL, //cb_player_atobloop_changed,
    cb_player_media_stopped_action_changed,
    cb_player_item_meta_changed,
    NULL, //cb_player_item_epg_changed,
    NULL, //cb_player_subitems_changed,
    cb_player_vout_list_changed,
};

#pragma mark - video specific callback implementations

static void cb_player_vout_fullscreen_changed(vlc_player_t *p_player, vout_thread_t *p_vout, bool isFullscreen, void *p_data)
{
    VLC_UNUSED(p_player); VLC_UNUSED(p_vout);
    dispatch_async(dispatch_get_main_queue(), ^{
        VLCPlayerController *playerController = (__bridge VLCPlayerController *)p_data;
        [playerController fullscreenChanged:isFullscreen];
    });
}

static void cb_player_vout_wallpaper_mode_changed(vlc_player_t *p_player, vout_thread_t *p_vout,  bool wallpaperModeEnabled, void *p_data)
{
    VLC_UNUSED(p_player); VLC_UNUSED(p_vout);
    dispatch_async(dispatch_get_main_queue(), ^{
        VLCPlayerController *playerController = (__bridge VLCPlayerController *)p_data;
        [playerController wallpaperModeChanged:wallpaperModeEnabled];
    });
}

static const struct vlc_player_vout_cbs player_vout_callbacks = {
    cb_player_vout_fullscreen_changed,
    cb_player_vout_wallpaper_mode_changed,
};

#pragma mark - video specific callback implementations

static void cb_player_aout_volume_changed(vlc_player_t *p_player, float volume, void *p_data)
{
    VLC_UNUSED(p_player);
    dispatch_async(dispatch_get_main_queue(), ^{
        VLCPlayerController *playerController = (__bridge VLCPlayerController *)p_data;
        [playerController volumeChanged:volume];
    });
}

static void cb_player_aout_mute_changed(vlc_player_t *p_player, bool muted, void *p_data)
{
    VLC_UNUSED(p_player);
    dispatch_async(dispatch_get_main_queue(), ^{
        VLCPlayerController *playerController = (__bridge VLCPlayerController *)p_data;
        [playerController muteChanged:muted];
    });
}

static const struct vlc_player_aout_cbs player_aout_callbacks = {
    cb_player_aout_volume_changed,
    cb_player_aout_mute_changed,
};

#pragma mark - controller initialization

@implementation VLCPlayerController

- (instancetype)initWithPlayer:(vlc_player_t *)player
{
    self = [super init];
    if (self) {
        _defaultNotificationCenter = [NSNotificationCenter defaultCenter];
        _position = -1.f;
        _time = VLC_TICK_INVALID;
        _p_player = player;
        vlc_player_Lock(_p_player);
        // FIXME: initialize state machine here
        _playerListenerID = vlc_player_AddListener(_p_player,
                               &player_callbacks,
                               (__bridge void *)self);
        vlc_player_Unlock(_p_player);
        _playerAoutListenerID = vlc_player_aout_AddListener(_p_player,
                                                            &player_aout_callbacks,
                                                            (__bridge void *)self);
        _playerVoutListenerID = vlc_player_vout_AddListener(_p_player,
                                                            &player_vout_callbacks,
                                                            (__bridge void *)self);
        if (@available(macOS 10.12.2, *)) {
            _remoteControlService = [[VLCRemoteControlService alloc] init];
            [_remoteControlService subscribeToRemoteCommands];
        }
    }

    return self;
}

- (void)deinitialize
{
    [self onPlaybackHasTruelyEnded:nil];
    if (@available(macOS 10.12.2, *)) {
        [_remoteControlService unsubscribeFromRemoteCommands];
    }
    if (_currentTitleList) {
        vlc_player_title_list_Release(_currentTitleList);
    }
    if (_p_player) {
        if (_playerListenerID) {
            vlc_player_Lock(_p_player);
            vlc_player_RemoveListener(_p_player, _playerListenerID);
            vlc_player_Unlock(_p_player);
        }
        if (_playerAoutListenerID) {
            vlc_player_aout_RemoveListener(_p_player, _playerAoutListenerID);
        }
        if (_playerVoutListenerID) {
            vlc_player_vout_RemoveListener(_p_player, _playerVoutListenerID);
        }
    }
}

#pragma mark - playback control methods

- (int)start
{
    vlc_player_Lock(_p_player);
    int ret = vlc_player_Start(_p_player);
    vlc_player_Unlock(_p_player);
    return ret;
}

- (void)startInPausedState:(BOOL)startPaused
{
    vlc_player_Lock(_p_player);
    vlc_player_SetStartPaused(_p_player, startPaused);
    vlc_player_Unlock(_p_player);
}

- (void)pause
{
    vlc_player_Lock(_p_player);
    vlc_player_Pause(_p_player);
    vlc_player_Unlock(_p_player);
}

- (void)resume
{
    vlc_player_Lock(_p_player);
    vlc_player_Resume(_p_player);
    vlc_player_Unlock(_p_player);
}

- (void)togglePlayPause
{
    vlc_player_Lock(_p_player);
    if (_playerState == VLC_PLAYER_STATE_PLAYING) {
        vlc_player_Pause(_p_player);
    } else if (_playerState == VLC_PLAYER_STATE_PAUSED) {
        vlc_player_Resume(_p_player);
    } else
        vlc_player_Start(_p_player);
    vlc_player_Unlock(_p_player);
}

- (void)stop
{
    vlc_player_Lock(_p_player);
    vlc_player_Stop(_p_player);
    vlc_player_Unlock(_p_player);
}

- (void)stopActionChanged:(enum vlc_player_media_stopped_action)stoppedAction
{
    _actionAfterStop = stoppedAction;
}

- (void)setActionAfterStop:(enum vlc_player_media_stopped_action)actionAfterStop
{
    vlc_player_Lock(_p_player);
    vlc_player_SetMediaStoppedAction(_p_player, actionAfterStop);
    vlc_player_Unlock(_p_player);
}

- (void)metaDataChangedForInput:(input_item_t *)inputItem
{
    if (@available(macOS 10.12.2, *)) {
        NSMutableDictionary *currentlyPlayingTrackInfo = [NSMutableDictionary dictionary];

        currentlyPlayingTrackInfo[MPMediaItemPropertyPlaybackDuration] = @(SEC_FROM_VLC_TICK(input_item_GetDuration(inputItem)));
        currentlyPlayingTrackInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = @(SEC_FROM_VLC_TICK([self time]));
        currentlyPlayingTrackInfo[MPNowPlayingInfoPropertyPlaybackRate] = @([self playbackRate]);

        char *psz_title = input_item_GetTitle(inputItem);
        if (!psz_title)
            psz_title = input_item_GetName(inputItem);
        currentlyPlayingTrackInfo[MPMediaItemPropertyTitle] = toNSStr(psz_title);
        FREENULL(psz_title);

        char *psz_artist = input_item_GetArtist(inputItem);
        currentlyPlayingTrackInfo[MPMediaItemPropertyArtist] = toNSStr(psz_artist);
        FREENULL(psz_artist);

        char *psz_album = input_item_GetAlbum(inputItem);
        currentlyPlayingTrackInfo[MPMediaItemPropertyAlbumTitle] = toNSStr(psz_album);
        FREENULL(psz_album);

        char *psz_track_number = input_item_GetTrackNumber(inputItem);
        currentlyPlayingTrackInfo[MPMediaItemPropertyAlbumTrackNumber] = @([toNSStr(psz_track_number) intValue]);
        FREENULL(psz_track_number);

        [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = currentlyPlayingTrackInfo;
    }

    input_item_Release(inputItem);
}

- (void)nextVideoFrame
{
    vlc_player_Lock(_p_player);
    vlc_player_NextVideoFrame(_p_player);
    vlc_player_Unlock(_p_player);
}

#pragma mark - player callback delegations

- (input_item_t *)currentMedia
{
    input_item_t *inputItem;
    vlc_player_Lock(_p_player);
    inputItem = vlc_player_GetCurrentMedia(_p_player);
    if (inputItem) {
        input_item_Hold(inputItem);
    }
    vlc_player_Unlock(_p_player);
    return inputItem;
}

- (int)setCurrentMedia:(input_item_t *)currentMedia
{
    if (currentMedia == NULL) {
        return VLC_ENOITEM;
    }
    vlc_player_Lock(_p_player);
    int ret = vlc_player_SetCurrentMedia(_p_player, currentMedia);
    vlc_player_Unlock(_p_player);
    return ret;
}

- (void)currentMediaItemChanged:(input_item_t *)newMediaItem
{
    [_defaultNotificationCenter postNotificationName:VLCPlayerCurrentMediaItemChanged
                                              object:self
                                            userInfo:@{VLCPlayerCurrentMediaItem:[NSValue valueWithPointer:newMediaItem]}];
}

- (void)stateChanged:(enum vlc_player_state)state
{
    /* instead of using vlc_player_GetState, we cache the state and provide it through a synthesized getter
     * as the direct call might not reflect the actual state due the asynchronous API nature */
    _playerState = state;

    /* we seem to start (over), don't start other players */
    if (_playerState != VLC_PLAYER_STATE_STOPPED) {
        if (_playbackHasTruelyEndedTimer) {
            [_playbackHasTruelyEndedTimer invalidate];
            _playbackHasTruelyEndedTimer = nil;
        }
    }

    [_defaultNotificationCenter postNotificationName:VLCPlayerStateChanged
                                              object:self];

    if (@available(macOS 10.12.2, *)) {
        switch (_playerState) {
            case VLC_PLAYER_STATE_PLAYING:
                [MPNowPlayingInfoCenter defaultCenter].playbackState = MPNowPlayingPlaybackStatePlaying;
                break;

            case VLC_PLAYER_STATE_PAUSED:
                [MPNowPlayingInfoCenter defaultCenter].playbackState = MPNowPlayingPlaybackStatePaused;
                break;

            case VLC_PLAYER_STATE_STOPPED:
            case VLC_PLAYER_STATE_STOPPING:
                [MPNowPlayingInfoCenter defaultCenter].playbackState = MPNowPlayingPlaybackStateStopped;
                break;

            default:
                [MPNowPlayingInfoCenter defaultCenter].playbackState = MPNowPlayingPlaybackStateUnknown;
                break;
        }
    }

    /* notify third party apps through an informal protocol that our state changed */
    [[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"VLCPlayerStateDidChange"
                                                                   object:nil
                                                                 userInfo:nil
                                                       deliverImmediately:YES];

    /* schedule a timer to restart iTunes / Spotify because we are done here */
    if (_playerState == VLC_PLAYER_STATE_STOPPED) {
        if (_playbackHasTruelyEndedTimer) {
            [_playbackHasTruelyEndedTimer invalidate];
        }
        _playbackHasTruelyEndedTimer = [NSTimer scheduledTimerWithTimeInterval:0.5
                                                                        target:self
                                                                      selector:@selector(onPlaybackHasTruelyEnded:)
                                                                      userInfo:nil
                                                                       repeats:NO];
    }

    /* pause external players */
    if (_playerState == VLC_PLAYER_STATE_PLAYING || _playerState == VLC_PLAYER_STATE_STARTED) {
        [self stopOtherAudioPlaybackApps];
    }
}

// Called when playback has truely ended and likely no subsequent media will start playing
- (void)onPlaybackHasTruelyEnded:(id)sender
{
    msg_Dbg(getIntf(), "Playback has been ended");

    [self resumeOtherAudioPlaybackApps];
    _playbackHasTruelyEndedTimer = nil;
}

- (void)stopOtherAudioPlaybackApps
{
    intf_thread_t *p_intf = getIntf();
    int64_t controlOtherPlayers = var_InheritInteger(p_intf, "macosx-control-itunes");
    if (controlOtherPlayers <= 0)
        return;

    // pause iTunes
    if (!_iTunesPlaybackWasPaused) {
        iTunesApplication *iTunesApp = (iTunesApplication *) [SBApplication applicationWithBundleIdentifier:@"com.apple.iTunes"];
        if (iTunesApp && [iTunesApp isRunning]) {
            if ([iTunesApp playerState] == iTunesEPlSPlaying) {
                msg_Dbg(p_intf, "pausing iTunes");
                [iTunesApp pause];
                _iTunesPlaybackWasPaused = YES;
            }
        }
    }

    // pause Spotify
    if (!_SpotifyPlaybackWasPaused) {
        SpotifyApplication *spotifyApp = (SpotifyApplication *) [SBApplication applicationWithBundleIdentifier:@"com.spotify.client"];
        if (spotifyApp) {
            if ([spotifyApp respondsToSelector:@selector(isRunning)] && [spotifyApp respondsToSelector:@selector(playerState)]) {
                if ([spotifyApp isRunning] && [spotifyApp playerState] == kSpotifyPlayerStatePlaying) {
                    msg_Dbg(p_intf, "pausing Spotify");
                    [spotifyApp pause];
                    _SpotifyPlaybackWasPaused = YES;
                }
            }
        }
    }
}

- (void)resumeOtherAudioPlaybackApps
{
    intf_thread_t *p_intf = getIntf();
    if (var_InheritInteger(p_intf, "macosx-control-itunes") > 1) {
        if (_iTunesPlaybackWasPaused) {
            iTunesApplication *iTunesApp = (iTunesApplication *) [SBApplication applicationWithBundleIdentifier:@"com.apple.iTunes"];
            if (iTunesApp && [iTunesApp isRunning]) {
                if ([iTunesApp playerState] == iTunesEPlSPaused) {
                    msg_Dbg(p_intf, "unpausing iTunes");
                    [iTunesApp playpause];
                }
            }
        }

        if (_SpotifyPlaybackWasPaused) {
            SpotifyApplication *spotifyApp = (SpotifyApplication *) [SBApplication applicationWithBundleIdentifier:@"com.spotify.client"];
            if (spotifyApp) {
                if ([spotifyApp respondsToSelector:@selector(isRunning)] && [spotifyApp respondsToSelector:@selector(playerState)]) {
                    if ([spotifyApp isRunning] && [spotifyApp playerState] == kSpotifyPlayerStatePaused) {
                        msg_Dbg(p_intf, "unpausing Spotify");
                        [spotifyApp play];
                    }
                }
            }
        }
    }

    _iTunesPlaybackWasPaused = NO;
    _SpotifyPlaybackWasPaused = NO;
}

- (void)errorChanged:(enum vlc_player_error)error
{
    /* instead of using vlc_player_GetError, we cache the error and provide it through a synthesized getter
     * as the direct call might not reflect the actual error due the asynchronous API nature */
    _error = error;
    [_defaultNotificationCenter postNotificationName:VLCPlayerErrorChanged
                                              object:self];
}

- (void)newBufferingValue:(float)bufferValue
{
    _bufferFill = bufferValue;
    [_defaultNotificationCenter postNotificationName:VLCPlayerBufferChanged
                                              object:self
                                            userInfo:@{VLCPlayerBufferFill : @(bufferValue)}];
}

- (void)newRateValue:(float)rateValue
{
    _playbackRate = rateValue;
    [_defaultNotificationCenter postNotificationName:VLCPlayerRateChanged
                                              object:self];
}

- (void)setPlaybackRate:(float)playbackRate
{
    vlc_player_Lock(_p_player);
    vlc_player_ChangeRate(_p_player, playbackRate);
    vlc_player_Unlock(_p_player);
}

- (void)incrementPlaybackRate
{
    vlc_player_Lock(_p_player);
    vlc_player_IncrementRate(_p_player);
    vlc_player_Unlock(_p_player);
}

- (void)decrementPlaybackRate
{
    vlc_player_Lock(_p_player);
    vlc_player_DecrementRate(_p_player);
    vlc_player_Unlock(_p_player);
}

- (void)capabilitiesChanged:(int)newCapabilities
{
    _seekable = newCapabilities & VLC_INPUT_CAPABILITIES_SEEKABLE ? YES : NO;
    _rewindable = newCapabilities & VLC_INPUT_CAPABILITIES_REWINDABLE ? YES : NO;
    _pausable = newCapabilities & VLC_INPUT_CAPABILITIES_PAUSEABLE ? YES : NO;
    _recordable = newCapabilities & VLC_INPUT_CAPABILITIES_RECORDABLE ? YES : NO;
    _rateChangable = newCapabilities & VLC_INPUT_CAPABILITIES_CHANGE_RATE ? YES : NO;
    [_defaultNotificationCenter postNotificationName:VLCPlayerCapabilitiesChanged
                                              object:self];
}

- (void)position:(float)position andTimeChanged:(vlc_tick_t)time
{
    _position = position;
    _time = time;
    [_defaultNotificationCenter postNotificationName:VLCPlayerTimeAndPositionChanged
                                              object:self];
}

- (void)setTimeFast:(vlc_tick_t)time
{
    vlc_player_Lock(_p_player);
    vlc_player_SeekByTime(_p_player, time, VLC_PLAYER_SEEK_FAST, VLC_PLAYER_WHENCE_ABSOLUTE);
    vlc_player_Unlock(_p_player);
}

- (void)setTimePrecise:(vlc_tick_t)time
{
    vlc_player_Lock(_p_player);
    vlc_player_SeekByTime(_p_player, time, VLC_PLAYER_SEEK_PRECISE, VLC_PLAYER_WHENCE_ABSOLUTE);
    vlc_player_Unlock(_p_player);
}

- (void)setPositionFast:(float)position
{
    vlc_player_Lock(_p_player);
    vlc_player_SeekByPos(_p_player, position, VLC_PLAYER_SEEK_FAST, VLC_PLAYER_WHENCE_ABSOLUTE);
    vlc_player_Unlock(_p_player);
}

- (void)setPositionPrecise:(float)position
{
    vlc_player_Lock(_p_player);
    vlc_player_SeekByPos(_p_player, position, VLC_PLAYER_SEEK_PRECISE, VLC_PLAYER_WHENCE_ABSOLUTE);
    vlc_player_Unlock(_p_player);
}

- (void)jumpWithValue:(char *)p_userDefinedJumpSize forward:(BOOL)shallJumpForward
{
    int64_t interval = var_InheritInteger(getIntf(), p_userDefinedJumpSize);
    if (interval > 0) {
        vlc_tick_t jumptime = vlc_tick_from_sec( interval );
        if (!shallJumpForward)
            jumptime = jumptime * -1;

        /* No fask seek for jumps. Indeed, jumps can seek to the current position
         * if not precise enough or if the jump value is too small. */
        vlc_player_SeekByTime(_p_player,
                              jumptime,
                              VLC_PLAYER_SEEK_PRECISE,
                              VLC_PLAYER_WHENCE_RELATIVE);
    }
}

- (void)jumpForwardExtraShort
{
    [self jumpWithValue:"extrashort-jump-size" forward:YES];
}

- (void)jumpBackwardExtraShort
{
    [self jumpWithValue:"extrashort-jump-size" forward:NO];
}

- (void)jumpForwardShort
{
    [self jumpWithValue:"short-jump-size" forward:YES];
}

- (void)jumpBackwardShort
{
    [self jumpWithValue:"short-jump-size" forward:NO];
}

- (void)jumpForwardMedium
{
    [self jumpWithValue:"medium-jump-size" forward:YES];
}

- (void)jumpBackwardMedium
{
    [self jumpWithValue:"medium-jump-size" forward:NO];
}

- (void)jumpForwardLong
{
    [self jumpWithValue:"long-jump-size" forward:YES];
}

- (void)jumpBackwardLong
{
    [self jumpWithValue:"long-jump-size" forward:NO];
}

- (void)lengthChanged:(vlc_tick_t)length
{
    _length = length;
    [_defaultNotificationCenter postNotificationName:VLCPlayerLengthChanged
                                              object:self];
}

- (void)titleListChanged:(vlc_player_title_list *)p_titles
{
    if (_currentTitleList) {
        vlc_player_title_list_Release(_currentTitleList);
    }
    /* the new list was already hold earlier */
    _currentTitleList = p_titles;
    [_defaultNotificationCenter postNotificationName:VLCPlayerTitleListChanged
                                              object:self];
}

- (void)selectedTitleChanged:(size_t)selectedTitle
{
    _selectedTitleIndex = selectedTitle;
    [_defaultNotificationCenter postNotificationName:VLCPlayerTitleSelectionChanged
                                              object:self];
}

- (const struct vlc_player_title *)selectedTitle
{
    if (_selectedTitleIndex >= 0 && _selectedTitleIndex < [self numberOfTitlesOfCurrentMedia]) {
        return vlc_player_title_list_GetAt(_currentTitleList, _selectedTitleIndex);
    }
    return NULL;
}

- (void)setSelectedTitleIndex:(size_t)selectedTitleIndex
{
    vlc_player_Lock(_p_player);
    vlc_player_SelectTitleIdx(_p_player, selectedTitleIndex);
    vlc_player_Unlock(_p_player);
}

- (const struct vlc_player_title *)titleAtIndexForCurrentMedia:(size_t)index
{
    return vlc_player_title_list_GetAt(_currentTitleList, index);
}

- (size_t)numberOfTitlesOfCurrentMedia
{
    if (!_currentTitleList) {
        return 0;
    }
    return vlc_player_title_list_GetCount(_currentTitleList);
}

- (void)teletextAvailibilityChanged:(BOOL)hasTeletextMenu
{
    _teletextMenuAvailable = hasTeletextMenu;
    [_defaultNotificationCenter postNotificationName:VLCPlayerTeletextTransparencyChanged
                                              object:self];
}

- (void)teletextEnabledChanged:(BOOL)teletextOn
{
    _teletextEnabled = teletextOn;
    [_defaultNotificationCenter postNotificationName:VLCPlayerTeletextEnabled
                                              object:self];
}

- (void)setTeletextEnabled:(BOOL)teletextEnabled
{
    vlc_player_Lock(_p_player);
    vlc_player_SetTeletextEnabled(_p_player, teletextEnabled);
    vlc_player_Unlock(_p_player);
}

- (void)teletextPageChanged:(unsigned int)page
{
    _teletextPage = page;
    [_defaultNotificationCenter postNotificationName:VLCPlayerTeletextPageChanged
                                              object:self];
}

- (void)setTeletextPage:(unsigned int)teletextPage
{
    vlc_player_Lock(_p_player);
    vlc_player_SelectTeletextPage(_p_player, teletextPage);
    vlc_player_Unlock(_p_player);
}

- (void)teletextTransparencyChanged:(BOOL)isTransparent
{
    _teletextTransparent = isTransparent;
    [_defaultNotificationCenter postNotificationName:VLCPlayerTeletextTransparencyChanged
                                              object:self];
}

- (void)setTeletextTransparent:(BOOL)teletextTransparent
{
    vlc_player_Lock(_p_player);
    vlc_player_SetTeletextTransparency(_p_player, teletextTransparent);
    vlc_player_Unlock(_p_player);
}

- (void)audioDelayChanged:(vlc_tick_t)audioDelay
{
    _audioDelay = audioDelay;
    [_defaultNotificationCenter postNotificationName:VLCPlayerAudioDelayChanged
                                              object:self];
}

- (void)setAudioDelay:(vlc_tick_t)audioDelay
{
    vlc_player_Lock(_p_player);
    vlc_player_SetAudioDelay(_p_player, audioDelay, VLC_PLAYER_WHENCE_ABSOLUTE);
    vlc_player_Unlock(_p_player);
}

- (void)subtitlesDelayChanged:(vlc_tick_t)subtitlesDelay
{
    _subtitlesDelay = subtitlesDelay;
    [_defaultNotificationCenter postNotificationName:VLCPlayerSubtitlesDelayChanged
                                              object:self];
}

- (void)setSubtitlesDelay:(vlc_tick_t)subtitlesDelay
{
    vlc_player_Lock(_p_player);
    vlc_player_SetSubtitleDelay(_p_player, subtitlesDelay, VLC_PLAYER_WHENCE_ABSOLUTE);
    vlc_player_Unlock(_p_player);
}

- (unsigned int)subtitleTextScalingFactor
{
    unsigned int ret = 100;
    vlc_player_Lock(_p_player);
    ret = vlc_player_GetSubtitleTextScale(_p_player);
    vlc_player_Unlock(_p_player);
    return ret;
}

- (void)setSubtitleTextScalingFactor:(unsigned int)subtitleTextScalingFactor
{
    if (subtitleTextScalingFactor < 10)
        subtitleTextScalingFactor = 10;
    if (subtitleTextScalingFactor > 500)
        subtitleTextScalingFactor = 500;

    vlc_player_Lock(_p_player);
    vlc_player_SetSubtitleTextScale(_p_player, subtitleTextScalingFactor);
    vlc_player_Unlock(_p_player);
}

- (void)rendererChanged:(vlc_renderer_item_t *)newRenderer
{
    _rendererItem = newRenderer;
    [_defaultNotificationCenter postNotificationName:VLCPlayerRendererChanged
                                              object:self];
}

- (void)setRendererItem:(vlc_renderer_item_t *)rendererItem
{
    vlc_player_Lock(_p_player);
    vlc_player_SetRenderer(_p_player, rendererItem);
    vlc_player_Unlock(_p_player);
}

- (void)recordingChanged:(BOOL)recording
{
    _enableRecording = recording;
    [_defaultNotificationCenter postNotificationName:VLCPlayerRecordingChanged
                                              object:self];
}

- (void)inputStatsUpdated:(VLCInputStats *)inputStats
{
    _statistics = inputStats;
    [_defaultNotificationCenter postNotificationName:VLCPlayerStatisticsUpdated
                                              object:self
                                            userInfo:@{VLCPlayerInputStats : inputStats}];
}

- (void)setEnableRecording:(BOOL)enableRecording
{
    vlc_player_Lock(_p_player);
    vlc_player_SetRecordingEnabled(_p_player, enableRecording);
    vlc_player_Unlock(_p_player);
}

- (void)toggleRecord
{
    vlc_player_Lock(_p_player);
    vlc_player_SetRecordingEnabled(_p_player, !_enableRecording);
    vlc_player_Unlock(_p_player);
}

#pragma mark - video specific delegation

- (void)fullscreenChanged:(BOOL)isFullscreen
{
    _fullscreen = isFullscreen;
    [_defaultNotificationCenter postNotificationName:VLCPlayerFullscreenChanged
                                              object:self];
}

- (void)setFullscreen:(BOOL)fullscreen
{
    vlc_player_vout_SetFullscreen(_p_player, fullscreen);
}

- (void)toggleFullscreen
{
    vlc_player_vout_SetFullscreen(_p_player, !_fullscreen);
}

- (void)wallpaperModeChanged:(BOOL)wallpaperModeValue
{
    _wallpaperMode = wallpaperModeValue;
    [_defaultNotificationCenter postNotificationName:VLCPlayerWallpaperModeChanged
                                              object:self];
}

- (void)setWallpaperMode:(BOOL)wallpaperMode
{
    vlc_player_vout_SetWallpaperModeEnabled(_p_player, wallpaperMode);
}

- (void)takeSnapshot
{
    vlc_player_vout_Snapshot(_p_player);
}

- (void)voutListUpdated
{
    [_defaultNotificationCenter postNotificationName:VLCPlayerListOfVideoOutputThreadsChanged
                                              object:self];
}

- (vout_thread_t *)mainVideoOutputThread
{
    return vlc_player_vout_Hold(_p_player);
}

- (vout_thread_t *)videoOutputThreadForKeyWindow
{
    vout_thread_t *p_vout = nil;

    id currentWindow = [NSApp keyWindow];
    if ([currentWindow respondsToSelector:@selector(videoView)]) {
        VLCVoutView *videoView = [currentWindow videoView];
        if (videoView) {
            p_vout = [videoView voutThread];
        }
    }

    if (!p_vout)
        p_vout = [self mainVideoOutputThread];

    return p_vout;
}

- (NSArray<NSValue *> *)allVideoOutputThreads
{
    size_t numberOfVoutThreads = 0;
    vout_thread_t **pp_vouts = vlc_player_vout_HoldAll(_p_player, &numberOfVoutThreads);
    if (numberOfVoutThreads == 0) {
        return nil;
    }

    NSMutableArray<NSValue *> *vouts = [NSMutableArray arrayWithCapacity:numberOfVoutThreads];

    for (size_t i = 0; i < numberOfVoutThreads; ++i)
    {
        assert(pp_vouts[i]);
        [vouts addObject:[NSValue valueWithPointer:pp_vouts[i]]];
    }

    free(pp_vouts);
    return vouts;
}

#pragma mark - audio specific delegation

- (void)volumeChanged:(float)volume
{
    _volume = volume;
    [_defaultNotificationCenter postNotificationName:VLCPlayerVolumeChanged
                                              object:self];
}

- (void)setVolume:(float)volume
{
    vlc_player_aout_SetVolume(_p_player, volume);
}

- (void)incrementVolume
{
    vlc_player_aout_SetVolume(_p_player, _volume + 0.05);
}

- (void)decrementVolume
{
    vlc_player_aout_SetVolume(_p_player, _volume - 0.05);
}

- (void)muteChanged:(BOOL)mute
{
    _mute = mute;
    [_defaultNotificationCenter postNotificationName:VLCPlayerMuteChanged
                                              object:self];
}

- (void)setMute:(BOOL)mute
{
    vlc_player_aout_Mute(_p_player, mute);
}

- (void)toggleMute
{
    vlc_player_aout_Mute(_p_player, !_mute);
}

- (audio_output_t *)mainAudioOutput
{
    return vlc_player_aout_Hold(_p_player);
}

@end

@implementation VLCInputStats

@end
