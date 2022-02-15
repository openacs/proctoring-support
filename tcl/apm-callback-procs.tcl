ad_library {

    APM callbacks for the proctoring-support package.

}

namespace eval proctoring {}
namespace eval proctoring::apm {}

ad_proc -private ::proctoring::apm::after_upgrade {
    {-from_version_name:required}
    {-to_version_name:required}
} {
    Upgrade logic
} {
    apm_upgrade_logic \
        -from_version_name $from_version_name \
        -to_version_name $to_version_name \
        -spec {
            3.0.0 3.1.0 {
                if {[namespace which ::xowf::atjob] ne ""} {
                    #
                    # We can use xowf atjobs: as this upgrade can
                    # potentially take a long time on busy systems, we
                    # schedule it to run at the next server restart by
                    # setting the atjob time in the past.
                    #
                    set cmd [list eval [list ::proctoring::apm::upgrade_to_3_1_0]]
                    set j [::xowf::atjob new \
                               -cmd $cmd \
                               -time [::xowf::atjob ansi_time 0]]
                    $j persist
                } else {
                    #
                    # No atjobs, the upgrade will run during the
                    # upgrade process.
                    #
                    ::proctoring::apm::upgrade_to_3_1_0 -apm
                }
            }
        }
}

ad_proc -private ::proctoring::apm::upgrade_to_3_1_0 {
    -apm:boolean
} {
    Version 3.1.0 introduced an actual table in the datamodel to store
    proctoring artifacts. Go into the proctoring folder and generate a
    database entry for each picture that respects the format used so
    far.
} {
    # Go in the proctoring folder...
    set object_folders [glob \
                            -nocomplain \
                            -directory [acs_root_dir]/proctoring/ \
                            -type d *]

    set msg "::proctoring::apm::upgrade_to_3_1_0 START\n"
    ns_log warning $msg
    if {$apm_p} {
        apm_ns_write_callback $msg<br>
    }

    set msg "Creating entries in the artifacts table. [llength $object_folders] to inspect..."
    ns_log warning $msg
    if {$apm_p} {
        apm_ns_write_callback $msg<br>
    }

    # ...for each object folder...
    foreach object_folder $object_folders {
        set object_id [file tail $object_folder]
        if {![string is integer -strict $object_id]} {
            continue
        }

        set user_folders [glob \
                              -nocomplain \
                              -directory $object_folder \
                              -type d *]

        set msg "...object '$object_id' has [llength $user_folders] user folders..."
        ns_log warning $msg
        if {$apm_p} {
            apm_ns_write_callback $msg<br>
        }

        # ...foreach user folder...
        foreach user_folder $user_folders {
            set user_id [file tail $user_folder]
            if {![string is integer -strict $user_id]} {
                continue
            }

            set files [glob \
                           -nocomplain \
                           -directory $user_folder \
                           -type f *]
            set msg "......for object '$object_id', user '$user_id' has [llength $files] files..."
            ns_log warning $msg
            if {$apm_p} {
                apm_ns_write_callback $msg<br>
            }

            # ...foreach file...
            foreach f $files {
                if {[regexp {^(\w+)-(\w+)-(\d+)\.\w+$} [file tail $f] m name type timestamp]} {
                    set msg ".........object '$object_id', user '$user_id' storing file '$f' in the artifacts table..."
                    # If the file respects the naming convention
                    # upheld so far, store the information in the
                    # database.
                    ::xo::dc dml -prepare integer,integer,integer,text,text,text,integer,integer init_artifact {
                        insert into proctoring_object_artifacts
                        (object_id, user_id, timestamp, name, type, file)
                        select :object_id, :user_id, to_timestamp(:timestamp), :name, :type, :f
                        from dual
                        where exists (select 1 from acs_objects where object_id = :object_id)
                          and exists (select 1 from users where user_id = :user_id)
                    }
                } else {
                    set msg ".........object '$object_id', user '$user_id' file '$f' does not respect the naming convention."
                }
                ns_log warning $msg
                if {$apm_p} {
                    apm_ns_write_callback $msg<br>
                }
            }
        }
    }

    set msg "::proctoring::apm::upgrade_to_3_1_0 FINISH\n"
    ns_log warning $msg
    if {$apm_p} {
        apm_ns_write_callback $msg<br>
    }
}
