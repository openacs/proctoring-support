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
        ::proctoring::seb::valid_hash_p
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
                seb_p
                seb_file
                seb_keys
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

            aa_log "Storing SEB configuration"
            set key a3e85dcad0cd6a6e2f55e77399e4c9caf47807d760402d6b740017a9f0b2a197
            set hash 6f3edc0ef5a56879eba206a7debb3fb0585ebb1f2423ebc10a1afce991edfbcd
            set url https://learn-a.wu.ac.at:8081/dotlrn/classes/tlf/testkurs.17s/
            set wfd [ad_opentmpfile conf_file]
            puts $wfd abcd
            close $wfd
            set conf_file_hash [ns_md file $conf_file]

            ::proctoring::configure \
                -object_id $object_id \
                -seb_p true \
                -seb_keys $key
            set conf [::proctoring::get_configuration -object_id $object_id]
            aa_equals "Conf file is empty" [dict get $conf seb_file] ""
            aa_equals "Key has been stored" [dict get $conf seb_keys] $key

            set keys [list $key ${key}-2 ${key}-3]
            ::proctoring::configure \
                -object_id $object_id \
                -seb_p true \
                -seb_keys $keys
            set conf [::proctoring::get_configuration -object_id $object_id]
            aa_equals "Same number of keys are stored" [llength $keys] [llength [dict get $conf seb_keys]]
            aa_equals "Exactly the same keys are stored" [lsort $keys] [lsort [dict get $conf seb_keys]]

            ::proctoring::configure \
                -object_id $object_id \
                -seb_keys ${key}abcd
            set conf [::proctoring::get_configuration -object_id $object_id]
            aa_equals "Seb confs are deleted when the seb_p flag is false" \
                "" [dict get $conf seb_keys]

            ::proctoring::configure \
                -object_id $object_id \
                -seb_p true \
                -seb_keys $key \
                -seb_file $conf_file

            set conf [::proctoring::get_configuration -object_id $object_id]
            aa_equals "Conf file was stored correctly" \
                [ns_md file [dict get $conf seb_file]] $conf_file_hash
            aa_equals "Key was stored correctly" \
                [dict get $conf seb_keys] $key

            aa_true "Data has been stored correctly and the hash can be computed as expected" \
                [::proctoring::seb::valid_hash_p \
                     -key [lindex [dict get $conf seb_keys] 0] \
                     -hash $hash \
                     -url $url]
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
        set wfd [ad_opentmpfile file1]
        puts $wfd abcd
        close $wfd

        set user2 2
        set object2 2
        set wfd [ad_opentmpfile file2]
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

