ad_page_contract {
    Proctoring upload endpoint
} {
    name:oneof(camera|desktop),notnull
    type:oneof(image|audio),notnull
    object_id:naturalnum,notnull
    file
    file.tmpfile
}
