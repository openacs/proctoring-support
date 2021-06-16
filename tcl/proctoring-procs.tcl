ad_library {
    Proctoring API
}

namespace eval ::proctoring {}

ad_proc ::proctoring::folder {
    -object_id:required
    {-user_id ""}
} {
    Returns the proctoring folder on the system
} {
    set folder [acs_root_dir]/proctoring/$object_id
    if {$user_id ne ""} {
        append folder /$user_id
    }
    file mkdir $folder
    return $folder
}

ad_proc ::proctoring::delete {
    -object_id:required
    {-user_id ""}
} {
    Deletes the proctoring folder. When no user is specified,
    proctoring files for the whole object will be deleted.

    @param user_id when specified, only folder for this user will be
                   deleted.
} {
    file delete -force -- [::proctoring::folder \
                               -object_id $object_id \
                               -user_id $user_id]
}

ad_proc ::proctoring::configure {
    -object_id:required
    {-enabled_p true}
    {-examination_statement_p true}
    {-proctoring_p true}
    {-audio_p true}
    {-camera_p true}
    {-desktop_p true}
    {-preview_p false}
    {-start_date ""}
    {-end_date ""}
    {-start_time ""}
    {-end_time ""}
    {-seb_p false}
    {-seb_keys ""}
    {-seb_file ""}
} {
    Configures proctoring for specified object.

    @param enabled_p enable proctoring.
    @param proctoring_p Do the actual proctoring. This allows one to have
                        only the examination statement, without
                        actually taking and uploading pixctures/sound.
    @param audio_p Record audio.
    @param camera_p Record the camera.
    @param desktop_p Record the desktop
    @param examination_statement_p Display the examination statement
    @param preview_p if specified, a preview of recorded inputs will
                     be displayed to users during proctored session
    @param start_date Date since which proctoring is enabled. No start
                      date check is performed when not specified and
                      proctoring will be enabled from today.
    @param end_date Date since which proctoring will not count as
                    enabled anymore. No end date check is performed
                    when not specified and proctoring will not expire.
    @param start_time Time of day since when proctoring is
                      executed. No time check when not specified.
    @param end_time Time of day since when proctoring is not
                    executed. No time check when not specified.
    @param seb_p Does this object enforce the use of the Safe Exam
                 Browser?
    @param seb_keys Keys we check against when enforcing the use of
                    the Safe Exam Browser, created via the Safe Exam
                    Browser configuration tool. These can be a
                    ConfigKeyHash, just validating the browser's
                    configuration or a RequestHash, also validating
                    the platform-specific version of SEB in use.
    @param seb_file .seb file that holds the valid configuration for
                    this exam. When provided, upon failing the check
                    the user will be sent the file so that they can
                    open it with the Safe Exam Browser and apply the
                    configuration to their session. In case this is
                    not provided, we are just going to reject clients
                    that fail the check.
} {
    ::xo::dc dml insert_proctoring {
        insert into proctoring_objects (
            object_id,
            enabled_p,
            start_date,
            end_date,
            start_time,
            end_time,
            preview_p,
            audio_p,
            camera_p,
            desktop_p,
            proctoring_p,
            examination_statement_p
          ) values (
            :object_id,
            :enabled_p,
            :start_date,
            :end_date,
            :start_time,
            :end_time,
            :preview_p,
            :audio_p,
            :camera_p,
            :desktop_p,
            ((:audio_p or :camera_p or :desktop_p) and :proctoring_p),
            :examination_statement_p
          ) on conflict(object_id) do update set
            enabled_p  = :enabled_p,
            start_date = :start_date,
            end_date   = :end_date,
            start_time = :start_time,
            end_time   = :end_time,
            preview_p  = :preview_p,
            audio_p    = :audio_p,
            camera_p   = :camera_p,
            desktop_p  = :desktop_p,
            proctoring_p = ((:audio_p or :camera_p or :desktop_p) and :proctoring_p),
            examination_statement_p = :examination_statement_p
    }

    if {$seb_p} {
        if {$seb_keys ne ""} {
            ::proctoring::seb::configure \
                -object_id $object_id \
                -allowed_keys $seb_keys \
                -seb_file $seb_file
        }
    } else {
        ::proctoring::seb::unconfigure \
            -object_id $object_id
    }
}