aa_register_case \
    -cats {api smoke} \
    -procs {
        ::proctoring::artifact::store
        ::proctoring::artifact::delete
    } \
    proctoring_artifact_store {
        Test ::proctoring::artifact::store
    } {
        set wfd [ad_opentmpfile file *.test]
        puts $wfd 1234
        close $wfd

        for {set i 2} {$i <= 4} {incr i} {
            set file${i} [ad_tmpnam].test
            file copy $file [set file${i}]
        }

        # A new test user is at the same time a safe user and a safe
        # object to test on.
        set user_info [::acs::test::user::create]
        set user_id [dict get $user_info user_id]
        set object_id $user_id

        set another_user_id [::xo::dc get_value get_user_id {
            select min(user_id) from users
        }]

        set name test
        set type code
        set timestamp [clock scan "2016-09-07" -format %Y-%m-%d]

        aa_section "Test full cleanup"
        ::proctoring::artifact::store \
            -object_id $object_id \
            -user_id $user_id \
            -timestamp $timestamp \
            -name $name \
            -type $type \
            -file $file3
        ::proctoring::artifact::store \
            -object_id $object_id \
            -user_id $another_user_id \
            -timestamp $timestamp \
            -name $name \
            -type $type \
            -file $file4
        ::proctoring::artifact::delete \
            -object_id $object_id
        aa_false "No artifacts for object '$object_id'" [::xo::dc 0or1row check {
            select 1 from proctoring_object_artifacts
            where object_id = :object_id
            fetch first 1 rows only
        }]

        aa_section "Storing an artifact correctly"
        set artifact [::proctoring::artifact::store \
                          -object_id $object_id \
                          -user_id $user_id \
                          -timestamp $timestamp \
                          -name $name \
                          -type $type \
                          -file $file]

        set artifact_id [dict get $artifact artifact_id]
        set file [dict get $artifact file]
        aa_true "Artifact '$artifact_id' on file '$file' was created" [::xo::dc 0or1row check {
            select 1 from proctoring_object_artifacts
            where artifact_id = :artifact_id
              and file = :file
              and name = :name
              and type = :type
              and timestamp = to_timestamp(:timestamp)
              and user_id = :user_id
              and object_id = :object_id
        }]
        aa_true "File exists" [file exists $file]
        aa_equals "File has the original extension" .test [file extension $file]

        aa_section "Storing another artifact for a different user"
        set artifact2 [::proctoring::artifact::store \
                           -object_id $object_id \
                           -user_id $another_user_id \
                           -timestamp $timestamp \
                           -name $name \
                           -type $type \
                           -file $file2]
        aa_true "Entry for '$another_user_id' was created" [::xo::dc 0or1row check {
            select 1 from proctoring_object_artifacts
            where object_id = :object_id
              and user_id = :another_user_id
            fetch first 1 rows only
        }]

        aa_section "Cleanup"
        ::proctoring::artifact::delete \
            -object_id $object_id \
            -user_id $user_id
        aa_false "No entry for '$user_id' anymore" [::xo::dc 0or1row check {
            select 1 from proctoring_object_artifacts
            where object_id = :object_id
              and user_id = :user_id
            fetch first 1 rows only
        }]
        aa_false "File '$file' was removed" [file exists $file]
        aa_true "Still entry for '$another_user_id'" [::xo::dc 0or1row check {
            select 1 from proctoring_object_artifacts
            where object_id = :object_id
              and user_id = :another_user_id
            fetch first 1 rows only
        }]
        aa_true "Still file for '$another_user_id'" [file exists [dict get $artifact2 file]]
        ::proctoring::artifact::delete \
            -object_id $object_id \
            -user_id $another_user_id
        aa_false "Also artifacts for '$another_user_id' deleted." [::xo::dc 0or1row check {
            select 1 from proctoring_object_artifacts
            where object_id = :object_id
            fetch first 1 rows only
        }]
        aa_false "File also delete for '$another_user_id'" [file exists [dict get $artifact2 file]]

        aa_section "Try to store for an invalid object"
        set broken_object_id [::xo::dc get_value get_broken_object_id {
            select min(object_id) - 1 from acs_objects
        }]
        aa_true "Saving for an invalid object fails" [catch {
            ::proctoring::artifact::store \
                -object_id $broken_object_id \
                -user_id $user_id \
                -timestamp $timestamp \
                -name $name \
                -type $type \
                -file $file
        }]
        aa_false "No row can be found for broken object '$broken_object_id'" [::xo::dc 0or1row check {
            select 1 from proctoring_object_artifacts
            where object_id = :broken_object_id
            fetch first 1 rows only
        }]

        aa_section "Try to store for an invalid user"
        set broken_user_id [::xo::dc get_value get_broken_user_id {
            select min(user_id) - 1 from users
        }]
        aa_true "Saving for an invalid user fails" [catch {
            ::proctoring::artifact::store \
                -object_id $object_id \
                -user_id $broken_user_id \
                -timestamp $timestamp \
                -name $name \
                -type $type \
                -file $file
        }]
        aa_false "No row can be found for broken user '$broken_user_id'" [::xo::dc 0or1row check {
            select 1 from proctoring_object_artifacts
            where user_id = :broken_user_id
            fetch first 1 rows only
        }]

        aa_section "Try to store a non-existing file"
        set broken_file [ad_tmpnam]
        aa_true "Saving a non-existing file fails" [catch {
            ::proctoring::artifact::store \
                -object_id $object_id \
                -user_id $user_id \
                -timestamp $timestamp \
                -name $name \
                -type $type \
                -file $broken_file
        }]
        aa_false "No row can be found for non-existing file '$broken_file'" [::xo::dc 0or1row check {
            select 1 from proctoring_object_artifacts
            where file = :broken_file
              and object_id = :object_id
              and user_id = :user_id
            fetch first 1 rows only
        }]
    }

aa_register_case \
    -cats {api smoke} \
    -urls {
        upload
    } \
    -procs {
        ::proctoring::artifact::store
    } \
    proctoring_upload_test {
        Test that the actual upload works as expected
    } {
        try {
            set package_url [lindex [::site_node::get_package_url -package_key proctoring-support] 0]

            set user_info [acs::test::user::create]
            set d [::acs::test::login $user_info]
            dict set session cookies [dict get $d session cookies]
            dict set session login via_login

            set login [dict get $session login]

            set headers [ns_set create headers]
            if {[dict exists $session cookies]} {
                ns_set put $headers Cookie [dict get $session cookies]
            }

            set user_id [dict get $user_info user_id]
            set object_id $user_id

            set type image
            set name camera
            set file [acs_root_dir]/packages/proctoring-support/tcl/test/data/test.png

            set url [acs::test::url]${package_url}upload

            aa_section "Upload enforcing active proctoring conf"

            set r [util::http::post \
                       -url $url \
                       -headers $headers \
                       -files [list [list fieldname file file $file]] \
                       -formvars [export_vars {type name object_id}]]

            aa_equals "Request returns 200" [dict get $r status] 200
            aa_equals "Proctoring is not configured for '$object_id', so requests returns 'OFF'" \
                [dict get $r page] OFF

            aa_false "File was not stored" [::xo::dc 0or1row artifact_exists {
                select 1 from dual where exists
                (select 1 from proctoring_object_artifacts
                 where object_id = :object_id
                 and user_id = :user_id)
            }]

            aa_section "Upload NOT enforcing active proctoring conf"
            set r [util::http::post \
                       -url $url \
                       -headers $headers \
                       -files [list [list fieldname file file $file]] \
                       -formvars [export_vars {type name object_id {check_active_p false}}]]

            aa_equals "Request returns 200" [dict get $r status] 200
            aa_equals "Requests returns 'OK'" \
                [dict get $r page] OK

            aa_true "File was stored" [::xo::dc 0or1row artifact_exists {
                select 1 from dual where exists
                (select 1 from proctoring_object_artifacts
                 where object_id = :object_id
                 and user_id = :user_id)
            }]
        } finally {
            # Cleanup
            if {[info exists user_id]} {
                proctoring::artifact::delete -object_id $user_id
                acs_user::delete -user_id $user_id -permanent
            }
        }
    }

# Local variables:
#    mode: tcl
#    tcl-indent-level: 4
#    indent-tabs-mode: nil
# End:
