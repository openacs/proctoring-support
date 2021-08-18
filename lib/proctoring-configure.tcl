ad_include_contract {

    User Interface to configure proctoring for an object.

    @param object_id id of the ACS Object to be proctored

} {
    object_id:naturalnum,notnull
    return_url:localurl,optional
} -validate {
    has_permission -requires {object_id:naturalnum} {
        permission::require_permission -object_id $object_id -privilege "admin"
    }
}

ad_form \
    -name configure \
    -export {
        object_id
        return_url
    } \
    -form {
        {proctoring_examination_statement_p:text(radio)
            {label "[_ proctoring-support.Examination_Statement]"}
            {options {{[_ acs-kernel.common_Yes] true} {[_ acs-kernel.common_No] false}}}
        }
        {proctoring_proctoring_p:text(radio)
            {label "[_ proctoring-support.Proctoring]"}
            {options {{[_ acs-kernel.common_Yes] true} {[_ acs-kernel.common_No] false}}}
            {help_text "[_ proctoring-support.community_help_text]"}
        }
        {proctoring_preview_p:text(radio)
            {label "[_ proctoring-support.Preview]"}
            {options {{[_ acs-kernel.common_Yes] true} {[_ acs-kernel.common_No] false}}}
            {help_text "[_ proctoring-support.preview_help_text]"}
        }
        {proctoring_start_date:h5date,optional
            {label "[_ proctoring-support.Start_date]"}
        }
        {proctoring_end_date:h5date,optional
            {label "[_ proctoring-support.End_date]"}
        }
        {proctoring_start_time:h5time,optional
            {label "[_ acs-admin.Start_time]"}
            {format "HH24:MI"}
        }
        {proctoring_end_time:h5time,optional
            {label "[_ acs-admin.End_time]"}
            {format "HH24:MI"}
        }
    } -on_request {

        set settings [::proctoring::get_configuration -object_id $object_id]
        set proctoring_preview_p  [dict get $settings preview_p]
        set proctoring_proctoring_p [dict get $settings proctoring_p]
        set proctoring_examination_statement_p [dict get $settings examination_statement_p]
        set proctoring_start_date [dict get $settings start_date]
        set proctoring_end_date   [dict get $settings end_date]
        set proctoring_start_time [dict get $settings start_time]
        set proctoring_end_time   [dict get $settings end_time]

    } -on_submit {

        ::proctoring::configure -object_id $object_id \
            -start_date $proctoring_start_date \
            -end_date   $proctoring_end_date \
            -start_time $proctoring_start_time \
            -end_time   $proctoring_end_time \
            -preview_p  $proctoring_preview_p \
            -proctoring_p $proctoring_proctoring_p \
            -examination_statement_p $proctoring_examination_statement_p \
            -enabled_p [expr {$proctoring_proctoring_p || $proctoring_examination_statement_p}]

    } -after_submit {
        if {[info exists return_url]} {
            ad_returnredirect $return_url
            ad_script_abort
        }
    }
