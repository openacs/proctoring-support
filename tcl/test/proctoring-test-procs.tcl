ad_library {
    Test proctoring api
}

aa_register_case \
    -cats {api smoke} \
    -procs {
        ::proctoring::folder
        ::proctoring::delete
    } \
    proctoring_folder_test {
        Test ::proctoring::folder
    } {
        # Make sure we never conflict with "real" object folders
        set min_object_id [db_string get_object_id {
            select min(object_id) - 100 from acs_objects
        }]

        set object_dirs [list]
        set paths [list]

        aa_section "Creating and deleting proctoring folders"
        for {set object_id $min_object_id} {$object_id < $min_object_id + 5} {incr object_id} {
            for {set user_id 0} {$user_id < 5} {incr user_id} {
                # Here we require the proctoring folder and make sure it exists
                set path [::proctoring::folder -object_id $object_id -user_id $user_id]
                aa_true "'$path' is a directory" [file isdirectory $path]
                aa_log "Deleting '$path'"
                # Here we delete it just for the user
                ::proctoring::delete -object_id $object_id -user_id $user_id
                aa_false "'$path' does not exist anymore" [file isdirectory $path]
                lappend paths $path
            }
            set path [file dirname $path]
            # Here we make sure that even when the user folders are
            # deleted, the object folder remains
            aa_true "'$path' still exists" [file isdirectory $path]
            aa_log "Deleting '$path'"
            # Here we delete the object folder as well and make sure
            # it does not exist anymore
            ::proctoring::delete -object_id $object_id
            aa_false "'$path' does not exist anymore" [file isdirectory $path]
        }

        aa_true "Unique paths were generated" {[llength [lsort -unique $paths]] == 25}
    }

aa_register_case \
    -cats {api smoke} \
    -procs {
        ::proctoring::configure
        ::proctoring::get_configuration
        ::proctoring::active_p
    } \
    proctoring_conf_test {
        Test proctoring configuration api
    } {
        aa_run_with_teardown -rollback -test_code {
            set object_id [::xo::dc get_value get_object {
                select object_id from acs_objects o
                where not exists (select 1 from proctoring_objects
                                  where object_id = o.object_id)
                fetch first 1 rows only
            }]

            aa_false "Proctoring on $object_id is not active" [::proctoring::active_p -object_id $object_id]

            set conf [::proctoring::get_configuration -object_id $object_id]
            foreach field {
                enabled_p
                start_date
                end_date
                start_time
                end_time
                preview_p
                audio_p
                camera_p
                desktop_p
                proctoring_p
                examination_statement_p
            } {
                aa_true "Field $field exists in dict" [dict exists $conf $field]
            }

            aa_log "Enable proctoring"
            ::proctoring::configure -object_id $object_id -enabled_p true
            set conf [::proctoring::get_configuration -object_id $object_id]
            aa_true "Conf was stored" [dict get $conf enabled_p]
            aa_true "Proctoring on $object_id is active" [::proctoring::active_p -object_id $object_id]

            set yesterday [clock format [clock scan "-1 day"] -format %Y-%m-%d]
            set today [clock format [clock seconds] -format %Y-%m-%d]
            set this_hour [clock format [clock seconds] -format %H:00:00]
            set next_hour [clock format [clock scan "1 hour"] -format %H:00:00]
            set past_hour [clock format [clock scan "-1 hour"] -format %H:00:00]

            aa_log "Enable proctoring up to yesterday"
            ::proctoring::configure -object_id $object_id -end_date $yesterday
            set conf [::proctoring::get_configuration -object_id $object_id]
            aa_true "Conf was stored" {[dict get $conf end_date] eq $yesterday}
            aa_false "Proctoring on $object_id is not active" [::proctoring::active_p -object_id $object_id]

            aa_log "Enable proctoring from yesterday"
            ::proctoring::configure -object_id $object_id -start_date $yesterday -end_date ""
            set conf [::proctoring::get_configuration -object_id $object_id]
            aa_true "Conf was stored" {[dict get $conf start_date] eq $yesterday && [dict get $conf end_date] eq ""}
            aa_true "Proctoring on $object_id is active" [::proctoring::active_p -object_id $object_id]

            aa_log "Enable proctoring from yesterday up to one hour ago"
            ::proctoring::configure -object_id $object_id -end_time $past_hour
            set conf [::proctoring::get_configuration -object_id $object_id]
            aa_true "Conf was stored" {[dict get $conf end_time] eq $past_hour}
            aa_false "Proctoring on $object_id is not active" [::proctoring::active_p -object_id $object_id]

            aa_log "Enable proctoring every day, one hour from now"
            ::proctoring::configure -object_id $object_id -start_date "" -end_date "" -start_time $next_hour
            set conf [::proctoring::get_configuration -object_id $object_id]
            aa_true "Conf was stored" {
                [dict get $conf start_date] eq "" &&
                [dict get $conf end_date] eq "" &&
                [dict get $conf start_time] eq $next_hour
            }
            aa_false "Proctoring on $object_id is not active" [::proctoring::active_p -object_id $object_id]

            aa_log "Enable proctoring every day, from this hour to one hour from now"
            ::proctoring::configure -object_id $object_id -start_time $this_hour -end_time $next_hour
            set conf [::proctoring::get_configuration -object_id $object_id]
            aa_true "Conf was stored" {
                [dict get $conf start_time] eq $this_hour &&
                [dict get $conf end_time] eq $next_hour
            }
            aa_true "Proctoring on $object_id is active" [::proctoring::active_p -object_id $object_id]

            aa_log "Disable camera and desktop"
            ::proctoring::configure -object_id $object_id \
                -proctoring_p true -camera_p false -desktop_p false -audio_p false
            set conf [::proctoring::get_configuration -object_id $object_id]
            aa_false "No camera and no desktop means no proctoring" [dict get $conf proctoring_p]

            aa_log "Enable camera"
            ::proctoring::configure -object_id $object_id -camera_p true
            set conf [::proctoring::get_configuration -object_id $object_id]
            aa_true "Now proctoring appears to be on" [dict get $conf proctoring_p]
        }
    }

