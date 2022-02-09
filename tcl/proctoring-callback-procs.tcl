ad_library {
    Proctoring callback hooks
}

namespace eval ::proctoring {}

ad_proc -private ::proctoring::enforce_filter args {
    This is the enforcing filter calling the callbacks that will tell
    us whether this request whould be proctored or not.

    @see proctoring::enforce
    @see https://naviserver.sourceforge.io/n/naviserver/files/ns_register.html
} {
    if {![ns_conn isconnected]} {
        return filter_ok
    }

    set enforcings [::callback ::proctoring::enforce]
    foreach data $enforcings {
        # Check whether:
        # - the callback told us this is a proctored request
        # - we are already on the proctoring entry point or not
        # - proctoring is actually active for this URL
        if {[dict exists $data object_id] &&
            [dict exists $data object_url] &&
            [dict get $data object_url] ne [ns_conn url] &&
            [::proctoring::active_p -object_id [dict get $data object_id]]
        } {
            # "Enforcing" proctoring means to forcefully redirect any
            # request landing in a "proctored area" of the website (as
            # decided by the callbacks) to the proctoring entry page. Such
            # page is responsible to embed the /lib/proctored-page include
            # that will perform the actual iframe magic.
            set mapping [list \
                             @object_id@ [dict get $data object_id] \
                             @object_url@ [dict get $data object_url] \
                            ]
            template::add_body_script -script [string map $mapping {
                var inProctoringIframe = window.parent &&
                window.parent.document.querySelector("#proctored-iframe-@object_id@");
                if (!inProctoringIframe) {
                    location.href = "@object_url@";
                }
            }]
        }

        # In case that multiple proctoring configurations apply to this
        # request, only the first one will actually be enforced. This
        # should not be a problem in practice, as the expected behavior is
        # indeed that for any particular proctored object, only one
        # enforcing applies.
        if {[llength $enforcings] > 1} {
            ad_log warning "Multiple proctoring callbacks apply to this URL: '$enforcings'. Only '$data' was enforced."
        }
        break
    }
    return filter_ok
}

ad_proc -public -callback ::proctoring::enforce {} {
    Implementations of this hook should return nothing when a request
    is not supposed to be proctored, and the proctoring object and URL
    otherwise.

    Does not accept any argument, because all of the information is
    supposed to be retrieved by the connection context.

    @return dict with fields 'object_id' and 'object_url'
} -
