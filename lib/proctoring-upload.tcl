ad_include_contract {

    Implements the upload backend for proctoring, which can be used as
    is or inside e.g. an object method.

} {
    name:oneof(camera|desktop),notnull
    type:oneof(image|audio),notnull
    object_id:naturalnum,notnull
    file
    file.tmpfile
    {notify_p:boolean false}
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
} elseif {![::proctoring::active_p -object_id $object_id]} {
    ns_return 200 text/plain "OFF"
    ad_script_abort
}

set timestamp [clock seconds]
set file_path $proctoring_dir/${name}-${type}-$timestamp.$extension
file mkdir -- $proctoring_dir
file rename -force -- ${file.tmpfile} $file_path

# TODO: downstream UI implements the receiving end of this
# websocket. We should port it.
# Notify a websocket about the upload so that e.g. a UI can be updated
# in real time.
if {$notfiy_p} {
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