aa_register_case \
    -cats {api smoke} \
    -procs {
        ::proctoring::file_already_received_p
    } \
    proctoring_file_already_received_test {
        Test that the server side check for duplicated uploads works
        as expected.
    } {
        set user1 1
        set object1 1
        set file1 [ad_tmpnam]
        set wfd [open $file1 w]
        puts $wfd abcd
        close $wfd

        set user2 2
        set object2 2
        set file2 [ad_tmpnam]
        set wfd [open $file2 w]
        puts $wfd efgh
        close $wfd

        try {
            for {set o 1} {$o <= 2} {incr o} {
                for {set u 1} {$u <= 2} {incr u} {
                    set user [set user${u}]
                    set object [set object${o}]
                    aa_false "'$file1' for user '$user' and object '$object' IS NOT duplicated" \
                        [::proctoring::file_already_received_p \
                             -object_id $object \
                             -user_id $user \
                             -file $file1]

                    aa_true "'$file1' for user '$user' and object '$object' IS duplicated" \
                        [::proctoring::file_already_received_p \
                             -object_id $object \
                             -user_id $user \
                             -file $file1]

                    aa_false "'$file2' for user '$user' and object '$object' IS NOT duplicated" \
                        [::proctoring::file_already_received_p \
                             -object_id $object \
                             -user_id $user \
                             -file $file2]

                    aa_false "'$file1' for user '$user' and object '$object' IS AGAIN NOT duplicated" \
                        [::proctoring::file_already_received_p \
                             -object_id $object \
                             -user_id $user \
                             -file $file1]

                    # Trick to forget about file1 when re-running the test
                    ::proctoring::file_already_received_p \
                        -object_id $object \
                        -user_id $user \
                        -file $file2
                }
            }
        } finally {
            file delete -- $file1 $file2
        }
    }
# Local variables:
#    mode: tcl
#    tcl-indent-level: 4
#    indent-tabs-mode: nil
# End:
