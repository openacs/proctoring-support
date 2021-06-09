ad_library {
    API to support usage of the Safe Exam Browser for proctoring

    https://safeexambrowser.org/
}

namespace eval proctoring {}
namespace eval proctoring::seb {}

ad_proc -private ::proctoring::seb::configure {
    -object_id:required
    -key:required
    -seb_file:required
} {
    Stores the configuration for an exam

    @param object_id id of the proctored object.
    @param key safe exam browser's key that will be used to validate
               against the request hash provided by the clients.
    @param seb_file absolute path to a file that will store the
                    configuration for this exam. When served to a user
                    having the Safe Exam Browser installed, this file
                    will configure and optionally start the exam using
                    exactly the provided configuration.
} {
    set folder_path [acs_root_dir]/proctoring/seb/$object_id
    file mkdir -- $folder_path

    set seb_file_path $folder_path/Conf.seb

    file rename -force -- $seb_file $seb_file_path

    ::xo::dc dml -prepare {
        integer text text
        text text
    } save_conf {
        insert into proctoring_safe_exam_browser_conf
        (object_id, key, seb_file)
        values
        (:object_id, :key, :seb_file_path)
        on conflict (object_id)
        do update set
        key = :key,
        seb_file = :seb_file_path
    }
}

ad_proc -private ::proctoring::seb::unconfigure {
    -object_id:required
} {
    Deletes the configuration for an exam

    @param object_id id of the proctored object.
} {
    set folder_path [acs_root_dir]/proctoring/seb/$object_id
    set seb_file $folder_path/Conf.seb

    file delete -- $seb_file

    ::xo::dc dml -prepare integer delete_conf {
        delete from proctoring_safe_exam_browser_conf
         where object_id = :object_id
    }
}

ad_proc -private ::proctoring::seb::valid_key_p {
    -object_id:required
    -object_url:required
    -key:required
} {
    Validates a Safe Exam Browser key

    @return boolean
} {
    set header [ns_set get [ns_conn headers] X-SafeExamBrowser-RequestHash]
    return [expr {[ns_md string -digest sha256 ${object_url}${key}] eq $header}]
}

ad_proc -private ::proctoring::seb::require_valid_access {
    -object_id:required
    -object_url:required
} {
    Validates the proctored session using the Safe Exam Broswer keys
    configured for the object. If the client does not comply, will
    stop page execution and return the .seb configuration file as
    response. If no .seb file was cofigured, will just return a
    unauthorized error.
} {
    set seb_p [::xo::dc 0or1row -prepare integer get_seb_conf {
        select key, seb_file
        from proctoring_safe_exam_browser_conf
        where object_id = :object_id
    }]

    if {$seb_p} {
        set valid_access_p [::proctoring::seb::valid_key_p \
                                -object_id $object_id \
                                -object_url $object_url \
                                -key $key]
    } else {
        set valid_access_p true
    }

    if {!$valid_access_p} {
        if {[file exists $seb_file]} {
            ns_writer submitfile -headers $seb_file
        } else {
            ns_returnunauthorized
        }
        ad_script_abort
    }
}
