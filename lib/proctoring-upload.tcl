ad_include_contract {

    Implements the upload backend for proctoring, which can be used as
    is or inside e.g. an object method.

    @param notify_p enable websocket notifications on two
                    subscriptions named proctoring-<object_id> and
                    proctoring-<object_id>-<user_id>, notifying about
                    uploads on the whole proctored object and on the
                    single user respectively.
    @param check_active_p when enabled, upload backend will use data
                          stored in the proctoring datamodel to check
                          if proctoring is still active on the
                          object. If it is not, the include will
                          return "OFF" as a res ponse, informing the
                          client side that proctoring can be
                          interrupted.

    @return 200/OK on success, 500/KO on failure, 200/OFF on a correct
            request when proctoring is not active anymore and the
            check_active_p flag is enabled.
} {
    name:oneof(camera|desktop),notnull
    type:oneof(image|audio),notnull
    object_id:naturalnum,notnull
    file
    file.tmpfile
    {notify_p:boolean false}
    {check_active_p:boolean true}
    {record_p:boolean true}
}

#ns_log notice "LIB PROCTORING_UPLOAD called with record_p $record_p, notify_p $notify_p"

if {!$record_p} {
    ad_file delete ${file.tmpfile}
    ns_log notice "proctoring-support: do not save uploaded content"

} else {
    set user_id [auth::require_login]

    set proctoring_dir [::proctoring::folder \
                            -object_id $object_id -user_id $user_id]

    if {$type eq "audio"} {
        #
        # Audios are assumed to be webm files. One could do better and
        # peek into the file like we do in the commented line,
        # however, this would not scale. Exec-free solutions are
        # welcome!
        #
        # set mime_type [exec [util::which file] --mime-type -b ${file.tmpfile}]
        set mime_type video/webm
    } else {
        set mime_type [ns_imgmime ${file.tmpfile}]
    }
    if {($type eq "image" && ![regexp {^image/(.*)$} $mime_type m extension]) ||
        ($type eq "audio" && ![regexp {^video/(.*)$} $mime_type m extension])
    } {
        ns_log warning "Proctoring: user $user_id uploaded a non-$type ($mime_type) file for object $object_id"
        ns_return 500 text/plain "KO"
        ad_script_abort
    } elseif {$check_active_p && ![::proctoring::active_p -object_id $object_id]} {
        ns_return 200 text/plain "OFF"
        ad_script_abort
    }

    # A client-side timeout might still end up being processed by the
    # server. Here we make sure we do not process files twice for a
    # specific user.
    if {[::proctoring::file_already_received_p \
             -object_id $object_id \
             -user_id $user_id \
             -file ${file.tmpfile}]} {
        # We do not tell anything to the client: for what they are
        # concerned, file has been received and they should go on with
        # their lives.
        ns_log warning "Proctoring: user $user_id tried to upload content twice, skipping silently..."
        ns_return 200 text/plain OK
        ad_script_abort
    }

    set file ${file.tmpfile}.${extension}
    file rename -- ${file.tmpfile} $file
    set artifact [::proctoring::artifact::store \
                      -object_id $object_id \
                      -user_id $user_id \
                      -name $name \
                      -type $type \
                      -file $file]

    # Notify a websocket about the upload so that e.g. a UI can be updated
    # in real time.
    if {$notify_p} {
        if {[namespace which ::ws::multicast] eq ""} {
            ns_log warning "proctoring-upload: notify was requested, but websockets are NOT configured"
        } else {
            set message [subst {
                {
                    "user_id": "$user_id",
                    "name": "$name",
                    "type": "$type",
                    "timestamp": "[dict get $artifact timestamp]",
                    "file": "[dict get $artifact file]",
                    "id": "[dict get $artifact artifact_id]"
                }
            }]

            # Transitional code for NaviServer versions that do not
            # implement the wsencode subcommand. ::ws::build_msg would
            # return a warning on those versions, so we first try the
            # more modern idiom and fallback on the old api.
            try {
                set message [ns_connchan wsencode \
                                 -opcode text $message]
            } on error {errmsg} {
                set message [::ws::build_msg $message]
            }

            set chat proctoring-${object_id}
            #ns_log warning "Sending to chat $chat"
            ::ws::multicast $chat $message

            set chat proctoring-${object_id}-${user_id}
            #ns_log warning "Sending to chat $chat"
            ::ws::multicast $chat $message
        }
    }
}
ns_return 200 text/plain OK
