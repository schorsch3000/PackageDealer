# Image containing nothing but the script, to be used as a COPY --from source:
#   COPY --from=ghcr.io/<owner>/packagedealer:1 /usr/local/bin/pd /usr/local/bin/pd
FROM scratch
COPY PackageDealer /usr/local/bin/PackageDealer
COPY PackageDealer /usr/local/bin/pd
