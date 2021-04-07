ad_library {
    Startup script for proctoring-support
}

# This cache will store the checksum of the last picture that has been
# received on behalf of a user while proctoring a specific object.
# This is needed to implement a server-side check that detects
# pictures being sent multiple times, e.g. when a request resulting in
# a client timeout still gets processed by the server.

set cache_name proctoring_checksums_cache
set cache_size 1MB ; # ~ 25000 40bytes sha1 entries
set cache_timeout 1ms
set cache_expires 2h

ns_cache_create \
    -timeout $cache_timeout \
    -expires $cache_expires -- $cache_name $cache_size

