ad_include_contract {

    User Interface to display and manage proctoring data from users.

    This include lists the proctored users for a particular object and
    the files collected for each one of them, either audio or
    pictures. The UI can update automatically when new pictures are
    available if websockets have been enabled for uploads.

    Site wide admins can also delete the pictures collected for the
    whole object or for the single users.

    @param object_id the proctored object id.
    @param user_id the user to be displayed. If the page has been
                   called with the 'delete' query paramet er, this can
                   be a list of users, for which we want proctoring
                   files to be deleted.
    @param file when specified, the page will return the file as a
                response (e.g. a proctored picture).  Must be a valid
                filename belonging to the correct proctored and user
                folder.
    @param delete decides if this is a delete operation. If users are
                  specified, only files for those users will be
                  deleted, otherwise all the files for this proctored
                  object will be. Only SWAs can delete files.
} {
    object_id:naturalnum,notnull
    {user_id "[ns_querygetall user_id]"}
    file:optional
    {delete:boolean "[ns_queryget delete false]"}
} -validate {
    object_folder_exists -requires {object_id:naturalnum} {
        # in order to access the contents of the proctoring folder:
        # a) the user should have admin permissions for this object and
        permission::require_permission -object_id $object_id -privilege "admin"
    }
    user_id_valid -requires {user_id} {
        foreach id $user_id {
            if {![string is integer -strict $id]} {
                ad_complain [_ acs-tcl.lt_name_is_not_an_intege [list name $id]]
                ad_script_abort
            }
        }
    }
}

set swa_p [acs_user::site_wide_admin_p]

if {$swa_p} {
    set delete_p $delete
} else {
    set delete_p false
}

set this_url [export_vars -base [ad_conn url] -entire_form -no_empty]
set folder_exists_p [file isdirectory [::proctoring::folder -object_id $object_id]]
set delete_url [export_vars -base [ad_conn url] -entire_form -no_empty {{delete true}}]

set host [util_current_location]
set parsed_host [ns_parseurl $host]
set only_host [dict get $parsed_host host]
set port      [expr {[dict exists $parsed_host port] ? [dict get $parsed_host port] : ""}]
set host ${only_host}[expr {$port ni {"" 80} ? ":$port" : ""}]
set proto     [dict get $parsed_host proto]
set ws_proto  [expr {$proto eq "https" ? "wss" : "ws"}]
set ws_url $ws_proto://${host}/[export_vars -base proctoring-websocket -no_empty {user_id object_id}]

if {$delete_p && [llength $user_id] >= 1} {
    foreach u $user_id {
        set folder [::proctoring::folder \
                        -object_id $object_id -user_id $u]
        file delete -force -- $folder
    }
    set return_url [export_vars -base [ad_conn url] -entire_form -no_empty -exclude {delete user_id}]
    ad_returnredirect $return_url
    ad_script_abort
} elseif {[llength $user_id] == 1} {
    set folder [::proctoring::folder \
                    -object_id $object_id -user_id $user_id]

    set delete_label [_ xowiki.delete]
    set delete_confirm [_ xowiki.delete_confirm]

    if {[info exists file]} {
        # Returning the picture
        if {[file exists ${folder}/[ad_sanitize_filename ${file}]]} {
            ns_setexpires 864000 ;# 10 days
            ns_writer submitfile -headers ${folder}/[ad_sanitize_filename ${file}]
        } else {
            ns_returnnotfound
        }
        ad_script_abort
    } else {
        # List of pictures for a particular user

        set user_name [person::name -person_id $user_id]
        set first_names [::person::get -person_id $user_id -element first_names]
        set last_name [::person::get -person_id $user_id -element last_name]
        set portrait_url [export_vars -base "/shared/portrait-bits.tcl" {user_id {size x200}}]

        set back_url [export_vars -base [ad_conn url] -entire_form -no_empty -exclude {user_id}]
        set camera_pics [lsort -increasing -dictionary \
                             [glob -nocomplain -directory $folder camera-image-*.*]]
        set desktop_pics [lsort -increasing -dictionary \
                              [glob -nocomplain -directory $folder desktop-image-*.*]]
        set rows [list]
        foreach camera_pic $camera_pics desktop_pic $desktop_pics {
            set row [dict create \
                        audio_url ""]

            if {$camera_pic ne ""} {
                set camera_pic [file tail $camera_pic]
                regexp {^camera-image-(\d+)\.\w+$} $camera_pic m camera_timestamp
                dict set row camera_url [export_vars -base $this_url {{file $camera_pic}}]
            } else {
                dict set row camera_url ""
            }

            if {$desktop_pic ne ""} {
                set desktop_pic [file tail $desktop_pic]
                regexp {^desktop-image-(\d+)\.\w+$} $desktop_pic m desktop_timestamp
                dict set row desktop_url [export_vars -base $this_url {{file $desktop_pic}}]
            } else {
                dict set row desktop_url ""
            }

            if {[info exists camera_timestamp]} {
                set timestamp $camera_timestamp
            } else {
                set timestamp $desktop_timestamp
            }
            dict set row timestamp $timestamp
            dict set row timestamp_pretty [clock format $timestamp -format "%y-%m-%d %H:%M:%S"]

            lappend rows $row
        }

        set audios [glob -nocomplain -directory $folder *-audio-*.*]
        foreach audio $audios {
            set row [dict create]
            set audio [file tail $audio]
            regexp {^\w+-audio-(\d+)\.\w+$} $audio m timestamp
            dict set row audio_url [export_vars -base $this_url {{file $audio}}]
            dict set row camera_url ""
            dict set row desktop_url ""
            dict set row timestamp $timestamp
            dict set row timestamp_pretty [clock format $timestamp -format "%y-%m-%d %H:%M:%S"]

            lappend rows $row
        }

        template::util::list_to_multirow events $rows
        template::multirow sort events timestamp
    }
} else {
    # List of proctored users

    set folder [::proctoring::folder \
                    -object_id $object_id]

    set delete_label [_ xowiki.delete_all]
    set delete_confirm [_ xowiki.delete_all_confirm]

    if {$delete_p} {
        file delete -force -- $folder
        ad_returnredirect [export_vars -base [ad_conn url] -entire_form -no_empty -exclude {delete}]
        ad_script_abort
    }

    set rows [list]
    foreach user_folder [glob -type d -nocomplain -directory $folder *] {
        set row [dict create]
        set proctored_user_id [file tail $user_folder]
        dict set row user_id $proctored_user_id

        set user [acs_user::get -user_id $proctored_user_id]
        if {$user eq ""} {continue}

        set first_names [dict get $user first_names]
        set last_name [dict get $user last_name]

        dict set row user_id $proctored_user_id
        dict set row first_names $first_names
        dict set row last_name $last_name
        dict set row proctoring_url [export_vars -base [ad_conn url] {{user_id $proctored_user_id} {object_id $object_id}}]
        dict set row portrait_url /shared/portrait-bits.tcl?user_id=$proctored_user_id
        dict set row filter [string tolower "$last_name $first_names"]
        lappend rows $row
    }
    template::util::list_to_multirow users $rows
    template::multirow sort users first_names
    template::multirow sort users last_name
}
