ad_library {
    Proctoring callback hooks
}

namespace eval ::proctoring {}

ad_proc -private ::proctoring::enforce_filter args {
    This is the enforcing filter calling the callbacks that will tell
    us whether this request would be proctored or not.

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

namespace eval ::proctoring::callback {}
namespace eval ::proctoring::callback::artifact {}

ad_proc -public -callback ::proctoring::callback::artifact::postprocess {
    -artifact_id:required
} {
    Implementations of this hook can apply custom postprocessing to a
    proctoring artifact.

    Be aware that this callback is invoked as soon as the artifact is
    created, for instance, at upload. Every callback implementation
    should defer to background processing every operation that would
    block a connection thread for a long time.

    @param artifact_id id of the artifact
} -

namespace eval ::proctoring::callback {}
namespace eval ::proctoring::callback::object {}

ad_proc -public -callback ::proctoring::callback::object::timeframes {
    -object_id:required
} {
    Implementations of this hook can return a list of timeframes,
    retrieved by package-specific logic (e.g. the timeframe of an XoWF
    InclassExam) that we can use to e.g. filter the list of proctoring
    artifacts via presets.

    @param object_id id of the proctored object

    @return a list of dicts with fields "name", "start_date",
            "start_time", "end_date" and "end_time". Date fields are
            dates in ISO format such as "2016-09-07", time fields are
            time formats such as "08:00" or other value accepted by a
            time HTML input field.
} -

