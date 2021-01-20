ad_library {
    Test proctoring api
}

aa_register_case \
    -cats {api smoke} \
    -procs {::proctoring::folder} \
    proctoring_folder_test {
        Test ::proctoring::folder
    } {
        # Make sure we never conflict with "real" object folders
        set object_id [db_string get_object_id {
            select min(object_id) - 100 from acs_objects
        }]
        set max_object_id [expr {$object_id + 5}]

        set object_dirs [list]
        set paths [list]

        while {$object_id < $max_object_id} {
            for {set user_id 0} {$user_id < 5} {incr user_id} {
                set path [::proctoring::folder -object_id $object_id -user_id $user_id]
                aa_log "Path is $path"
                lappend paths $path
                aa_log "...deleted."
                file delete -- $path
                lappend object_dirs [file dirname $path]
            }
            incr object_id
        }

        set object_dirs [lsort -unique $object_dirs]
        aa_log "Cleaning up $object_dirs"
        file delete -- {*}$object_dirs

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

# Local variables:
#    mode: tcl
#    tcl-indent-level: 4
#    indent-tabs-mode: nil
# End:
