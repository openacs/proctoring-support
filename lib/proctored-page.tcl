ad_include_contract {
    Embed proctoring support in a page.

    This template creates and empty page embedding specified URL in an
    iframe surrounded by proctoring support.

    This kind of proctoring will take snapshots from camera and
    desktop at random intervals and upload them to specified URL.

    @param exam_id Id of the exam. This can be e.g. the item_id of the
           exam object.
    @param exam_url URL of the actual exam, which will be included in
           an iframe.
    @param min_ms_interval miniumum time to the next snapshot in
           missliseconds
    @param max_ms_interval maximum time to the next snapshot in
           milliseconds.
    @param audio_p decides if we record audio. Every time some input
           longer than min_audio_duration is detected from the
           microphone, a recording will be started and terminated at
           the next silence, or once it reaches max_audio_duration
    @param check_active_p detects if proctoring is not active anymore
                          for this object and exit the proctored
                          session. "active", is implemented by
                          checking that the upload backed does not
                          return something differ ent from the "OK"
                          response. Using provided upload backend,
                          this will be checked by querying proctoring
                          object metadata stored in this package's
                          datamodel.
    @param min_audio_duration minimum audio duration to start
           recording in seconds
    @param max_audio_duration max audio duration in seconds. Once
           reached, recording will stop and resume at the next
           detected audio segment.
    @param preview_p if specified, a preview of recorded inputs will
                     be displayed to users during proctored session
    @param proctoring_p Do the actual proctoring. Can be disabled to
                        display just the examination statement
    @param camera_p proctor the camera. If false, camera will not be
                   recorded.
    @param desktop_p proctor the desktop screen. If false, desktop
                   screen will not be recorded.
    @param examination_statement_p Display the examination statement
    @param examination_statement_url URL we are calling in order to
           store acceptance of the examination statement. It will
           receive 'object_id' as query parameter.
    @param upload_p decides if we want to skip the actual upload of
           proctored files, useful to implement e.g. test pages or
           when proctoring should only be used as a deterrent.
    @param upload_url URL for the backend receiving and storing the
           collected snapshots. It will receive 'name' (device name,
           either camera or desktop), item_id (exam_id), the file and
           the check_active_p flag. Current default URL is that which
           becomes available by default once proctoring-support
           package is mounted and will store the pictures in the
           /proctoring folder under acs_root_dir.
    @param msg an array that can be used to customize UI labels with
           fields: 'missing_stream' (message to display in case
           proctoring fails due to a missing stream), 'accept' (label
           for the accept button), 'exam_mode' (examination statement
           for the exam, to be displayed as literal),
           'proctoring_accept' (disclaimer informing users that
           proctoring will happen), 'proctoring_banner' (message in
           the red proctoring banner). Any of those fields can be
           omitted and will default to message keys in this package.
} {
    object_url:localurl
    object_id:naturalnum,notnull
    {min_ms_interval:naturalnum 1000}
    {max_ms_interval:naturalnum 60000}
    {audio_p:boolean true}
    {min_audio_duration:naturalnum 2}
    {max_audio_duration:naturalnum 60}
    {preview_p:boolean false}
    {proctoring_p:boolean true}
    {camera_p:boolean true}
    {desktop_p:boolean true}
    {check_active_p:boolean true}
    {examination_statement_p:boolean true}
    {examination_statement_url:localurl "/proctoring/examination-statement-accept"}
    {upload_p:boolean true}
    {upload_url:localurl "/proctoring/upload"}
    msg:array,optional
}

::proctoring::seb::require_valid_access \
    -object_id $object_id

set system_name [ad_system_name]

set default_msg(missing_stream) [_ proctoring-support.missing_stream_message]
set default_msg(proctoring_accept) [_ proctoring-support.accept_message]
set default_msg(exam_mode) [_ proctoring-support.Exam_mode_message]
set default_msg(proctoring_banner) [_ proctoring-support.banner_message]
set default_msg(black_picture_camera) [_ proctoring-support.you_are_producing_black_pictures_from_camera]
set default_msg(black_picture_desktop) [_ proctoring-support.you_are_producing_black_pictures_from_desktop]
set default_msg(request_failed) [_ proctoring-support.request_failed]
set default_msg(request_timeout) [_ proctoring-support.request_timeout]
set default_msg(audio_grabbing_not_supported) [_ proctoring-support.audio_grabbing_not_supported]
set default_msg(camera_grabbing_not_supported) [_ proctoring-support.camera_grabbing_not_supported]
set default_msg(desktop_grabbing_not_supported) [_ proctoring-support.desktop_grabbing_not_supported]
set default_msg(your_microphone_is_muted) [_ proctoring-support.your_microphone_is_muted]
set default_msg(microphone_too_low) [_ proctoring-support.microphone_volume_is_too_low]
set default_msg(camera_permission_denied) [_ proctoring-support.camera_permission_denied]
set default_msg(microphone_permission_denied) [_ proctoring-support.microphone_permission_denied]
set default_msg(desktop_permission_denied) [_ proctoring-support.desktop_permission_denied]
set default_msg(microphone_not_found) [_ proctoring-support.microphone_not_found]
set default_msg(microphone_not_readable) [_ proctoring-support.microphone_not_readable]
set default_msg(camera_not_found) [_ proctoring-support.camera_not_found]
set default_msg(camera_not_readable) [_ proctoring-support.camera_not_readable]
set default_msg(wrong_display_surface_selected) [_ proctoring-support.wrong_display_surface_selected]
set default_msg(display_surface_not_supported) [_ proctoring-support.display_surface_not_supported]
set default_msg(mobile_devices_not_supported) [_ proctoring-support.mobile_devices_are_unsupported]

foreach {key value} [array get default_msg] {
    if {![info exists msg($key)]} {
        set msg($key) $value
    }
}

set mobile_p [ad_conn mobile_p]
set check_active_p [expr {$check_active_p ? true : false}]
set preview_p [expr {$preview_p ? true : false}]
set proctoring_p [expr {$proctoring_p &&
                        ($camera_p || $audio_p || $desktop_p) ? true : false}]
set upload_p [expr {$upload_p ? true : false}]
set audio_p [expr {$audio_p ? true : false}]
set camera_p [expr {$camera_p ? true : false}]
set desktop_p [expr {$desktop_p ? true : false}]

#ns_log notice "PROCTORED PAGE sees desktop_p $desktop_p, camera_p $camera_p, examination_statement_p $examination_statement_p preview_p $preview_p"

#
# Local variables:
#    mode: tcl
#    tcl-indent-level: 4
#    indent-tabs-mode: nil
# End:
