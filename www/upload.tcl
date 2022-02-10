ad_page_contract {
    Proctoring upload endpoint
} {
    name:oneof(camera|desktop),notnull
    type:oneof(image|audio),notnull
    object_id:naturalnum,notnull
    file
    file.tmpfile
    {check_active_p:boolean true}
    {notify_p:boolean true}
    {record_p:boolean true}
}
#ns_log notice "UPLOAD called with notify_p $notify_p record_p $record_p"