ad_proc ::proctoring::get_configuration {
    -object_id:required
} {
    Returns proctoring settings for specified object

    @return a dict with fields: enabled_p, start_date, end_date,
            start_time, end_time, preview_p, camera_p, desktop_p,
            proctoring_p, examination_statement_p, seb_p, seb_key,
            seb_file
} {
    set start_date ""
    set end_date ""
    set start_time ""
    set end_time ""
    set enabled_p false
    set preview_p true
    set audio_p false
    set camera_p false
    set desktop_p false
    set proctoring_p false
    set examination_statement_p false
    set seb_p false
    set seb_keys {}
    set seb_file ""

    ::xo::dc 0or1row is_proctored {
        select to_char(start_date, 'YYYY-MM-DD') as start_date,
               to_char(end_date, 'YYYY-MM-DD') as end_date,
               to_char(start_time, 'HH24:MI:SS') as start_time,
               to_char(end_time, 'HH24:MI:SS') as end_time,
               case when preview_p then 'true' else 'false' end as preview_p,
               case when audio_p then 'true' else 'false' end as audio_p,
               case when camera_p then 'true' else 'false' end as camera_p,
               case when desktop_p then 'true' else 'false' end as desktop_p,
               case when proctoring_p then 'true' else 'false' end as proctoring_p,
               case when enabled_p then 'true' else 'false' end as enabled_p,
               case when examination_statement_p then 'true' else 'false' end as examination_statement_p,
               case when seb.object_id is not null then 'true' else 'false' end as seb_p,
               seb.allowed_keys as seb_keys,
               seb.seb_file
          from proctoring_objects o
               left join proctoring_safe_exam_browser_conf seb
                    on seb.object_id = o.object_id
        where o.object_id = :object_id
    }

    return [list \
                enabled_p  $enabled_p \
                start_date $start_date \
                end_date   $end_date \
                start_time $start_time \
                end_time   $end_time \
                preview_p  $preview_p \
                audio_p    $audio_p \
                camera_p   $camera_p \
                desktop_p  $desktop_p \
                proctoring_p $proctoring_p \
                examination_statement_p $examination_statement_p \
                seb_p      $seb_p \
                seb_keys   $seb_keys \
                seb_file   $seb_file]
}

ad_proc ::proctoring::active_p {
    -object_id:required
} {
    Returns whether proctoring is active now.

    @return boolean
} {
    return [::xo::dc 0or1row -prepare integer check {
        select 1 from proctoring_objects
        where object_id = :object_id
          and enabled_p
          and (start_date is null or start_date <= current_date)
          and (end_date is null or end_date >= current_date)
          and (start_time is null or start_time <= cast(current_timestamp as time))
          and (end_time is null or end_time >= cast(current_timestamp as time))
    }]
}

ad_proc ::proctoring::file_already_received_p {
    -object_id:required
    -user_id:required
    -file:required
} {
    Returns if the file is the same the users sent the last time
    they uploaded a proctoring file.

    @param object_id id of the proctored object
    @param user_id id of the proctored user
    @param file an absolute path to a file in the filesystem

    @return boolean
} {
    set cache_name proctoring_checksums_cache

    # Make sure the checksum of current file is not the same as the
    # one we have in the cache.
    set checksum [ns_md file -digest sha1 $file]
    set already_received_p false
    if {[ns_cache_get $cache_name ${object_id}_${user_id} cached_checksum]} {
        if {$checksum eq $cached_checksum} {
            set already_received_p true
        }
    }

    # Update in any case the cache to renew the expiration
    ns_cache_eval -force -- $cache_name ${object_id}_${user_id} set v $checksum

    return $already_received_p
}

