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
}

auth::require_login

set user_id [ad_conn user_id]

set proctoring_dir [::proctoring::folder \
                        -object_id $object_id -user_id $user_id]

if {$type eq "audio"} {
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

set timestamp [clock seconds]
set file_path $proctoring_dir/${name}-${type}-$timestamp.$extension

file mkdir -- $proctoring_dir
file rename -force -- ${file.tmpfile} $file_path

# Notify a websocket about the upload so that e.g. a UI can be updated
# in real time.
if {$notify_p} {
    set message [subst -nocommands {
        {
            "user_id": "$user_id",
            "name": "$name",
            "type": "$type",
            "timestamp": "$timestamp",
            "file": "$file_path"
        }
    }]

    set message [::ws::build_msg $message]

    set chat proctoring-${object_id}
    #ns_log warning "Sending to chat $chat"
    ::ws::multicast $chat $message

    set chat proctoring-${object_id}-${user_id}
    #ns_log warning "Sending to chat $chat"
    ::ws::multicast $chat $message
}

ns_return 200 text/plain OK
