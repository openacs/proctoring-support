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
    @param master_p decides if the include should provide a master or
                    not. Choose false if you need to embed the UI
                    inside other pages or true if you want a
                    standalone page.
} {
    object_id:naturalnum,notnull
    {user_id "[ns_querygetall user_id]"}
    file:optional
    {delete:boolean "[ns_queryget delete false]"}
    {master_p:boolean true}
    {file "[ns_queryget file]"}
} -validate {
    object_folder_exists -requires {object_id:naturalnum} {
        # In order to access the contents of the proctoring folder,
        # the user should have admin permissions for this object.
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

set base_url [export_vars -base [ad_conn url] -entire_form -no_empty -exclude {delete file object_id user_id}]
set folder_exists_p [file isdirectory [::proctoring::folder -object_id $object_id]]
set delete_url [export_vars -base $base_url {{delete true} user_id}]

set host [util_current_location]
set parsed_host [ns_parseurl $host]
set only_host [dict get $parsed_host host]
set port      [expr {[dict exists $parsed_host port] ? [dict get $parsed_host port] : ""}]
set host ${only_host}[expr {$port ni {"" 80} ? ":$port" : ""}]
set proto     [dict get $parsed_host proto]
set ws_proto  [expr {$proto eq "https" ? "wss" : "ws"}]
set ws_url $ws_proto://${host}/[export_vars -base proctoring-websocket -no_empty {user_id object_id}]

if {$delete_p && [llength $user_id] >= 1} {
    #
    # Deletion of specific users via bulk-actions
    #
    foreach u $user_id {
        ::proctoring::artifact::delete \
            -object_id $object_id -user_id $u
    }
    ad_returnredirect $base_url
    ad_script_abort
} elseif {[llength $user_id] == 1} {
    set folder [::proctoring::folder \
                    -object_id $object_id -user_id $user_id]

    set delete_label [_ xowiki.delete]
    set delete_confirm [_ xowiki.delete_confirm]

    if {$file ne ""} {
        #
        # Display a specific artifact file
        #
        if {[file exists ${folder}/[ad_sanitize_filename ${file}]]} {
            ns_setexpires 864000 ;# 10 days
            ns_writer submitfile -headers ${folder}/[ad_sanitize_filename ${file}]
        } else {
            ns_returnnotfound
        }
        ad_script_abort
    } else {
        #
        # Display all of the artifacts for a specific user
        #
        set user_url [export_vars -base [ad_conn url] -entire_form -no_empty -exclude {delete file object_id}]

        set user_name [person::name -person_id $user_id]
        set first_names [::person::get -person_id $user_id -element first_names]
        set last_name [::person::get -person_id $user_id -element last_name]
        set portrait_url [export_vars -base "/shared/portrait-bits.tcl" {user_id {size x200}}]

        set back_url $base_url

        db_multirow events get_artifacts {
            select camera.file as camera_url,
                   desktop.file as desktop_url,
                   coalesce(camera.timestamp,
                            desktop.timestamp) as timestamp,
                   null as audio_url
              from (select timestamp,
                           file,
                           rank() over (
                                        partition by object_id, user_id
                                        order by timestamp asc
                                         ) as order
                      from proctoring_object_artifacts
                    where object_id = :object_id
                    and user_id = :user_id
                    and type = 'image'
                    and name = 'camera') camera
                   join
                   (select timestamp,
                           file,
                           rank() over (
                                        partition by object_id, user_id
                                        order by timestamp asc
                                         ) as order
                      from proctoring_object_artifacts
                    where object_id = :object_id
                    and user_id = :user_id
                    and type = 'image'
                    and name = 'desktop') desktop
                   on camera.order = desktop.order

            union

            select null as camera_url,
                   null as desktop_url,
                   timestamp,
                   file as audio_url
              from proctoring_object_artifacts
             where object_id = :object_id
               and user_id = :user_id
               and type = 'audio'

            order by timestamp asc
        } {
            if {$camera_url ne ""} {
                set camera_url [file tail $camera_url]
                set camera_url [export_vars -base $user_url {{file $camera_url}}]
            }
            if {$desktop_url ne ""} {
                set desktop_url [file tail $desktop_url]
                set desktop_url [export_vars -base $user_url {{file $desktop_url}}]
            }
            if {$audio_url ne ""} {
                set audio_url [file tail $audio_url]
                set audio_url [export_vars -base $user_url {{file $audio_url}}]
            }
        }
    }
} else {
    set folder [::proctoring::folder \
                    -object_id $object_id]

    set delete_label [_ xowiki.delete_all]
    set delete_confirm [_ xowiki.delete_all_confirm]

    if {$delete_p} {
        #
        # Delete all of the artifacts for this proctored object
        #
        ::proctoring::artifact::delete -object_id $object_id
        ad_returnredirect $base_url
        ad_script_abort
    }

    #
    # Display the list of proctored users for this object for whom
    # artifacts exist
    #
    db_multirow -extend {
        student_id
        proctoring_url
        portrait_url
        filter
    } -unclobber users get_users {
        select distinct a.user_id,
                        p.first_names,
                        p.last_name
        from proctoring_object_artifacts a,
             persons p
        where object_id = :object_id
          and a.user_id = p.person_id
        order by last_name asc, first_names asc
    } {
        set student_id [::party::email -party_id $user_id]

        set proctoring_url [export_vars -no_base_encode -base $base_url { user_id object_id }]
        set portrait_url /shared/portrait-bits.tcl?user_id=$user_id
        set filter [string tolower "$last_name $first_names $student_id"]
    }
}
