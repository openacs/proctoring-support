ad_include_contract {

    Exports the examination statement acceptances for specified object

} {
    object_id:naturalnum,notnull
}

package require csv

# Make the lists to convert to csv-format
set acceptances {{"userID" "name" "timestamp"}}
lappend acceptances {*}[::xo::dc list_of_lists -prepare integer export {
    select u.username,
           p.last_name || ' ' || p.first_names,
           a.timestamp
    from proctoring_examination_statement_acceptance a,
         users u, persons p
    where a.object_id = :object_id
      and a.user_id = u.user_id
      and a.user_id = p.person_id
    order by last_name asc, first_names asc, timestamp desc
}]

# Write the data to a file
set tmpfile [ad_tmpnam]
set f [open $tmpfile w]
puts $f [csv::joinlist $acceptances ";"]
close $f

ns_set cput [ns_conn outputheaders] "Content-Disposition" "attachment; filename=\"export.csv\""
ns_writer submitfile -headers $tmpfile
file delete -- $tmpfile
ad_script_abort
