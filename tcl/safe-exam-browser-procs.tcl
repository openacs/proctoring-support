ad_library {
    API to support usage of the Safe Exam Browser for proctoring

    https://safeexambrowser.org/
}

namespace eval proctoring {}
namespace eval proctoring::seb {}

ad_proc -private ::proctoring::seb::configure {
    -object_id:required
    -allowed_keys:required
    {-seb_file ""}
} {
    Stores the configuration for an exam

    @param object_id id of the proctored object.
    @param allowed_keys safe exam browser's keys that will be used to validate
               against the request hash provided by the clients.
    @param seb_file absolute path to a file that will store the
                    configuration for this exam. When served to a user
                    having the Safe Exam Browser installed, this file
                    will configure and optionally start the exam using
                    exactly the provided configuration.
} {
    if {$seb_file ne ""} {
        set folder_path [acs_root_dir]/proctoring/seb/$object_id
        file mkdir $folder_path

        set seb_file_path $folder_path/Conf.seb

        file rename -force -- $seb_file $seb_file_path
    } else {
        set seb_file_path ""
    }

    ::xo::dc dml -prepare {
        integer text text
        text text
    } save_conf {
        insert into proctoring_safe_exam_browser_conf
        (object_id, allowed_keys, seb_file)
        values
        (:object_id, :allowed_keys, :seb_file_path)
        on conflict (object_id)
        do update set
        allowed_keys = :allowed_keys,
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

ad_proc -private ::proctoring::seb::valid_hash_p {
    -key:required
    -hash:required
    -url:required
} {
    Validates a Safe Exam Browser hash.

    The hash is generated based on:
      - the SEB configuration (ConfigKeyHash and RequestHash)
      - the SEB version and platform (RequestHash only)
      - the currently requested URL

    @return boolean
} {
    return [expr {[ns_md string -digest sha256 ${url}${key}] eq $hash}]
}

ad_proc -private ::proctoring::seb::this_url {} {
    Computes the currently requested URL, used to match against the
    hash provided by the browser.

    @return fully qualified URL
} {
    set url [util_current_location][ns_conn url]
    set query [ns_conn query]
    if {$query ne ""} {
        append url ?$query
    }

    return $url
}

ad_proc -private ::proctoring::seb::get_hashes {} {
    Gets the hashes provided by the browser, which we will check
    against the configured keys.
} {
    set hashes [list]

    foreach h {
        "X-SafeExamBrowser-RequestHash"
        "X-SafeExamBrowser-ConfigKeyHash"
    } {
        set hash [ns_set get [ns_conn headers] $h]
        if {$hash ne ""} {
            lappend hashes $hash
        }
    }

    return $hashes
}

ad_proc -private ::proctoring::seb::valid_access_p {
    -allowed_keys:required
} {
    Check the hashes provided by the browser against the keys.

    @return boolean
} {
    set url [::proctoring::seb::this_url]

    foreach hash [::proctoring::seb::get_hashes] {
        foreach key $allowed_keys {
            set valid_access_p [::proctoring::seb::valid_hash_p \
                                    -hash $hash \
                                    -url  $url \
                                    -key  $key]
            if {$valid_access_p} {
                return true
            }
        }
    }

    return false
}

ad_proc -private ::proctoring::seb::require_valid_access {
    -object_id:required
} {
    Validates the proctored session using the Safe Exam Broswer keys
    configured for the object. If the client does not comply, will
    stop page execution and return the .seb configuration file as
    response. If no .seb file was cofigured, will just return a
    unauthorized error.
} {
    set seb_p [::xo::dc 0or1row -prepare integer get_seb_conf {
        select allowed_keys, seb_file
        from proctoring_safe_exam_browser_conf
        where object_id = :object_id
    }]

    if {$seb_p} {
        set valid_access_p [::proctoring::seb::valid_access_p \
                                -allowed_keys $allowed_keys]
    } else {
        set valid_access_p true
    }

    if {!$valid_access_p} {
        if {[file exists $seb_file]} {
            ns_set cput [ns_conn outputheaders] \
                Content-Disposition "attachment; filename=[file tail $seb_file]"
            ns_writer submitfile -headers $seb_file
        } else {
            ns_returnforbidden
        }
        ad_script_abort
    }
}
